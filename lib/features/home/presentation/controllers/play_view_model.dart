import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
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
  }) : _repo = repository,
       _profile = profile {
    final normalizedMainSport = AppSports.normalizeSportKey(
      profile.mainSport ?? '',
    );

    // Estado inicial para evitar CTA deshabilitados al abrir Play.
    _selectedSport = normalizedMainSport.isNotEmpty
        ? normalizedMainSport
        : AppSports.sportKeys.first;
    _selectedModality = EventModality.casual;
  }

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

  // ─── Estado de My Scheduled ───────────────────────────────────────────────

  bool _showMyScheduled = false;
  bool _isLoadingMyScheduled = false;
  List<SportEvent> _myScheduledEvents = [];
  String? _myScheduledError;

  bool get showMyScheduled => _showMyScheduled;
  bool get isLoadingMyScheduled => _isLoadingMyScheduled;
  List<SportEvent> get myScheduledEvents => List.unmodifiable(_myScheduledEvents);
  String? get myScheduledError => _myScheduledError;

  // ─── Getters derivados (lógica de negocio) ────────────────────────────────

  /// El usuario puede buscar solo si eligió deporte Y modalidad.
  bool get canSearch => _selectedSport != null && _selectedModality != null;

  /// El usuario puede crear un evento casual cuando ya eligio un deporte.
  ///
  /// Nota: el formulario de creacion siempre persiste modalidad `casual`,
  /// asi evitamos bloquear UX por no elegir modalidad antes de crear.
  bool get canCreate => _selectedSport != null;

  // ─── Acceso al perfil ────────────────────────────────────────────────────

  UserProfile get profile => _profile;

  /// Actualiza el perfil del usuario. Llamado desde [AppShell] una vez que
  /// el usuario ya tiene sesión activa y el perfil real está disponible.
  void updateProfile(UserProfile profile) {
    _profile = profile;

    // Si por alguna razon no hay deporte seleccionado, intenta usar el del perfil.
    if (_selectedSport == null || _selectedSport!.trim().isEmpty) {
      final normalizedMainSport = AppSports.normalizeSportKey(
        profile.mainSport ?? '',
      );
      if (normalizedMainSport.isNotEmpty) {
        _selectedSport = normalizedMainSport;
      }
    }

    _selectedModality ??= EventModality.casual;
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

  Future<void> toggleMyScheduled() async {
    _showMyScheduled = !_showMyScheduled;
    notifyListeners();

    if (_showMyScheduled) {
      await loadMyScheduled();
    }
  }

  Future<void> loadMyScheduled({bool forceRefresh = false}) async {
    if (_isLoadingMyScheduled) return;
    if (!forceRefresh && _myScheduledEvents.isNotEmpty) return;

    _isLoadingMyScheduled = true;
    _myScheduledError = null;
    notifyListeners();

    try {
      final events = await _repo.getUserParticipatingEvents(_profile.uid);
      _myScheduledEvents = events.where((event) => event.status == 'active').toList();
    } catch (_) {
      _myScheduledError = 'Could not load your scheduled events';
    } finally {
      _isLoadingMyScheduled = false;
      notifyListeners();
    }
  }

  Future<bool> leaveScheduledEvent(SportEvent event) async {
    try {
      await _repo.leaveEvent(eventId: event.id, userId: _profile.uid);
      if (_showMyScheduled) {
        await loadMyScheduled(forceRefresh: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Registro en evento ───────────────────────────────────────────────────

  /// Intenta registrar al usuario en [event].
  /// Devuelve el mapa con `success` (bool) y `message` (String) del repositorio.
  Future<Map<String, dynamic>> joinEvent(SportEvent event) async {
    if (_joiningEventId != null) {
      return {'success': false, 'message': 'Operation in progress'};
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
      if (_showMyScheduled) {
        await loadMyScheduled(forceRefresh: true);
      }
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
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dayLabel;
    if (eventDate == today) {
      dayLabel = 'Today';
    } else if (eventDate == tomorrow) {
      dayLabel = 'Tomorrow';
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

