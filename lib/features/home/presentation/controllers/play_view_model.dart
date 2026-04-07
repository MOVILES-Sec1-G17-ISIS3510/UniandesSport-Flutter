import 'package:flutter/material.dart';

import '../../data/events_repository.dart';
import '../../domain/models/event_modality.dart';
import '../../domain/models/sport_event.dart';
import '../../../auth/domain/models/user_profile.dart';

/// ViewModel de la pantalla Play.
///
/// Implementa el patrón **MVVM (Model-View-ViewModel)**:
/// - Extiende [ChangeNotifier] para que la View pueda observar cambios de estado.
/// - Centraliza toda la lógica de negocio y el estado de la pantalla Play.
/// - La View (PlayPage) solo llama métodos de este ViewModel y dibuja los datos
///   que este expone; nunca accede directamente al repositorio.
///
/// Recibe [EventsRepository] por inyección de dependencias (a través de Provider),
/// lo que facilita el testing y respeta el principio de inversión de dependencias.
class PlayViewModel extends ChangeNotifier {
  PlayViewModel({
    required EventsRepository repository,
    required UserProfile profile,
  })  : _repo = repository,
        _profile = profile;

  // ─── Dependencias ────────────────────────────────────────────────────────

  /// Repositorio inyectado (Singleton compartido via Provider).
  final EventsRepository _repo;

  /// Perfil del usuario autenticado (mutable para permitir actualización desde AppShell).
  UserProfile _profile;

  // ─── Estado de selección ─────────────────────────────────────────────────

  String? _selectedSport;
  EventModality? _selectedModality;

  String? get selectedSport => _selectedSport;
  EventModality? get selectedModality => _selectedModality;

  // ─── Estado de búsqueda ───────────────────────────────────────────────────

  bool _hasSearched = false;
  bool _isSearching = false;
  List<SportEvent> _searchResults = [];
  String? _searchError;

  bool get hasSearched => _hasSearched;
  bool get isSearching => _isSearching;
  List<SportEvent> get searchResults => List.unmodifiable(_searchResults);
  String? get searchError => _searchError;

  // ─── Estado de registro ───────────────────────────────────────────────────

  /// ID del evento en el que se está procesando el registro actualmente.
  /// Null si no hay ninguna operación en curso.
  String? _joiningEventId;
  String? get joiningEventId => _joiningEventId;

  // ─── Getters derivados (lógica de negocio) ────────────────────────────────

  /// El usuario puede buscar solo si eligió deporte Y modalidad.
  bool get canSearch => _selectedSport != null && _selectedModality != null;

  /// El usuario puede crear un evento solo si eligió casual
  /// (los torneos solo los crea la coordinación estudiantil).
  bool get canCreate => canSearch && _selectedModality == EventModality.casual;

  // ─── Acceso al perfil ────────────────────────────────────────────────────

  UserProfile get profile => _profile;

  /// Actualiza el perfil del usuario. Llamado desde [AppShell] una vez que
  /// el usuario ya tiene sesión activa y el perfil real está disponible.
  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  // ─── Métodos de selección ─────────────────────────────────────────────────

  void selectSport(String? sport) {
    _selectedSport = sport;
    notifyListeners();
  }

  void selectModality(EventModality? modality) {
    _selectedModality = modality;
    notifyListeners();
  }

  // ─── Búsqueda de eventos ──────────────────────────────────────────────────

  /// Ejecuta la búsqueda en Firestore y almacena los resultados.
  /// Notifica a la View en cada cambio de estado (cargando, error, éxito).
  Future<void> search() async {
    if (!canSearch) return;

    _hasSearched = true;
    _isSearching = true;
    _searchError = null;
    _searchResults = [];
    notifyListeners();

    try {
      final results = await _repo.searchEvents(
        sport: _selectedSport!,
        modality: _selectedModality!,
      );
      _searchResults = results;
    } catch (e) {
      _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Vuelve a la pantalla de selección (antes de buscar).
  void resetSearch() {
    _hasSearched = false;
    _searchResults = [];
    _searchError = null;
    _joiningEventId = null;
    notifyListeners();
  }

  // ─── Registro en evento ───────────────────────────────────────────────────

  /// Intenta registrar al usuario en [event].
  /// Devuelve el mapa con `success` (bool) y `message` (String) del repositorio.
  Future<Map<String, dynamic>> joinEvent(SportEvent event) async {
    if (_joiningEventId != null) {
      return {'success': false, 'message': 'Operación en curso'};
    }

    _joiningEventId = event.id;
    notifyListeners();

    final result = await _repo.registerUserInEventWithMessage(
      eventId: event.id,
      userId: _profile.uid,
    );

    final success = result['success'] as bool;

    // Si tuvo éxito, refresca el listado para mostrar el contador actualizado.
    if (success) {
      await search();
    }

    _joiningEventId = null;
    notifyListeners();

    return result;
  }

  // ─── Utilidades de formato (lógica fuera de la View) ─────────────────────

  /// Formatea una fecha para mostrar "Hoy HH:MM PM", "Mañana …", etc.
  /// Vive en el ViewModel para que la View no contenga lógica de negocio.
  String formatSchedule(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dayLabel;
    if (eventDate == today) {
      dayLabel = 'Hoy';
    } else if (eventDate == tomorrow) {
      dayLabel = 'Mañana';
    } else {
      dayLabel = '${eventDate.day}/${eventDate.month}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dayLabel $displayHour:$minute $period';
  }
}



