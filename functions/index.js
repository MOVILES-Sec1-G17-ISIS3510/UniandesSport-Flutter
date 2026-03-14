const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Inicializa el SDK de administración
admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// REGLA 1: CREAR UNA PARTIDA (+8)
// ============================================================================
exports.onEventCreated = functions.firestore
    .document('events/{eventId}')
    .onCreate(async (snap, context) => {
        const eventData = snap.data();
        const creatorId = eventData.creatorId;
        const sport = eventData.sport;

        if (!creatorId || !sport) return null;

        return db.collection('users').doc(creatorId).update({
            [`inferredPreferences.${sport}`]: admin.firestore.FieldValue.increment(8),
            [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
        });
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
                return db.collection('users').doc(userId).update({
                    [`inferredPreferences.${sport}`]: admin.firestore.FieldValue.increment(5),
                    [`lastActivity.${sport}`]: admin.firestore.FieldValue.serverTimestamp()
                });
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