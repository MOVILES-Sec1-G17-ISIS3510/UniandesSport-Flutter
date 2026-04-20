const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
// Carga diferida de Gemini dentro de dailyMatchmaker para evitar fallo global al iniciar.

admin.initializeApp();
const db = admin.firestore();

const SMART_RECOMMENDATION_COLLECTION = 'smart_recommendations';
const SMART_MATCH_LOG_COLLECTION = 'smart_match_logs';
const USERS_COLLECTION = 'users';
const EVENTS_COLLECTION = 'events';
const GEMINI_MODEL = 'gemini-2.5-flash';
const GEMINI_API_KEY = 'AIzaSyDdC2I3Y62cVLYu60G7q4TFJSFQWsnv5Uo';

const BQ_COLLECTION = 'business_metrics';
const BQ3_USER_COLLECTION = 'bq3_user_sport_counts';
const BQ4_NOTIFICATION_COLLECTION = 'bq4_automated_notifications';
const USER_SPORT_NOTIFICATION_COLLECTION = 'user_sport_notifications';
const BQ4_CONVERSION_COLLECTION = 'bq4_notification_conversions';
const BQ4_SNAPSHOT_COLLECTION = 'bq4_conversion_snapshots';
const BQ5_READINESS_LOG_COLLECTION = 'bq5_readiness_time_logs';
const BQ6_URGENCY_QUEUE_COLLECTION = 'bq6_urgency_notification_queue';
const BQ3_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq3_global');
const BQ4_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq4_global');
const BQ5_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq5_global');
const BQ6_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq6_global');

/**
 * Normaliza nombres de deporte para evitar duplicados semanticos en agregaciones.
 * Ejemplo: " Soccer " y "soccer" terminan en la misma llave.
 */
function normalizeSport(sport) {
    return String(sport || '').trim().toLowerCase();
}

/**
 * Normaliza modalidad de evento (casual/tournament).
 */
function normalizeModality(modality) {
    return String(modality || '').trim().toLowerCase();
}

function isFutureTimestamp(value, now) {
    if (!value || typeof value.toDate !== 'function') {
        return false;
    }

    return value.toDate() > now.toDate();
}

/**
 * Incrementa acumuladores de BQ3 en dos niveles:
 * 1) Documento por usuario (bq3_user_sport_counts/{userId})
 * 2) Documento global (business_metrics/bq3_global)
 *
 * source permite explicar de donde salió el conteo:
 * - event_created
 * - event_joined
 * - coach_request
 */
async function incrementBq3SportCount({userId, sport, source, amount = 1}) {
    const normalizedSport = normalizeSport(sport);
    const normalizedSource = String(source || '').trim().toLowerCase();

    if (!userId || !normalizedSport || !normalizedSource || amount === 0) {
        return null;
    }

    const userDocRef = db.collection(BQ3_USER_COLLECTION).doc(userId);

    await Promise.all([
        userDocRef.set({
            userId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            [`sports.${normalizedSport}.total`]: admin.firestore.FieldValue.increment(amount),
            [`sports.${normalizedSport}.sources.${normalizedSource}`]: admin.firestore.FieldValue.increment(amount)
        }, {merge: true}),
        BQ3_GLOBAL_DOC.set({
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            [`sports.${normalizedSport}.total`]: admin.firestore.FieldValue.increment(amount),
            [`sports.${normalizedSport}.sources.${normalizedSource}`]: admin.firestore.FieldValue.increment(amount)
        }, {merge: true})
    ]);

    await Promise.all([
        refreshBq3UserSummary(userId),
        refreshBq3GlobalSummary(),
    ]);

    return null;
}

/**
 * Convierte el mapa sports en un ranking descendente y resume el deporte principal.
 */
function buildBq3SummaryFromSports(sports, requestedSources = []) {
    const normalizedSources = Array.isArray(requestedSources)
        ? requestedSources.map((source) => String(source || '').trim().toLowerCase()).filter(Boolean)
        : [];
    const hasSourceFilter = normalizedSources.length > 0;

    const ranking = Object.entries(sports || {})
        .map(([sport, payload]) => {
            const sourceBreakdown = payload && payload.sources ? payload.sources : {};
            const total = hasSourceFilter
                ? normalizedSources.reduce((sum, source) => sum + Number(sourceBreakdown[source] || 0), 0)
                : Number(payload && payload.total ? payload.total : 0);

            return {
                sport,
                total,
                sourceBreakdown,
            };
        })
        .filter((item) => item.total > 0)
        .sort((a, b) => b.total - a.total);

    const top = ranking.length > 0 ? ranking[0] : null;

    return {
        hasData: ranking.length > 0,
        mostScheduledSport: top ? top.sport : null,
        totalSchedules: top ? top.total : 0,
        sourceBreakdown: top ? top.sourceBreakdown : {},
        ranking,
        appliedSources: hasSourceFilter ? normalizedSources : ['all'],
    };
}

async function refreshBq3UserSummary(userId) {
    if (!userId) {
        return null;
    }

    const docRef = db.collection(BQ3_USER_COLLECTION).doc(userId);
    const snap = await docRef.get();
    const data = snap.data() || {};
    const summary = buildBq3SummaryFromSports(data.sports || {});

    await docRef.set({
        userId,
        summaryScope: 'user',
        ...summary,
        summaryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return summary;
}

async function refreshBq3GlobalSummary() {
    const snap = await BQ3_GLOBAL_DOC.get();
    const data = snap.data() || {};
    const summary = buildBq3SummaryFromSports(data.sports || {});

    await BQ3_GLOBAL_DOC.set({
        summaryScope: 'global',
        ...summary,
        summaryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return summary;
}

/**
 * Calcula y persiste el resumen global de BQ4 para que pueda verse en Firestore.
 *
 * El documento `business_metrics/bq4_global` siempre queda con los campos
 * derivados mas importantes, y ademas guardamos una foto historica en
 * `bq4_conversion_snapshots` para auditoria.
 */
async function refreshBq4GlobalSummary() {
    const snap = await BQ4_GLOBAL_DOC.get();
    const data = snap.data() || {};

    const notificationsSent = Number(data.notificationsSent || 0);
    const effectiveRegistrations = Number(data.effectiveRegistrations || 0);
    const conversionRate = notificationsSent > 0
        ? Number(((effectiveRegistrations / notificationsSent) * 100).toFixed(2))
        : 0;

    const summary = {
        summaryScope: 'global',
        notificationsSent,
        effectiveRegistrations,
        conversionRate,
        sentBySource: data.sentBySource || {},
        conversionsBySource: data.conversionsBySource || {},
        summaryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        summaryFormula: 'conversionRate = (effectiveRegistrations / notificationsSent) * 100',
    };

    await BQ4_GLOBAL_DOC.set(summary, {merge: true});

    await db.collection(BQ4_SNAPSHOT_COLLECTION).add({
        ...summary,
        recordedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedAt: admin.firestore.Timestamp.now(),
    });

    return {
        notificationsSent,
        effectiveRegistrations,
        conversionRate,
        sentBySource: summary.sentBySource,
        conversionsBySource: summary.conversionsBySource,
        formula: summary.summaryFormula,
    };
}

/**
 * Reconstruye BQ3 por usuario usando historial existente.
 *
 * Se usa como backfill cuando el documento agregado aun no existe
 * (ej. eventos creados antes de desplegar la Cloud Function).
 */
async function rebuildBq3UserFromHistory(userId) {
    if (!userId) {
        return {};
    }

    const totalsBySport = {};

    const addCount = (sport, source, amount = 1) => {
        const normalizedSport = normalizeSport(sport);
        const normalizedSource = String(source || '').trim().toLowerCase();

        if (!normalizedSport || !normalizedSource || amount <= 0) {
            return;
        }

        if (!totalsBySport[normalizedSport]) {
            totalsBySport[normalizedSport] = {total: 0, sources: {}};
        }

        totalsBySport[normalizedSport].total += amount;
        totalsBySport[normalizedSport].sources[normalizedSource] =
            (totalsBySport[normalizedSport].sources[normalizedSource] || 0) + amount;
    };

    const [createdEventsSnap, joinedEventsSnap, coachRequestsSnap] = await Promise.all([
        db.collection('events')
            .where('createdBy', '==', userId)
            .get(),
        db.collection('events')
            .where('participants', 'array-contains', userId)
            .get(),
        db.collection('coach_requests')
            .where('userId', '==', userId)
            .get(),
    ]);

    createdEventsSnap.docs.forEach((doc) => {
        const data = doc.data() || {};
        addCount(data.sport, 'event_created', 1);
    });

    joinedEventsSnap.docs.forEach((doc) => {
        const data = doc.data() || {};
        addCount(data.sport, 'event_joined', 1);
    });

    coachRequestsSnap.docs.forEach((doc) => {
        const data = doc.data() || {};
        addCount(data.sport, 'coach_request', 1);
    });

    await db.collection(BQ3_USER_COLLECTION).doc(userId).set({
        userId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        sports: totalsBySport,
        backfilledAt: admin.firestore.FieldValue.serverTimestamp(),
        backfillReason: 'missing_or_empty_bq3_doc',
    }, {merge: true});

    await refreshBq3UserSummary(userId);

    return totalsBySport;
}

/**
 * Devuelve el ultimo registro de coaching/tutoria disponible para un usuario.
 *
 * En este proyecto no existe una coleccion separada de sesiones confirmadas,
 * por lo que usamos `coach_requests.createdAt` como el evento de coaching/tutoria
 * persistido mas cercano que refleja contacto real con el servicio.
 */
async function getLastCoachingTouch(userId) {
    if (!userId) {
        return null;
    }

    const snapshot = await db.collection('coach_requests')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

    if (snapshot.empty) {
        return null;
    }

    const doc = snapshot.docs[0];
    const data = doc.data() || {};
    return {
        requestId: doc.id,
        createdAt: data.createdAt || null,
        sport: normalizeSport(data.sport),
        skillLevel: String(data.skillLevel || '').trim(),
    };
}

function toJsDate(value) {
    if (!value) {
        return null;
    }

    if (value instanceof Date) {
        return value;
    }

    if (typeof value.toDate === 'function') {
        return value.toDate();
    }

    return null;
}

async function registerBq5ReadinessLog({userId, eventId, eventData, registeredAt}) {
    if (!userId || !eventId || !eventData) {
        return null;
    }

    const nowDate = toJsDate(registeredAt) || new Date();
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};
    const appRegisteredAt = toJsDate(userData.createdAt);
    const lastCoachingTouch = await getLastCoachingTouch(userId);
    const lastCoachingAt = toJsDate(lastCoachingTouch && lastCoachingTouch.createdAt);

    let baselineType = 'unknown';
    let baselineAt = null;
    if (lastCoachingAt) {
        baselineType = 'coaching_touch';
        baselineAt = lastCoachingAt;
    } else if (appRegisteredAt) {
        baselineType = 'app_registration';
        baselineAt = appRegisteredAt;
    }

    const elapsedHoursSinceBaseline = baselineAt
        ? Number(Math.max(0, (nowDate.getTime() - baselineAt.getTime()) / 36e5).toFixed(2))
        : null;
    const elapsedDaysSinceBaseline = elapsedHoursSinceBaseline !== null
        ? Number((elapsedHoursSinceBaseline / 24).toFixed(2))
        : null;

    const scheduledAt = toJsDate(eventData.scheduledAt);
    const readinessGapHoursToCompetition = baselineAt && scheduledAt
        ? Number(Math.max(0, (scheduledAt.getTime() - baselineAt.getTime()) / 36e5).toFixed(2))
        : null;

    const title = String(eventData.title || '');
    const challengeHint = String((eventData.metadata && eventData.metadata.type) || '').toLowerCase().includes('challenge')
        || title.toLowerCase().includes('challenge');

    const logPayload = {
        userId,
        eventId,
        eventTitle: title,
        eventSport: normalizeSport(eventData.sport),
        eventModality: normalizeModality(eventData.modality),
        challengeHint,
        isUpcomingCompetition: isUpcomingCompetition(eventData, admin.firestore.Timestamp.now()),
        eventScheduledAt: scheduledAt,
        registrationDetectedAt: nowDate,
        lastCoachingRequestId: lastCoachingTouch ? lastCoachingTouch.requestId : null,
        lastCoachingAt,
        appRegisteredAt,
        baselineType,
        baselineAt,
        elapsedHoursSinceBaseline,
        elapsedDaysSinceBaseline,
        readinessGapHoursToCompetition,
        hasPriorCoaching: Boolean(lastCoachingAt),
        source: 'onRegistrationChange',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedAt: admin.firestore.Timestamp.now(),
        formula: 'elapsedHoursSinceBaseline = registrationDetectedAt - (lastCoachingAt || appRegisteredAt)',
    };

    await db.collection(BQ5_READINESS_LOG_COLLECTION).add(logPayload);

    await db.runTransaction(async (tx) => {
        const summarySnap = await tx.get(BQ5_GLOBAL_DOC);
        const summaryData = summarySnap.data() || {};
        const currentTracked = Number(summaryData.totalTrackedRegistrations || 0);
        const currentWithBaseline = Number(summaryData.totalWithBaseline || 0);
        const currentCumulativeHours = Number(summaryData.cumulativeElapsedHours || 0);
        const incrementHours = elapsedHoursSinceBaseline !== null ? elapsedHoursSinceBaseline : 0;
        const nextTracked = currentTracked + 1;
        const nextWithBaseline = currentWithBaseline + (elapsedHoursSinceBaseline !== null ? 1 : 0);
        const nextCumulativeHours = Number((currentCumulativeHours + incrementHours).toFixed(2));
        const averageElapsedHours = nextWithBaseline > 0
            ? Number((nextCumulativeHours / nextWithBaseline).toFixed(2))
            : 0;

        tx.set(BQ5_GLOBAL_DOC, {
            summaryScope: 'global',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastTrackedUserId: userId,
            lastTrackedEventId: eventId,
            totalTrackedRegistrations: nextTracked,
            totalWithBaseline: nextWithBaseline,
            cumulativeElapsedHours: nextCumulativeHours,
            averageElapsedHours,
            baselineTypeCounters: {
                ...(summaryData.baselineTypeCounters || {}),
                [baselineType]: Number(((summaryData.baselineTypeCounters || {})[baselineType] || 0) + 1),
            },
            note: 'BQ5 registra el tiempo transcurrido entre inscripcion a torneo/reto y ultima senal de coaching; si no existe coaching, usa users.createdAt.',
        }, {merge: true});
    });

    return {
        userId,
        eventId,
        baselineType,
        elapsedHoursSinceBaseline,
        elapsedDaysSinceBaseline,
        readinessGapHoursToCompetition,
    };
}

/**
 * Resuelve los deportes mas relevantes de un usuario para analitica tipo BQ6.
 *
 * Prioridad:
 * 1) inferredPreferences (si existen)
 * 2) mainSport
 * 3) catalogo actual de deportes
 */
function getUserTopSportsFromProfile(userData, fallbackLimit = 3) {
    const rawPrefs = userData && userData.inferredPreferences;
    const prefs = {};

    if (rawPrefs && typeof rawPrefs === 'object') {
        Object.entries(rawPrefs).forEach(([key, value]) => {
            if (typeof key === 'string' && typeof value === 'number') {
                prefs[normalizeSport(key)] = value;
            }
        });
    }

    if (Object.keys(prefs).length > 0) {
        return Object.entries(prefs)
            .sort((a, b) => b[1] - a[1])
            .slice(0, fallbackLimit)
            .map(([sport]) => sport);
    }

    const mainSport = normalizeSport(userData && userData.mainSport);
    if (mainSport) {
        return [mainSport];
    }

    return [];
}

/**
 * Identifica si un evento puede considerarse competencia proxima para BQ5.
 *
 * Regla actual:
 * - modality = tournament
 * - status = active
 * - scheduledAt futuro
 * - para compatibilidad con los retos del proyecto, tambien aceptamos eventos
 *   cuyo titulo o metadata sugiera un reto competitivo.
 */
function isUpcomingCompetition(eventData, now) {
    if (!eventData) {
        return false;
    }

    const modality = normalizeModality(eventData.modality);
    const status = String(eventData.status || '').trim().toLowerCase();
    const title = String(eventData.title || '').toLowerCase();
    const metadata = eventData.metadata && typeof eventData.metadata === 'object'
        ? eventData.metadata
        : {};
    const competitionType = String(metadata.type || metadata.category || '').trim().toLowerCase();
    const hasChallengeSignal = title.includes('challenge') || competitionType.includes('challenge');

    return status === 'active' && isFutureTimestamp(eventData.scheduledAt, now) && (
        modality === 'tournament' || hasChallengeSignal
    );
}

/**
 * Calcula la capacidad disponible de un evento como maxParticipants menos
 * participantes actuales. Nunca retorna valores negativos.
 */
function getAvailableCapacity(eventData) {
    const maxParticipants = Number(eventData && eventData.maxParticipants ? eventData.maxParticipants : 0);
    const participants = Array.isArray(eventData && eventData.participants)
        ? eventData.participants.length
        : 0;

    return Math.max(0, maxParticipants - participants);
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function buildBq6IntentSummaryForSport({sport, inferredPreferences, bq3Sports}) {
    const normalizedSport = normalizeSport(sport);
    const preferenceScore = Number((inferredPreferences && inferredPreferences[normalizedSport]) || 0);
    const bq3Payload = bq3Sports && bq3Sports[normalizedSport] ? bq3Sports[normalizedSport] : {};
    const interactionCount = Number((bq3Payload && bq3Payload.total) || 0);

    // Escala combinada de intencion en [0,100] basada en preferencia + interacciones historicas.
    const intentScore = clamp(Number((preferenceScore * 8 + interactionCount * 12).toFixed(2)), 0, 100);
    const hasDemonstratedIntent = intentScore >= 20 || interactionCount >= 1 || preferenceScore >= 3;

    return {
        sport: normalizedSport,
        preferenceScore,
        interactionCount,
        intentScore,
        hasDemonstratedIntent,
    };
}

/**
 * Construye lista de tokens FCM de forma resiliente a distintos esquemas.
 *
 * Campos soportados en users/{uid}:
 * - fcmToken (string)
 * - notificationToken (string)
 * - pushToken (string)
 * - fcmTokens (array<string>)
 * - notificationTokens (array<string>)
 */
function collectUserNotificationTokens(userData) {
    if (!userData || typeof userData !== 'object') {
        return [];
    }

    const tokens = new Set();

    const singleKeys = ['fcmToken', 'notificationToken', 'pushToken'];
    singleKeys.forEach((key) => {
        const value = userData[key];
        if (typeof value === 'string' && value.trim().length > 0) {
            tokens.add(value.trim());
        }
    });

    const listKeys = ['fcmTokens', 'notificationTokens'];
    listKeys.forEach((key) => {
        const value = userData[key];
        if (Array.isArray(value)) {
            value.forEach((token) => {
                if (typeof token === 'string' && token.trim().length > 0) {
                    tokens.add(token.trim());
                }
            });
        }
    });

    return Array.from(tokens);
}

/**
 * Envia (o encola) notificaciones automaticas por coincidencia de deporte BQ3.
 *
 * Reglas:
 * - Usuario debe tener `mainSport` no nulo en users/{uid}
 * - `bq3_user_sport_counts/{uid}.mostScheduledSport` debe coincidir con el deporte del evento
 * - Si hay tokens FCM, se intenta envio push; si no, se deja registro en cola
 */
async function notifyUsersByBq3MainSportOnEventCreated({eventId, eventData, creatorId}) {
    const eventSport = normalizeSport(eventData && eventData.sport);
    if (!eventId || !eventSport) {
        return {targetedUsers: 0, sentUsers: 0, queuedUsers: 0};
    }

    const eventTitle = String((eventData && eventData.title) || 'New event').trim() || 'New event';
    const eventModality = normalizeModality(eventData && eventData.modality);

    const bq3CandidatesSnap = await db.collection(BQ3_USER_COLLECTION)
        .where('mostScheduledSport', '==', eventSport)
        .limit(300)
        .get();

    if (bq3CandidatesSnap.empty) {
        return {targetedUsers: 0, sentUsers: 0, queuedUsers: 0};
    }

    let targetedUsers = 0;
    let sentUsers = 0;
    let queuedUsers = 0;

    for (const bq3Doc of bq3CandidatesSnap.docs) {
        const userId = bq3Doc.id;
        if (!userId || userId === creatorId) {
            continue;
        }

        const userSnap = await db.collection('users').doc(userId).get();
        if (!userSnap.exists) {
            continue;
        }

        const userData = userSnap.data() || {};
        const userMainSport = normalizeSport(userData.mainSport);

        // Requisito del producto: solo notificar si mainSport existe.
        if (!userMainSport) {
            continue;
        }

        // Requisito del producto: notificar cuando el evento coincide con su deporte principal.
        if (userMainSport !== eventSport) {
            continue;
        }

        targetedUsers += 1;

        const notificationDocId = `${eventId}_${userId}`;
        const notificationRef = db.collection(USER_SPORT_NOTIFICATION_COLLECTION).doc(notificationDocId);
        const notificationBase = {
            notificationId: notificationDocId,
            userId,
            eventId,
            eventTitle,
            sport: eventSport,
            modality: eventModality,
            reason: 'bq3_main_sport_match',
            status: 'queued',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'onEventCreated',
        };

        const tokens = collectUserNotificationTokens(userData);

        if (!tokens.length) {
            queuedUsers += 1;
            await notificationRef.set(notificationBase, {merge: true});
            continue;
        }

        try {
            const response = await admin.messaging().sendMulticast({
                tokens,
                notification: {
                    title: 'New event in your main sport',
                    body: `${eventTitle} was created in ${eventSport}.`,
                },
                data: {
                    eventId,
                    sport: eventSport,
                    source: 'bq3_main_sport_match',
                },
            });

            const hasAnySuccess = Number(response.successCount || 0) > 0;
            if (hasAnySuccess) {
                sentUsers += 1;
            } else {
                queuedUsers += 1;
            }

            await notificationRef.set({
                ...notificationBase,
                status: hasAnySuccess ? 'sent' : 'failed',
                fcmSuccessCount: Number(response.successCount || 0),
                fcmFailureCount: Number(response.failureCount || 0),
                attemptedTokenCount: tokens.length,
                sentAt: hasAnySuccess ? admin.firestore.FieldValue.serverTimestamp() : null,
            }, {merge: true});
        } catch (error) {
            queuedUsers += 1;
            await notificationRef.set({
                ...notificationBase,
                status: 'failed',
                attemptedTokenCount: tokens.length,
                errorMessage: String((error && error.message) || error || 'unknown_error'),
            }, {merge: true});
        }
    }

    return {targetedUsers, sentUsers, queuedUsers};
}

// ============================================================================
// REGLA 1: CREAR UNA PARTIDA (+8)
// ============================================================================
exports.onEventCreated = functions.firestore
    .document('events/{eventId}')
    .onCreate(async (snap, context) => {
        const eventData = snap.data();
        const creatorId = eventData.creatorId || eventData.createdBy;
        const sport = eventData.sport;

        if (!creatorId || !sport) return null;

        await Promise.all([
            db.collection('users').doc(creatorId).update({
                [`inferredPreferences.${sport}`]: admin.firestore.FieldValue.increment(8),
                [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
            }),
            incrementBq3SportCount({
                userId: creatorId,
                sport,
                source: 'event_created',
                amount: 1
            })
        ]);

        try {
            await notifyUsersByBq3MainSportOnEventCreated({
                eventId: context.params.eventId,
                eventData,
                creatorId,
            });
        } catch (error) {
            console.error('[onEventCreated] Error sending BQ3 sport notifications:', error);
        }

        return null;
    });

// ============================================================================
// BQ3: SOLICITUD DE COACH (+1 al historial de entrenamiento/coaching)
// ============================================================================
exports.onCoachRequestCreated = functions.firestore
    .document('coach_requests/{requestId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const userId = data.userId;
        const sport = data.sport;

        if (!userId || !sport) {
            return null;
        }

        await incrementBq3SportCount({
            userId,
            sport,
            source: 'coach_request',
            amount: 1
        });

        return null;
    });

// ============================================================================
// BQ5: EVENTO DE COACHING MAS RECIENTE PARA COMPETENCIAS PROXIMAS
// ============================================================================
exports.getBq5ReadinessGapForUpcomingCompetitions = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para consultar BQ5.');
    }

    const userId = context.auth.uid;
    const now = admin.firestore.Timestamp.now();
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    const userTopSports = getUserTopSportsFromProfile(userData, 3);
    const maxCompetitions = Math.max(1, Number(data && data.limit ? data.limit : 5));

    const competitionsSnapshot = await db.collection('events')
        .where('status', '==', 'active')
        .orderBy('scheduledAt', 'asc')
        .limit(100)
        .get();

    const upcomingCompetitions = competitionsSnapshot.docs
        .map((doc) => ({id: doc.id, ...doc.data()}))
        .filter((eventData) => isUpcomingCompetition(eventData, now))
        .filter((eventData) => {
            const participants = Array.isArray(eventData.participants) ? eventData.participants : [];
            return participants.includes(userId);
        })
        .slice(0, maxCompetitions);

    const lastCoachingTouch = await getLastCoachingTouch(userId);
    const lastTouchAt = lastCoachingTouch && lastCoachingTouch.createdAt && typeof lastCoachingTouch.createdAt.toDate === 'function'
        ? lastCoachingTouch.createdAt.toDate()
        : null;

    const rows = upcomingCompetitions.map((eventData) => {
        const scheduledAt = eventData.scheduledAt && typeof eventData.scheduledAt.toDate === 'function'
            ? eventData.scheduledAt.toDate()
            : null;
        const hoursUntilCompetition = scheduledAt
            ? Math.max(0, (scheduledAt.getTime() - Date.now()) / 36e5)
            : null;
        const hoursSinceCoaching = lastTouchAt
            ? Math.max(0, (Date.now() - lastTouchAt.getTime()) / 36e5)
            : null;

        return {
            eventId: eventData.id,
            title: eventData.title || '',
            sport: normalizeSport(eventData.sport),
            modality: normalizeModality(eventData.modality),
            scheduledAt: scheduledAt,
            hoursUntilCompetition: hoursUntilCompetition !== null ? Number(hoursUntilCompetition.toFixed(2)) : null,
            lastCoachingAt: lastTouchAt,
            hoursSinceLastCoaching: hoursSinceCoaching !== null ? Number(hoursSinceCoaching.toFixed(2)) : null,
            readinessGapHours: lastTouchAt && scheduledAt
                ? Number(Math.max(0, (scheduledAt.getTime() - lastTouchAt.getTime()) / 36e5).toFixed(2))
                : null,
            challengeHint: String((eventData.metadata && eventData.metadata.type) || '').toLowerCase().includes('challenge') || String(eventData.title || '').toLowerCase().includes('challenge'),
        };
    });

    const averageGapHours = rows.length > 0
        ? Number((rows.reduce((sum, row) => sum + (row.readinessGapHours || 0), 0) / rows.length).toFixed(2))
        : 0;

    const response = {
        userId,
        userTopSports,
        lastCoachingTouch,
        upcomingCompetitions: rows,
        averageGapHours,
        checkedAt: now,
        note: 'BQ5 usa coach_requests.createdAt como ultima senal persistida de coaching/tutoria porque no existe una coleccion separada de sesiones confirmadas en el proyecto.'
    };

    await BQ5_GLOBAL_DOC.set({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastQueryBy: userId,
        lastQueryCount: rows.length,
    }, {merge: true});

    return response;
});

// ============================================================================
// BQ5: HISTORIAL DE TIEMPO TRANSCURRIDO AL REGISTRARSE A TORNEOS/RETOS
// ============================================================================
exports.getBq5ReadinessTimeLogs = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para consultar el historial BQ5.');
    }

    const userId = context.auth.uid;
    const limit = Math.max(1, Math.min(50, Number(data && data.limit ? data.limit : 20)));

    const logsSnapshot = await db.collection(BQ5_READINESS_LOG_COLLECTION)
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

    const rows = logsSnapshot.docs.map((doc) => {
        const row = doc.data() || {};
        return {
            id: doc.id,
            userId: row.userId || userId,
            eventId: row.eventId || null,
            eventTitle: row.eventTitle || '',
            eventSport: row.eventSport || '',
            eventModality: row.eventModality || '',
            challengeHint: Boolean(row.challengeHint),
            isUpcomingCompetition: Boolean(row.isUpcomingCompetition),
            registrationDetectedAt: row.registrationDetectedAt || null,
            eventScheduledAt: row.eventScheduledAt || null,
            lastCoachingAt: row.lastCoachingAt || null,
            appRegisteredAt: row.appRegisteredAt || null,
            baselineType: row.baselineType || 'unknown',
            baselineAt: row.baselineAt || null,
            elapsedHoursSinceBaseline: row.elapsedHoursSinceBaseline ?? null,
            elapsedDaysSinceBaseline: row.elapsedDaysSinceBaseline ?? null,
            readinessGapHoursToCompetition: row.readinessGapHoursToCompetition ?? null,
            hasPriorCoaching: Boolean(row.hasPriorCoaching),
            source: row.source || 'onRegistrationChange',
            createdAt: row.createdAt || null,
        };
    });

    return {
        userId,
        count: rows.length,
        logs: rows,
        checkedAt: admin.firestore.Timestamp.now(),
    };
});

// ============================================================================
// BQ6: CAPACIDAD DISPONIBLE DE TORNEOS SEGUN INTERESES DEL USUARIO
// ============================================================================
exports.getBq6UpcomingTournamentCapacity = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para consultar BQ6.');
    }

    const userId = context.auth.uid;
    const now = admin.firestore.Timestamp.now();
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};
    const bq3UserDoc = await db.collection(BQ3_USER_COLLECTION).doc(userId).get();
    const bq3UserData = bq3UserDoc.data() || {};
    const topSports = getUserTopSportsFromProfile(userData, 3);
    const limit = Math.max(1, Number(data && data.limit ? data.limit : 20));
    const lowCapacityThreshold = Math.max(1, Number(data && data.lowCapacityThreshold ? data.lowCapacityThreshold : 3));
    const highUtilizationThreshold = clamp(Number(data && data.highUtilizationThreshold ? data.highUtilizationThreshold : 85), 1, 100);

    let candidateSports = topSports;
    if (candidateSports.length === 0) {
        candidateSports = Object.keys(userData.inferredPreferences || {})
            .map((sport) => normalizeSport(sport))
            .filter((sport) => sport.length > 0)
            .slice(0, 3);
    }

    if (candidateSports.length === 0) {
        candidateSports = ['futbol'];
    }

    const inferredPreferences = userData && typeof userData.inferredPreferences === 'object'
        ? userData.inferredPreferences
        : {};
    const bq3Sports = bq3UserData && typeof bq3UserData.sports === 'object'
        ? bq3UserData.sports
        : {};
    const intentBySport = candidateSports.reduce((accumulator, sport) => {
        const summary = buildBq6IntentSummaryForSport({
            sport,
            inferredPreferences,
            bq3Sports,
        });
        accumulator[summary.sport] = summary;
        return accumulator;
    }, {});

    const competitionSnapshot = await db.collection('events')
        .where('status', '==', 'active')
        .where('modality', '==', 'tournament')
        .where('sport', 'in', candidateSports.slice(0, 10))
        .orderBy('scheduledAt', 'asc')
        .limit(100)
        .get();

    const upcomingTournaments = competitionSnapshot.docs
        .map((doc) => ({id: doc.id, ...doc.data()}))
        .filter((eventData) => isFutureTimestamp(eventData.scheduledAt, now))
        .filter((eventData) => {
            const participants = Array.isArray(eventData.participants) ? eventData.participants : [];
            return !participants.includes(userId);
        })
        .map((eventData) => {
            const availableCapacity = getAvailableCapacity(eventData);
            const maxParticipants = Number(eventData.maxParticipants || 0);
            const utilization = maxParticipants > 0
                ? Number((((maxParticipants - availableCapacity) / maxParticipants) * 100).toFixed(2))
                : 0;

            return {
                eventId: eventData.id,
                title: eventData.title || '',
                sport: normalizeSport(eventData.sport),
                scheduledAt: eventData.scheduledAt && typeof eventData.scheduledAt.toDate === 'function'
                    ? eventData.scheduledAt.toDate()
                    : null,
                maxParticipants,
                currentParticipants: Array.isArray(eventData.participants) ? eventData.participants.length : 0,
                availableCapacity,
                utilizationPercent: utilization,
                urgencyLevel: availableCapacity <= lowCapacityThreshold || utilization >= highUtilizationThreshold
                    ? (availableCapacity <= 1 || utilization >= 95 ? 'critical' : 'high')
                    : 'normal',
            };
        })
        .slice(0, limit);

    const tournamentsWithIntent = upcomingTournaments.map((tournament) => {
        const intent = intentBySport[tournament.sport] || buildBq6IntentSummaryForSport({
            sport: tournament.sport,
            inferredPreferences,
            bq3Sports,
        });
        const urgentByCapacity = tournament.availableCapacity <= lowCapacityThreshold;
        const urgentByUtilization = tournament.utilizationPercent >= highUtilizationThreshold;
        const shouldTriggerUrgencyNotification = intent.hasDemonstratedIntent
            && tournament.availableCapacity > 0
            && (urgentByCapacity || urgentByUtilization);

        return {
            ...tournament,
            intentScore: intent.intentScore,
            hasDemonstratedIntent: intent.hasDemostradoIntent,
            urgencyReasons: {
                lowCapacity: urgentByCapacity,
                highUtilization: urgentByUtilization,
            },
            shouldTriggerUrgencyNotification,
        };
    });

    const totalAvailableCapacity = tournamentsWithIntent.reduce((sum, tournament) => sum + tournament.availableCapacity, 0);

    const capacityBySport = tournamentsWithIntent.reduce((accumulator, tournament) => {
        const sport = tournament.sport || 'unknown';
        if (!accumulator[sport]) {
            accumulator[sport] = {
                availableCapacity: 0,
                events: 0,
                demonstratedIntentEvents: 0,
                avgIntentScore: 0,
                totalIntentScore: 0,
            };
        }

        accumulator[sport].availableCapacity += tournament.availableCapacity;
        accumulator[sport].events += 1;
        accumulator[sport].demonstratedIntentEvents += tournament.hasDemonstratedIntent ? 1 : 0;
        accumulator[sport].totalIntentScore += tournament.intentScore;
        return accumulator;
    }, {});

    Object.keys(capacityBySport).forEach((sport) => {
        const bucket = capacityBySport[sport];
        bucket.avgIntentScore = bucket.events > 0
            ? Number((bucket.totalIntentScore / bucket.events).toFixed(2))
            : 0;
        delete bucket.totalIntentScore;
    });

    const urgencyNotificationCandidates = tournamentsWithIntent
        .filter((tournament) => tournament.shouldTriggerUrgencyNotification)
        .map((tournament) => ({
            userId,
            eventId: tournament.eventId,
            eventTitle: tournament.title,
            sport: tournament.sport,
            availableCapacity: tournament.availableCapacity,
            utilizationPercent: tournament.utilizationPercent,
            urgencyLevel: tournament.urgencyLevel,
            intentScore: tournament.intentScore,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            generatedAt: admin.firestore.Timestamp.now(),
            status: 'pending',
            source: 'getBq6UpcomingTournamentCapacity',
        }));

    if (urgencyNotificationCandidates.length > 0) {
        const batch = db.batch();
        urgencyNotificationCandidates.forEach((candidate) => {
            const queueDocId = `${candidate.userId}_${candidate.eventId}`;
            const queueRef = db.collection(BQ6_URGENCY_QUEUE_COLLECTION).doc(queueDocId);
            batch.set(queueRef, candidate, {merge: true});
        });
        await batch.commit();
    }

    const response = {
        userId,
        candidateSports,
        upcomingTournaments: tournamentsWithIntent,
        totalAvailableCapacity,
        capacityBySport,
        urgencyRules: {
            lowCapacityThreshold,
            highUtilizationThreshold,
            requiresDemonstratedIntent: true,
        },
        urgencyNotificationCandidates,
        totalUrgencyCandidates: urgencyNotificationCandidates.length,
        intentBySport,
        checkedAt: now,
        note: 'BQ6 cruza deportes de mayor interaccion con capacidad en torneos proximos y genera candidatos de urgencia solo si hay intencion demostrada.'
    };

    await BQ6_GLOBAL_DOC.set({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastQueryBy: userId,
        lastQueryCount: tournamentsWithIntent.length,
        totalAvailableCapacity,
        totalUrgencyCandidates: urgencyNotificationCandidates.length,
        urgencyRules: response.urgencyRules,
    }, {merge: true});

    return response;
});

// ============================================================================
// REGLA 2 Y 3: REGISTRO (+5) Y CANCELACIÓN (-3 con límite 0)
// ============================================================================
exports.onRegistrationChange = functions.firestore
    .document('events/{eventId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const sport = newData.sport;

        if (!sport) return null;

        const newUsers = newData.participants || [];
        const oldUsers = oldData.participants || [];

        // REGLA 2: Alguien se registró (+5)
        if (newUsers.length > oldUsers.length) {
            const addedUsers = newUsers.filter((uid) => !oldUsers.includes(uid));
            const registrationDetectedAt = admin.firestore.Timestamp.now();
            const shouldTrackBq5 = isUpcomingCompetition(newData, registrationDetectedAt);

            await Promise.all(addedUsers.map(async (userId) => {
                await Promise.all([
                    db.collection('users').doc(userId).update({
                        [`inferredPreferences.${sport}`]: admin.firestore.FieldValue.increment(5),
                        [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
                    }),
                    incrementBq3SportCount({
                        userId,
                        sport,
                        source: 'event_joined',
                        amount: 1
                    })
                ]);

                if (shouldTrackBq5) {
                    await registerBq5ReadinessLog({
                        userId,
                        eventId: context.params.eventId,
                        eventData: newData,
                        registeredAt: registrationDetectedAt,
                    });
                }
            }));

            return null;
        }

        // REGLA 3: Alguien canceló su participación (-2)
        if (newUsers.length < oldUsers.length) {
            const userId = oldUsers.find(uid => !newUsers.includes(uid));
            if (userId) {
                const userRef = db.collection('users').doc(userId);
                const userSnap = await userRef.get();

                if (userSnap.exists) {
                    const userData = userSnap.data();
                    const currentScore = (userData.inferredPreferences && userData.inferredPreferences[sport]) || 0;

                    // Calculamos el nuevo puntaje asegurando que el mínimo sea 0
                    const newScore = Math.max(0, currentScore - 5);

                    return userRef.update({
                        [`inferredPreferences.${sport}`]: newScore
                    });
                }
            }
        }

        return null;
    });

// ============================================================================
// BQ3: REPORTE DEL DEPORTE MAS AGENDADO
// ============================================================================
exports.getBq3MostScheduledSport = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para consultar BQ3.');
    }

    const scope = String(data && data.scope ? data.scope : 'user').trim().toLowerCase();
    const requestedSources = Array.isArray(data && data.sources)
        ? data.sources
            .map((source) => String(source || '').trim().toLowerCase())
            .filter((source) => source.length > 0)
        : [];
    const hasSourceFilter = requestedSources.length > 0;
    const userId = context.auth.uid;
    const sourceRef = scope === 'global'
        ? BQ3_GLOBAL_DOC
        : db.collection(BQ3_USER_COLLECTION).doc(userId);

    const sourceSnap = await sourceRef.get();
    const sourceData = sourceSnap.data() || {};
    let sports = sourceData.sports || {};

    // Backfill on-demand para scope user cuando aun no existen agregados.
    if (scope === 'user' && Object.keys(sports).length === 0) {
        sports = await rebuildBq3UserFromHistory(userId);
    }

    const ranking = Object.entries(sports)
        .map(([sport, payload]) => {
            const sourceBreakdown = payload && payload.sources ? payload.sources : {};
            const total = hasSourceFilter
                ? requestedSources.reduce((sum, source) => {
                    return sum + Number(sourceBreakdown[source] || 0);
                }, 0)
                : Number(payload && payload.total ? payload.total : 0);

            return {
                sport,
                total,
                sourceBreakdown,
            };
        })
        .filter((item) => item.total > 0)
        .sort((a, b) => b.total - a.total);

    const topEntry = ranking.length > 0 ? ranking[0] : null;
    const topSport = topEntry ? topEntry.sport : null;
    const topCount = topEntry ? topEntry.total : 0;
    const topSources = topEntry ? topEntry.sourceBreakdown : {};

    return {
        scope,
        userId: scope === 'global' ? null : userId,
        appliedSources: hasSourceFilter ? requestedSources : ['all'],
        hasData: ranking.length > 0,
        mostScheduledSport: topSport,
        totalSchedules: topCount,
        sourceBreakdown: topSources,
        ranking,
        recommendedHomeFeedSport: topSport,
        sports
    };
});

// ============================================================================
// BQ4: REGISTRAR ENVIO DE NOTIFICACION AUTOMATICA
// ============================================================================
exports.logAutomatedNotificationSent = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para registrar notificaciones.');
    }

    const notificationId = String(data && data.notificationId ? data.notificationId : '').trim();
    const eventId = String(data && data.eventId ? data.eventId : '').trim();
    const userId = String(data && data.userId ? data.userId : context.auth.uid).trim();
    const modality = normalizeModality(data && data.modality);
    const source = String(data && data.source ? data.source : 'automated').trim();

    // Payload minimo requerido para poder atribuir una futura conversion.
    if (!notificationId || !eventId || !userId) {
        throw new functions.https.HttpsError('invalid-argument', 'notificationId, eventId y userId son requeridos.');
    }

    const now = admin.firestore.Timestamp.now();

    await db.collection(BQ4_NOTIFICATION_COLLECTION).doc(notificationId).set({
        notificationId,
        eventId,
        userId,
        modality,
        source,
        sentAt: now,
        openedAt: null,
        clickedAt: null,
        convertedAt: null,
        converted: false,
        updatedAt: now
    }, {merge: true});

    // Solo torneos cuentan para el KPI pedido por BQ4.
    if (modality === 'tournament') {
        await BQ4_GLOBAL_DOC.set({
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            notificationsSent: admin.firestore.FieldValue.increment(1),
            [`sentBySource.${source}`]: admin.firestore.FieldValue.increment(1)
        }, {merge: true});

        await refreshBq4GlobalSummary();
    }

    return {success: true, notificationId};
});

// ============================================================================
// BQ4: REGISTRAR APERTURA/CLICK DE NOTIFICACION AUTOMATICA
// ============================================================================
exports.logAutomatedNotificationInteraction = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para registrar interacción.');
    }

    const notificationId = String(data && data.notificationId ? data.notificationId : '').trim();
    const interactionType = String(data && data.interactionType ? data.interactionType : '').trim().toLowerCase();

    // Se registran eventos de embudo (opened/clicked) para trazabilidad.
    if (!notificationId || !['opened', 'clicked'].includes(interactionType)) {
        throw new functions.https.HttpsError('invalid-argument', 'notificationId e interactionType (opened|clicked) son requeridos.');
    }

    const notificationRef = db.collection(BQ4_NOTIFICATION_COLLECTION).doc(notificationId);
    const notificationSnap = await notificationRef.get();

    if (!notificationSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'No se encontró la notificación para registrar interacción.');
    }

    const now = admin.firestore.Timestamp.now();
    const fieldName = interactionType === 'clicked' ? 'clickedAt' : 'openedAt';

    await notificationRef.set({
        [fieldName]: now,
        updatedAt: now
    }, {merge: true});

    return {success: true, notificationId, interactionType};
});

// ============================================================================
// BQ4: ATRIBUIR REGISTRO EFECTIVO EN TORNEOS A NOTIFICACION AUTOMATICA
// ============================================================================
exports.onTournamentRegistrationForBq4 = functions.firestore
    .document('events/{eventId}')
    .onUpdate(async (change, context) => {
        const afterData = change.after.data();
        const beforeData = change.before.data();

        // BQ4 aplica solo a torneos.
        const modality = normalizeModality(afterData.modality);
        if (modality !== 'tournament') {
            return null;
        }

        const eventId = context.params.eventId;
        const newParticipants = afterData.participants || [];
        const oldParticipants = beforeData.participants || [];
        const addedUsers = newParticipants.filter(uid => !oldParticipants.includes(uid));

        if (!addedUsers.length) {
            return null;
        }

        const now = admin.firestore.Timestamp.now();

        for (const userId of addedUsers) {
            // Idempotencia: evita doble conteo por evento+usuario.
            const conversionRef = db.collection(BQ4_CONVERSION_COLLECTION).doc(`${eventId}_${userId}`);
            const conversionSnap = await conversionRef.get();
            if (conversionSnap.exists) {
                continue;
            }

            const notificationsSnap = await db.collection(BQ4_NOTIFICATION_COLLECTION)
                .where('eventId', '==', eventId)
                .get();

            // Toma la notificacion mas reciente del usuario para ese evento.
            const tournamentUserNotifications = notificationsSnap.docs
                .filter((doc) => {
                    const payload = doc.data() || {};
                    return payload.userId === userId && payload.modality === 'tournament';
                })
                .sort((a, b) => {
                    const aSent = a.data().sentAt;
                    const bSent = b.data().sentAt;
                    const aMillis = aSent && aSent.toMillis ? aSent.toMillis() : 0;
                    const bMillis = bSent && bSent.toMillis ? bSent.toMillis() : 0;
                    return bMillis - aMillis;
                });

            if (!tournamentUserNotifications.length) {
                continue;
            }

            const notificationDoc = tournamentUserNotifications[0];
            const notificationData = notificationDoc.data();

            if (!notificationData || !notificationData.notificationId) {
                continue;
            }
            const source = String(notificationData.source || 'automated');

            await Promise.all([
                conversionRef.set({
                    eventId,
                    userId,
                    notificationId: notificationDoc.id,
                    source,
                    convertedAt: now
                }),
                notificationDoc.ref.set({
                    converted: true,
                    convertedAt: now,
                    updatedAt: now
                }, {merge: true}),
                BQ4_GLOBAL_DOC.set({
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    effectiveRegistrations: admin.firestore.FieldValue.increment(1),
                    [`conversionsBySource.${source}`]: admin.firestore.FieldValue.increment(1)
                }, {merge: true})
            ]);

            await refreshBq4GlobalSummary();
        }

        return null;
    });

// ============================================================================
// BQ4: REPORTE DE CONVERSION DE NOTIFICACIONES A REGISTROS EN TORNEOS
// ============================================================================
exports.getBq4TournamentNotificationConversion = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para consultar BQ4.');
    }

    const globalSnap = await BQ4_GLOBAL_DOC.get();
    const globalData = globalSnap.data() || {};

    // Formula BQ4:
    // conversionRate = (effectiveRegistrations / notificationsSent) * 100
    const notificationsSent = Number(globalData.notificationsSent || 0);
    const effectiveRegistrations = Number(globalData.effectiveRegistrations || 0);
    const conversionRate = notificationsSent > 0
        ? Number(((effectiveRegistrations / notificationsSent) * 100).toFixed(2))
        : 0;

    await BQ4_GLOBAL_DOC.set({
        summaryScope: 'global',
        notificationsSent,
        effectiveRegistrations,
        conversionRate,
        sentBySource: globalData.sentBySource || {},
        conversionsBySource: globalData.conversionsBySource || {},
        summaryUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        summaryFormula: 'conversionRate = (effectiveRegistrations / notificationsSent) * 100',
    }, {merge: true});

    return {
        notificationsSent,
        effectiveRegistrations,
        conversionRate,
        sentBySource: globalData.sentBySource || {},
        conversionsBySource: globalData.conversionsBySource || {},
        formula: 'conversionRate = (effectiveRegistrations / notificationsSent) * 100'
    };
});

// ============================================================================
// REGLA 4: BUSCAR UN EVENTO DEPORTIVO (+1)
// ============================================================================
exports.logSportSearch = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Debes iniciar sesión para buscar.');
    }

    const userId = context.auth.uid;
    const sport = data.sport;

    if (!sport) {
        throw new functions.https.HttpsError('invalid-argument', 'El nombre del deporte es requerido.');
    }

    await db.collection('users').doc(userId).update({
        [`inferredPreferences.${sport}`]: admin.firestore.FieldValue.increment(1),
        [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: `Búsqueda de ${sport} registrada.` };
});

// ============================================================================
// REGLA 5: INACTIVIDAD DE 2 SEMANAS (-4 con límite 0)
// ============================================================================
exports.checkInactivity = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('America/Bogota')
    .onRun(async (context) => {
        const twoWeeksAgo = new Date();
        twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

        const usersSnap = await db.collection('users').get();
        const batch = db.batch();
        let operationsCount = 0;

        usersSnap.forEach(userDoc => {
            const userData = userDoc.data();
            const lastActivity = userData.lastActivity || {};
            const inferredPreferences = userData.inferredPreferences || {};

            Object.keys(lastActivity).forEach(sport => {
                const activityDate = lastActivity[sport].toDate();

                if (activityDate < twoWeeksAgo) {
                    const currentScore = inferredPreferences[sport] || 0;

                    // Aseguramos que la resta por inactividad no lo baje de cero
                    const newScore = Math.max(0, currentScore - 5);

                    batch.update(userDoc.ref, {
                        [`inferredPreferences.${sport}`]: newScore,
                        [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
                    });
                    operationsCount++;
                }
            });
        });

        if (operationsCount > 0) {
            await batch.commit();
        }

        console.log(`Penalizaciones por inactividad aplicadas: ${operationsCount}`);
        return null;
    });

// ============================================================================
// REGLA 6: LIMPIEZA DE EVENTOS PASADOS
// ============================================================================
exports.cleanupPastEvents = functions.pubsub
    .schedule('every 1 hours')
    .timeZone('America/Bogota')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();

        const querySnapshot = await db.collection('events')
            .where('status', '==', 'active')
            .where('scheduledAt', '<', now)
            .get();

        if (querySnapshot.empty) {
            console.log('No hay eventos pasados para desactivar.');
            return null;
        }

        const batch = db.batch();

        querySnapshot.forEach((doc) => {
            batch.update(doc.ref, { status: 'inactive' });
        });

        await batch.commit();
        console.log(`Se han desactivado ${querySnapshot.size} eventos.`);
        return null;
    });

// ============================================================================
// SMART MATCHMAKING: RECOMENDACIONES AUTOMATICAS DIARIAS
// ============================================================================
function toPlainDate(input) {
    const date = input && typeof input.toDate === 'function' ? input.toDate() : input;
    if (!(date instanceof Date)) return null;
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function buildSmartMatchPrompt(userProfile, freeSlots, todayEvents) {
    return `
Eres un motor de Smart Matchmaking de UniandesSport y copywriter personalizado.
Contexto clave: el usuario es estudiante universitario (ej. Ingenieria de Software, 8vo semestre).
Usa jerga de la Universidad de los Andes (ej. "hueco", "edificio ML", "entregas") cuando tenga sentido.

Datos del usuario:
${JSON.stringify(userProfile, null, 2)}

Bloques libres del usuario:
${JSON.stringify(freeSlots, null, 2)}

Eventos deportivos disponibles hoy:
${JSON.stringify(todayEvents, null, 2)}

Tu tarea:
1) Evalua si conviene recomendar que se una a un evento existente o que cree uno nuevo.
2) Si recomiendas JOIN, devuelve un evento_id valido de la lista de hoy.
3) Si recomiendas CREATE, devuelve un borrador con deporte, hora_inicio y lugar.
4) Redacta ui_title, ui_body y cta_text como copywriter empatico y persuasivo.

Responde SOLO JSON ESTRICTO con esta estructura:
{
  "tipo_recomendacion": "join" | "create",
  "evento_id": "string o null",
  "borrador_evento": {"deporte":"", "hora_inicio":"", "lugar":""},
  "ui_title": "",
  "ui_body": "",
  "cta_text": ""
}
`;
}

function sanitizeGeminiJson(text) {
    const raw = String(text || '').trim();
    if (!raw.startsWith('```')) return raw;
    return raw
        .split('\n')
        .filter((line) => !line.trim().startsWith('```'))
        .join('\n')
        .trim();
}

function collectFcmTokens(userData) {
    const tokens = new Set();
    const rawSingle = ['fcmToken', 'notificationToken', 'pushToken'];
    const rawList = ['fcmTokens', 'notificationTokens'];

    rawSingle.forEach((key) => {
        const value = userData && userData[key];
        if (typeof value === 'string' && value.trim()) {
            tokens.add(value.trim());
        }
    });

    rawList.forEach((key) => {
        const value = userData && userData[key];
        if (Array.isArray(value)) {
            value.forEach((token) => {
                if (typeof token === 'string' && token.trim()) {
                    tokens.add(token.trim());
                }
            });
        }
    });

    return Array.from(tokens);
}

function buildFallbackSmartRecommendation(userProfile, freeSlots, todayEvents) {
    const firstSlot = Array.isArray(freeSlots) && freeSlots.length > 0 ? freeSlots[0] : null;
    const firstEvent = Array.isArray(todayEvents) && todayEvents.length > 0 ? todayEvents[0] : null;
    const sport = String((userProfile && userProfile.mainSport) || (firstEvent && firstEvent.sport) || 'futbol').trim() || 'futbol';
    const hour = firstSlot && firstSlot.hora_inicio ? String(firstSlot.hora_inicio).trim() : '18:00';
    const location = (firstSlot && firstSlot.lugar) ? String(firstSlot.lugar).trim() : 'Campus';

    if (firstEvent) {
        return {
            tipo_recomendacion: 'join',
            evento_id: firstEvent.id,
            borrador_evento: null,
            ui_title: `Your best match today: ${firstEvent.title || 'available event'}`,
            ui_body: `You have a free slot around ${hour}. Joining this event could fit your day without affecting your other plans.`,
            cta_text: 'View event',
        };
    }

    return {
        tipo_recomendacion: 'create',
        evento_id: null,
        borrador_evento: {
            deporte: sport,
            hora_inicio: hour,
            lugar: location,
        },
        ui_title: 'You have a good window to create a match',
        ui_body: `It looks like you have a useful gap around ${hour}. Create a quick match and invite people who are also free.`,
        cta_text: 'Create event',
    };
}

exports.dailyMatchmaker = functions.pubsub
    .schedule('every day 07:30')
    .timeZone('America/Bogota')
    .onRun(async () => {
        let GoogleGenerativeAI;
        try {
            ({GoogleGenerativeAI} = require('@google/generative-ai'));
        } catch (error) {
            console.error('[dailyMatchmaker] Missing module @google/generative-ai. Run npm install in functions/.', error);
            return null;
        }

        const apiKey = process.env.GEMINI_API_KEY || GEMINI_API_KEY;
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: GEMINI_MODEL});

        const now = new Date();
        const today = toPlainDate(now);
        const nowTs = admin.firestore.Timestamp.now();

        const [usersSnap, eventsSnap] = await Promise.all([
            db.collection(USERS_COLLECTION).get(),
            db.collection(EVENTS_COLLECTION).where('status', '==', 'active').get(),
        ]);

        const eventsToday = eventsSnap.docs
            .map((doc) => ({id: doc.id, ...doc.data()}))
            .filter((event) => {
                const eventDate = toPlainDate(event.scheduledAt);
                return eventDate === today;
            })
            .map((event) => ({
                id: event.id,
                title: event.title || '',
                sport: event.sport || '',
                modality: event.modality || '',
                location: event.location || '',
                scheduledAt: event.scheduledAt || null,
                maxParticipants: Number(event.maxParticipants || 0),
                currentParticipants: Array.isArray(event.participants) ? event.participants.length : 0,
            }));

        const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
        const generateWithRetry = async (prompt, attempts = 3) => {
            let lastError;
            for (let i = 0; i < attempts; i++) {
                try {
                    return await model.generateContent(prompt);
                } catch (error) {
                    lastError = error;
                    const status = Number(error && error.status ? error.status : 0);
                    const retryable = status === 503 || status === 429 || String(error && error.message || '').includes('Service Unavailable');
                    if (!retryable || i === attempts - 1) {
                        throw error;
                    }
                    await sleep(750 * (i + 1));
                }
            }
            throw lastError;
        };

        for (const userDoc of usersSnap.docs) {
            const userData = userDoc.data() || {};
            if (userData.active === false) continue;

            const freeSlots = Array.isArray(userData.free_time_slots) ? userData.free_time_slots : [];
            if (freeSlots.length === 0) continue;

            const prompt = buildSmartMatchPrompt(
                {
                    uid: userDoc.id,
                    fullName: userData.fullName || '',
                    program: userData.program || '',
                    semester: userData.semester || null,
                },
                freeSlots,
                eventsToday,
            );

            try {
                const response = await generateWithRetry(prompt);
                const text = response.response && response.response.text ? response.response.text() : '';
                const cleaned = sanitizeGeminiJson(text);
                const payload = JSON.parse(cleaned);

                const recommendation = {
                    tipo_recomendacion: payload.tipo_recomendacion === 'create' ? 'create' : 'join',
                    evento_id: payload.evento_id || null,
                    borrador_evento: payload.borrador_evento || {
                        deporte: '',
                        hora_inicio: '',
                        lugar: '',
                    },
                    ui_title: String(payload.ui_title || ''),
                    ui_body: String(payload.ui_body || ''),
                    cta_text: String(payload.cta_text || ''),
                    generatedAt: nowTs,
                    source: 'dailyMatchmaker',
                };

                await db.collection(SMART_RECOMMENDATION_COLLECTION)
                    .doc(userDoc.id)
                    .set(recommendation, {merge: true});

                await db.collection(USERS_COLLECTION)
                    .doc(userDoc.id)
                    .set({
                        smart_recommendation: recommendation,
                    }, {merge: true});

                const tokens = collectFcmTokens(userData);
                if (tokens.length > 0) {
                    await admin.messaging().sendToDevice(tokens, {
                        notification: {
                            title: recommendation.ui_title,
                            body: recommendation.ui_body,
                        },
                        data: {
                            tipo_recomendacion: recommendation.tipo_recomendacion,
                            evento_id: recommendation.evento_id ? String(recommendation.evento_id) : '',
                            borrador_evento: JSON.stringify(recommendation.borrador_evento || {}),
                            ui_title: recommendation.ui_title,
                            ui_body: recommendation.ui_body,
                            cta_text: recommendation.cta_text,
                        },
                    });
                }

                await db.collection(SMART_MATCH_LOG_COLLECTION).add({
                    userId: userDoc.id,
                    success: true,
                    recommendation,
                    createdAt: nowTs,
                });
            } catch (error) {
                console.error('[dailyMatchmaker] user=', userDoc.id, error);
                const fallback = buildFallbackSmartRecommendation(
                    {
                        uid: userDoc.id,
                        mainSport: userData.mainSport || null,
                    },
                    freeSlots,
                    eventsToday,
                );

                const fallbackRecommendation = {
                    ...fallback,
                    generatedAt: nowTs,
                    source: 'dailyMatchmaker_fallback',
                };

                await db.collection(SMART_RECOMMENDATION_COLLECTION)
                    .doc(userDoc.id)
                    .set(fallbackRecommendation, {merge: true});

                await db.collection(USERS_COLLECTION)
                    .doc(userDoc.id)
                    .set({
                        smart_recommendation: fallbackRecommendation,
                    }, {merge: true});

                try {
                    await db.collection(SMART_MATCH_LOG_COLLECTION).add({
                        userId: userDoc.id,
                        success: false,
                        error: String(error && error.message ? error.message : error),
                        fallbackApplied: true,
                        recommendation: fallbackRecommendation,
                        createdAt: nowTs,
                    });
                } catch (logError) {
                    console.error('[dailyMatchmaker] failed to log error for user=', userDoc.id, logError);
                }
            }
        }

        return null;
    });

