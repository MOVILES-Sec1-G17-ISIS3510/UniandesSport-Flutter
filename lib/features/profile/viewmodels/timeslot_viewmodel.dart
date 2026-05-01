import 'package:flutter/foundation.dart';
import '../models/timeslot_model.dart';
import '../services/timeslot_repository.dart';

class TimeslotViewModel extends ChangeNotifier {
  final TimeslotRepository _repository;

  List<TimeslotModel> _timeslots = [];
  List<TimeslotModel> get timeslots => _timeslots;

  TimeslotViewModel(this._repository) {
    loadTimeslots();
  }

  void loadTimeslots() {
    _timeslots = _repository.getTimeslots();
    notifyListeners();
  }

  Future<void> addTimeslot(TimeslotModel timeslot) async {
    // 1. UI Optimista: Actualizar estado en memoria inmediatamente
    _timeslots.add(timeslot);
    notifyListeners();

    try {
      // 2. Persistir en Hive y encolar en SQLite (SyncEngine)
      await _repository.addTimeslot(timeslot);
    } catch (e) {
      // En caso de error, podríamos revertir la UI
      _timeslots.remove(timeslot);
      notifyListeners();
      debugPrint("Error agregando timeslot: $e");
    }
  }

  Future<void> removeTimeslot(String id) async {
    // 1. UI Optimista: Actualizar estado en memoria inmediatamente
    final index = _timeslots.indexWhere((t) => t.id == id);
    if (index != -1) {
      final removedTimeslot = _timeslots.removeAt(index);
      notifyListeners();

      try {
        // 2. Eliminar de Hive y encolar en SQLite (SyncEngine)
        await _repository.deleteTimeslot(id);
      } catch (e) {
        // Revertir UI si falla localmente
        _timeslots.insert(index, removedTimeslot);
        notifyListeners();
        debugPrint("Error eliminando timeslot: $e");
      }
    }
  }
}
