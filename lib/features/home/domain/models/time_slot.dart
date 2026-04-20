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
}

