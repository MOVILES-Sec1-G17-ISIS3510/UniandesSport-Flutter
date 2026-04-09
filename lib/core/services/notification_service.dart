import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  bool _initialized = false;

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
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
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
      notificationId.hashCode.abs(),
      'Evento generado',
      body,
      notificationDetails,
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
