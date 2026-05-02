// ...existing code...

import 'package:flutter/foundation.dart';

import '../models/event_model.dart';
import '../services/event_repository.dart';

/// ViewModel que expone estado para la capa View (widgets/ views).
/// No contiene Widgets ni lógica de layout; solo estado y lógica de negocio.
class EventsViewModel extends ChangeNotifier {
  final EventRepository _repository;

  List<EventModel> _events = [];
  bool _isLoading = false;

  EventsViewModel({EventRepository? repository}) : _repository = repository ?? EventRepository();

  List<EventModel> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;

  /// Carga eventos desde la base de datos local.
  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      _events = await _repository.getLocalEvents();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Añade un evento aplicando UI optimista: actualiza la lista inmediatamente y
  /// dispara la persistencia y el encolado en background.
  Future<void> addEvent(EventModel event) async {
    // UI optimista: agregamos localmente y notificamos a la vista antes de
    // esperar la confirmación del repo.
    final temp = EventModel(
      id: event.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : event.id,
      title: event.title,
      date: event.date,
      isSynced: false,
    );

    _events.add(temp);
    notifyListeners();

    try {
      final inserted = await _repository.createEvent(temp);

      // Reemplazamos el item temporal (por id) por la versión confirmada si el id cambió.
      final index = _events.indexWhere((e) => e.id == temp.id);
      if (index != -1) {
        _events[index] = inserted;
        notifyListeners();
      }
    } catch (e) {
      // Si falla la persistencia local, revertimos el cambio optimista.
      _events.removeWhere((e) => e.id == temp.id);
      notifyListeners();
    }
  }
}

