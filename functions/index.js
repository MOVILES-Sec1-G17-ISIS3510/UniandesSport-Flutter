const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Inicializa el SDK de administración
admin.initializeApp();
const db = admin.firestore();

const BQ_COLLECTION = 'business_metrics';
const BQ3_USER_COLLECTION = 'bq3_user_sport_counts';
const BQ4_NOTIFICATION_COLLECTION = 'bq4_automated_notifications';
const BQ4_CONVERSION_COLLECTION = 'bq4_notification_conversions';
const BQ3_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq3_global');
const BQ4_GLOBAL_DOC = db.collection(BQ_COLLECTION).doc('bq4_global');

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

    return null;
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

        // REGLA 2: Alguien se registró (+3)
        if (newUsers.length > oldUsers.length) {
            const userId = newUsers.find(uid => !oldUsers.includes(uid));
            if (userId) {
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

                return null;
            }
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
    const userId = context.auth.uid;
    const sourceRef = scope === 'global'
        ? BQ3_GLOBAL_DOC
        : db.collection(BQ3_USER_COLLECTION).doc(userId);

    const sourceSnap = await sourceRef.get();
    const sourceData = sourceSnap.data() || {};
    const sports = sourceData.sports || {};

    let topSport = null;
    let topCount = 0;
    let topSources = {};

    // Selecciona el deporte con mayor conteo total.
    // Nota: en empate prevalece el primer maximo iterado.
    Object.entries(sports).forEach(([sport, payload]) => {
        const total = Number(payload && payload.total ? payload.total : 0);
        if (total > topCount) {
            topSport = sport;
            topCount = total;
            topSources = payload && payload.sources ? payload.sources : {};
        }
    });

    return {
        scope,
        userId: scope === 'global' ? null : userId,
        mostScheduledSport: topSport,
        totalSchedules: topCount,
        sourceBreakdown: topSources,
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