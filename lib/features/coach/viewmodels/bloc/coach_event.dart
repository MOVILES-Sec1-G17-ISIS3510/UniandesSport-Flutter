abstract class CoachesEvent {}

class LoadCoaches extends CoachesEvent {}

class FilterCoachesBySport extends CoachesEvent {
  final String sport;

  FilterCoachesBySport(this.sport);
}

class SearchCoaches extends CoachesEvent {
  final String query;

  SearchCoaches(this.query);
}