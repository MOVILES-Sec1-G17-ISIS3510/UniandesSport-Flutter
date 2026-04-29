import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniandessport_flutter/features/coach/viewmodels/bloc/coach_event.dart';
import 'package:uniandessport_flutter/features/coach/viewmodels/bloc/coach_state.dart';
import 'package:uniandessport_flutter/features/coach/models/coach_model.dart';
import 'package:uniandessport_flutter/features/coach/services/coach_repository.dart';

class CoachesBloc extends Bloc<CoachesEvent, CoachesState> {
  final CoachRepository repository;

  List<Coach> _allCoaches = [];

  String _selectedSport = "All Coaches";
  String _searchQuery = "";

  CoachesBloc(this.repository) : super(CoachesInitial()) {
    on<LoadCoaches>(_onLoadCoaches);
    on<FilterCoachesBySport>(_onFilterCoaches);
    on<SearchCoaches>(_onSearchCoaches);
  }

  Future<void> _onLoadCoaches(
    LoadCoaches event,
    Emitter<CoachesState> emit,
  ) async {
    emit(CoachesLoading());

    try {
      _allCoaches = await repository.getCoaches();

      emit(CoachesLoaded(_allCoaches, selectedSport: "All Coaches"));
    } catch (e) {
      emit(CoachesError(e.toString()));
    }
  }

  void _onFilterCoaches(
    FilterCoachesBySport event,
    Emitter<CoachesState> emit,
  ) {
    _selectedSport = event.sport;

    _applyFilters(emit);
  }

  void _onSearchCoaches(SearchCoaches event, Emitter<CoachesState> emit) {
    _searchQuery = event.query;

    _applyFilters(emit);
  }

  void _applyFilters(Emitter<CoachesState> emit) {
    List<Coach> filtered = List.from(_allCoaches);

    if (_selectedSport != "All Coaches") {
      filtered = filtered
          .where((coach) => coach.deporte == _selectedSport)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (coach) => coach.nombre!.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    emit(CoachesLoaded(filtered, selectedSport: _selectedSport));
  }
}
