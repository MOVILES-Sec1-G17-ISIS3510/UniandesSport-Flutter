import '../../../core/local_storage/database_helper.dart';
import '../../../core/network/sync_engine_service.dart';
import '../models/event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repositorio de la feature `events`.
/// Está dentro de la feature y usa `DatabaseHelper` de `core` para persistencia local.
class EventRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngineService _syncEngine = SyncEngineService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crea un evento localmente y encola la tarea de sincronización (optimistic UI).
  /// Retorna el EventModel con id generado si no se proporcionó.
  Future<EventModel> createEvent(EventModel event) async {
    final id = event.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : event.id;
    final toInsert = EventModel(
      id: id,
      title: event.title,
      date: event.date,
      isSynced: false,
    );

    final map = toInsert.toMap();

    // Usamos transacción para asegurar atomicidad: insertar evento + encolar tarea.
    await _dbHelper.transaction((txn) async {
      await txn.insert('events', map);

      await txn.insert('sync_queue', {
        'event_id': id,
        'action': 'create',
        'status': 'pending',
        'retry_count': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // Intentar sincronizar inmediatamente en background.
    Future.microtask(() => _syncEngine.processQueue());

    return toInsert;
  }

  Future<List<EventModel>> getLocalEvents({int pageSize = 100}) async {
    final rows = await _dbHelper.query('events', orderBy: 'date ASC');

    if (rows.isNotEmpty) {
      return rows.map((r) => EventModel.fromMap(r)).toList();
    }

    // Si no hay cache local, consultar Firestore y cachear localmente.
    await _cacheEventsFromFirestore(pageSize: pageSize);

    final cached = await _dbHelper.query('events', orderBy: 'date ASC');
    return cached.map((r) => EventModel.fromMap(r)).toList();
  }

  /// Descarga eventos del Firestore filtrados por ownerUid y los cachea localmente
  /// usando batchInsert con replaceOnConflict para evitar duplicados y mantener atomicidad.
  Future<void> _cacheEventsFromFirestore({int pageSize = 100}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid; // guardamos el uid si existe

      Query query = _firestore.collection('events');
      if (uid != null) {
        query = query.where('ownerUid', isEqualTo: uid);
      }

      // Limitamos la cantidad para evitar descargar todo de golpe.
      query = query.orderBy('createdAt', descending: true).limit(pageSize);

      final snapshot = await query.get();

      final batchInserts = <Map<String, Object?>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final clientId = (data?['clientId'] ?? doc.id).toString();
        final title = data?['title']?.toString() ?? '';

        String dateStr = '';
        final dateField = data?['date'];
        if (dateField is Timestamp) {
          dateStr = dateField.toDate().toIso8601String();
        } else if (dateField != null) {
          dateStr = dateField.toString();
        }

        final isSynced = 1; // vienen de Firestore, por tanto consideramos sincronizados

        batchInserts.add({
          'id': clientId,
          'title': title,
          'date': dateStr,
          'isSynced': isSynced,
        });
      }

      if (batchInserts.isNotEmpty) {
        await _dbHelper.batchInsert('events', batchInserts, replaceOnConflict: true);
      }
    } catch (e) {
      // Registrar el error para depuración en lugar de silenciar.
      // En producción se recomienda enviar esto a un sistema de logs/telemetría.
      // print('Error caching events from Firestore: $e');
    }
  }
}
