class TimeSlot {
  final String dia;
  final String horaInicio;
  final String horaFin;

  const TimeSlot({
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      dia: (json['dia'] ?? '').toString(),
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      horaFin: (json['hora_fin'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dia': dia,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
    };
  }

  DateTime get start => _timeOfDayToDateTime(horaInicio);

  DateTime get end => _timeOfDayToDateTime(horaFin);

  static DateTime _timeOfDayToDateTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(2000, 1, 1, hour, minute);
  }
}

