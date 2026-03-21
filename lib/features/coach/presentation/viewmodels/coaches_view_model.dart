import 'package:flutter/material.dart';
import 'package:uniandessport_flutter/features/coach/domain/models/coach_model.dart';
import 'package:uniandessport_flutter/features/home/data/coach_repository.dart';

class CoachesViewModel extends ChangeNotifier {
  final CoachRepository _repository;

  List<Coach> _allCoaches = [];
  List<Coach> _filteredCoaches = [];
  bool _isLoading = false;
  String? _error;
  String _selectedSport = "All Coaches";
  String _searchQuery = "";

  List<Coach> get coaches => _filteredCoaches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedSport => _selectedSport;

  CoachesViewModel(this._repository);

  Future<void> loadCoaches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allCoaches = await _repository.getCoaches();
      _applyFilters();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterBySport(String sport) {
    _selectedSport = sport;
    _applyFilters();
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _applyFilters() {
    List<Coach> filtered = List.from(_allCoaches);

    if (_selectedSport != "All Coaches") {
      filtered = filtered
          .where((coach) => coach.deporte == _selectedSport)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((coach) =>
              coach.nombre?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false)
          .toList();
    }

    _filteredCoaches = filtered;
    notifyListeners();
  }
}
