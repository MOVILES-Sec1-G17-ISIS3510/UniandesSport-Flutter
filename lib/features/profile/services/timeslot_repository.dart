import 'dart:convert';
import '../../../core/local_storage/database_helper.dart';
import '../models/timeslot_model.dart';
import 'timeslot_hive_service.dart';

class TimeslotRepository {
  final TimeslotHiveService hiveService;
  final DatabaseHelper databaseHelper;

  TimeslotRepository({
    required this.hiveService,
    required this.databaseHelper,
  });

  Future<void> addTimeslot(TimeslotModel timeslot) async {
    // 1. Guardar en Hive
    hiveService.saveTimeslot(timeslot);

    // 2. Insertar en sync_queue de SQLite para el Sync Engine
    await databaseHelper.insert('sync_queue', {
      'event_id': timeslot.id,
      'action': 'ADD_TIMESLOT',
      'status': 'pending',
      'retry_count': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteTimeslot(String id) async {
    // 1. Eliminar de Hive
    hiveService.deleteTimeslot(id);

    // 2. Insertar en sync_queue de SQLite para el Sync Engine
    await databaseHelper.insert('sync_queue', {
      'event_id': id,
      'action': 'DELETE_TIMESLOT',
      'status': 'pending',
      'retry_count': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  List<TimeslotModel> getTimeslots() {
    return hiveService.getTimeslots();
  }
}
