import 'package:equatable/equatable.dart';
import 'package:uniandessport_flutter/features/coach/domain/models/coach_model.dart';


abstract class CoachesState extends Equatable {
  const CoachesState();

  @override
  List<Object?> get props => [];
}

class CoachesInitial extends CoachesState {}

class CoachesLoading extends CoachesState {}

// coach_state.dart
class CoachesLoaded extends CoachesState {
  final List<Coach> coaches;
  final String? selectedSport;

  const CoachesLoaded(
    this.coaches, {
    this.selectedSport,
  });

  @override
  List<Object?> get props => [coaches, selectedSport];
}

class CoachesError extends CoachesState {
  final String message;

  const CoachesError(this.message);

  @override
  List<Object?> get props => [message];
}