import 'package:flutter/foundation.dart';

import '../../../core/utils/lru_cache.dart';
import '../models/event_model.dart';
import '../services/event_repository.dart';

/// ViewModel que orquesta la paginación y caché L1 para la lista de eventos.
class EventListViewModel extends ChangeNotifier {
  final EventRepository _repository;
  
  // Caché L1 (LRU) con capacidad para 60 eventos (3 páginas)
  final LruCache<String, EventModel> _lruCache = LruCache<String, EventModel>(maxSize: 60);

  // Estado
  final List<EventModel> _eventsToShow = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _errorMessage;

  static const int _pageSize = 20;

  EventListViewModel({EventRepository? repository}) 
      : _repository = repository ?? EventRepository();

  // Getters
  List<EventModel> get events => List.unmodifiable(_eventsToShow);
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  String? get errorMessage => _errorMessage;

  /// Carga la primera página. Limpia estado y caché.
  Future<void> loadFirstPage() async {
    _currentPage = 1;
    _eventsToShow.clear();
    _lruCache.clear();
    _hasMoreData = true;
    _errorMessage = null;
    
    await _fetchPage(_currentPage);
  }

  /// Carga la siguiente página de eventos si no está cargando y hay más datos.
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMoreData) return;
    
    _currentPage++;
    await _fetchPage(_currentPage);
  }

  /// Recupera un evento. Intenta buscar primero en Caché L1, 
  /// luego podría buscar en Caché L2 si fuera necesario.
  EventModel? getEventById(String id) {
    // 1. Buscar en LRU Cache
    final cachedEvent = _lruCache.get(id);
    if (cachedEvent != null) {
      return cachedEvent;
    }
    
    // Si no está en L1, podríamos buscarlo en _eventsToShow (que funciona como L1.5)
    // o hacer una petición al repositorio si no se encuentra.
    try {
      return _eventsToShow.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchPage(int page) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newEvents = await _repository.getEventsPaginated(
        page: page,
        limit: _pageSize,
      );

      if (newEvents.isEmpty) {
        _hasMoreData = false;
      } else {
        // Lógica L1: Guardar nuevos eventos en el LRUCache
        for (final event in newEvents) {
          _lruCache.put(event.id, event);
        }

        _eventsToShow.addAll(newEvents);
        
        // Si llegaron menos eventos que el pageSize, ya no hay más
        if (newEvents.length < _pageSize) {
          _hasMoreData = false;
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading events: $e';
      // Retroceder página si hubo error
      if (_currentPage > 1) _currentPage--;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
