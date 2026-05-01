// ...existing code...

/// Modelo puro de datos para un evento deportivo.
/// No importa librerías de UI; solamente tipos y conversión a/desde Map para SQLite.
class EventModel {
  final String id;
  final String title;
  final String date; // Puede ser ISO-8601 u otro string; el repositorio decide cómo usarlo.
  final bool isSynced;

  EventModel({
    required this.id,
    required this.title,
    required this.date,
    this.isSynced = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory EventModel.fromMap(Map<String, Object?> map) {
    return EventModel(
      id: map['id'] as String,
      title: map['title'] as String,
      date: map['date'] as String,
      isSynced: (map['isSynced'] as int) == 1,
    );
  }
}

