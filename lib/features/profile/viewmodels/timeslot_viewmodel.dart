import 'package:flutter/foundation.dart';
import '../models/timeslot_model.dart';
import '../services/timeslot_repository.dart';

class TimeslotViewModel extends ChangeNotifier {
  final TimeslotRepository _repository;

  List<TimeslotModel> _timeslots = [];
  List<TimeslotModel> get timeslots => _timeslots;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  TimeslotViewModel(this._repository) {
    loadTimeslots();
  }

  void loadTimeslots() {
    _timeslots = _repository.getTimeslots();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> addTimeslot(TimeslotModel timeslot) async {
    _setLoading(true);
    // 1. UI Optimista: Actualizar estado en memoria inmediatamente
    _timeslots.add(timeslot);

    try {
      // 2. Persistir en Hive y encolar en SQLite (SyncEngine)
      await _repository.addTimeslot(timeslot);
    } catch (e) {
      // Revertir UI si falla localmente la escritura en caché o db
      _timeslots.remove(timeslot);
      debugPrint("Error agregando timeslot: $e");
    } finally {
      // Garantizar que la UI se libere inmediatamente
      _setLoading(false);
    }
  }

  Future<void> updateTimeslot(TimeslotModel timeslot) async {
    _setLoading(true);
    // 1. UI Optimista: Actualizar estado en memoria
    final index = _timeslots.indexWhere((t) => t.id == timeslot.id);
    TimeslotModel? oldTimeslot;
    if (index != -1) {
      oldTimeslot = _timeslots[index];
      _timeslots[index] = timeslot;
    }

    try {
      // 2. Persistir localmente en disco
      await _repository.updateTimeslot(timeslot);
    } catch (e) {
      // Revertir UI
      if (index != -1 && oldTimeslot != null) {
        _timeslots[index] = oldTimeslot;
      }
      debugPrint("Error actualizando timeslot: $e");
    } finally {
      // OBLIGATORIO: Garantizar que la UI se libere inmediatamente
      _setLoading(false);
    }
  }

  Future<void> removeTimeslot(String id) async {
    _setLoading(true);
    // 1. UI Optimista: Actualizar estado en memoria inmediatamente
    final index = _timeslots.indexWhere((t) => t.id == id);
    if (index != -1) {
      final removedTimeslot = _timeslots.removeAt(index);

      try {
        // 2. Eliminar de Hive y encolar en SQLite (SyncEngine)
        await _repository.deleteTimeslot(id);
      } catch (e) {
        // Revertir UI si falla localmente la escritura en caché o db
        _timeslots.insert(index, removedTimeslot);
        debugPrint("Error eliminando timeslot: $e");
      }
    }
    // Garantizar que la UI se libere inmediatamente
    _setLoading(false);
  }
}
