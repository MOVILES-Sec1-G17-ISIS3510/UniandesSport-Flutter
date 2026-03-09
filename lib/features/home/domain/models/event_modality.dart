/// Enumeración para modalidades de eventos
enum EventModality {
  casual,
  tournament;

  String get label => this == casual ? 'Casual' : 'Torneo';
  String get code => this == casual ? 'casual' : 'tournament';

  static EventModality fromCode(String value) {
    return EventModality.values.firstWhere(
      (m) => m.code == value,
      orElse: () => EventModality.casual,
    );
  }
}

