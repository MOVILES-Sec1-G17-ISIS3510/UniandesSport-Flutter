import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio centralizado para notificaciones locales y trazabilidad BQ4.
///
/// Esta capa se encarga de dos responsabilidades:
/// 1. Mostrar una notificacion local en el celular cuando se crea un evento.
/// 2. Registrar en backend cuando el usuario abre/toca esa notificacion.
///
/// Importante:
/// - La notificacion se muestra en el dispositivo actual.
/// - El click no navega automaticamente a una pantalla especifica; solo deja
///   trazabilidad del evento en Cloud Functions para la BQ4.
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  bool _remoteNotificationsInitialized = false;

  /// Inicializa el plugin y registra el callback de tap.
  ///
  /// Se llama una sola vez durante el arranque de la app, despues de Firebase.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    await _initializeRemoteNotifications();

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  Future<void> _initializeRemoteNotifications() async {
    if (_remoteNotificationsInitialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      '[NotificationService] Remote permission status: ${settings.authorizationStatus}',
    );

    await _syncFcmTokenForCurrentUser();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _persistToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final title =
          message.notification?.title ??
          message.data['title'] ??
          'UniandesSport';
      final body =
          message.notification?.body ??
          message.data['body'] ??
          'You have a new smart notification.';

      const androidDetails = AndroidNotificationDetails(
        'smart_challenge_channel',
        'Smart challenge notifications',
        channelDescription: 'Real-time smart challenge match notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['challengeId'] ?? message.data['eventId'] ?? '',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageOpened);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteMessageOpened(initialMessage);
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      await _syncFcmTokenForCurrentUser();
    });

    _remoteNotificationsInitialized = true;
  }

  Future<void> _syncFcmTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _persistToken(token);
  }

  Future<void> _persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'notificationToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[NotificationService] Error saving FCM token: $error');
    }
  }

  Future<void> _handleRemoteMessageOpened(RemoteMessage message) async {
    final challengeId = (message.data['challengeId'] ?? '').toString().trim();
    final eventId = (message.data['eventId'] ?? '').toString().trim();

    if (challengeId.isNotEmpty) {
      debugPrint(
        '[NotificationService] Challenge notification opened | challengeId=$challengeId',
      );
      return;
    }

    if (eventId.isNotEmpty) {
      await FirebaseFunctions.instance
          .httpsCallable('logAutomatedNotificationInteraction')
          .call({'notificationId': eventId, 'interactionType': 'opened'});
      debugPrint(
        '[NotificationService] Event notification opened | eventId=$eventId',
      );
    }
  }

  /// Muestra una notificacion local para un evento recien creado.
  ///
  /// [notificationId] se usa tambien como llave de trazabilidad en backend.
  Future<void> showEventCreatedNotification({
    required String notificationId,
    required String eventId,
    required String title,
    required String sport,
    required String modality,
    required String userId,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'event_created_channel',
      'Event created notifications',
      channelDescription: 'Notifications shown when a sport event is created',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final body =
        'Se genero "$title" en $sport ($modality). Toca para registrar la interaccion.';

    await _plugin.show(
      id: notificationId.hashCode.abs(),
      title: 'Evento generado',
      body: body,
      notificationDetails: notificationDetails,
      payload: eventId,
    );

    try {
      await FirebaseFunctions.instance
          .httpsCallable('logAutomatedNotificationSent')
          .call({
            'notificationId': notificationId,
            'eventId': eventId,
            'userId': userId,
            'modality': modality,
            'source': 'event_created_local_notification',
          });
    } catch (e) {
      debugPrint(
        '[NotificationService] No se pudo registrar envio de notificacion: $e',
      );
    }
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final eventId = response.payload;
    if (eventId == null || eventId.trim().isEmpty) {
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        return;
      }

      // Usamos eventId como notificationId para conservar trazabilidad simple.
      await FirebaseFunctions.instance
          .httpsCallable('logAutomatedNotificationInteraction')
          .call({'notificationId': eventId, 'interactionType': 'clicked'});
      debugPrint(
        '[NotificationService] Notification clicked | eventId=$eventId',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] No se pudo registrar click de notificacion: $e',
      );
    }
  }
}
