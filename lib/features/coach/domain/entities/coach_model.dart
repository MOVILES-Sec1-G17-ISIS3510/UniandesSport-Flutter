import 'package:cloud_firestore/cloud_firestore.dart';

class Coach {
  final String? deporte;
  final String? disponibilidad;
  final String? especialidad;
  final String? experiencia;
  final String? id;
  final String? nombre;
  final String? precio;
  final int? rankInSport;
  final double? rating;
  final int? sessionsDelivered;
  final int? totalCoachesInSport;
  final int? totalReviews;
  final int? tournamentWins;
  final bool? verified;
  final String? whatsapp;

  const Coach({
    this.deporte,
    this.disponibilidad,
    this.especialidad,
    this.experiencia,
    this.id,
    this.nombre,
    this.precio,
    this.rankInSport,
    this.rating,
    this.sessionsDelivered,
    this.totalCoachesInSport,
    this.totalReviews,
    this.tournamentWins,
    this.verified,
    this.whatsapp,
  });

  String get initials {
    if (nombre == null || nombre!.trim().isEmpty) return "";

    final parts = nombre!.trim().split(" ");

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  factory Coach.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return Coach(
      id: doc.id,
      deporte: data?['deporte'] as String?,
      disponibilidad: data?['disponibilidad'] as String?,
      especialidad: data?['especialidad'] as String?,
      experiencia: data?['experiencia'] as String?,
      nombre: data?['nombre'] as String?,
      precio: data?['precio'] as String?,
      rankInSport: _asInt(data?['rankInSport']),
      rating: _asDouble(data?['rating']),
      sessionsDelivered: _asInt(data?['sessionsDelivered']),
      totalCoachesInSport: _asInt(data?['totalCoachesInSport']),
      totalReviews: _asInt(data?['totalReviews']),
      tournamentWins: _asInt(data?['tournamentWins']),
      verified: _asBool(data?['verified']),
      whatsapp: data?['whatsapp'] as String?,
    );
  }

  factory Coach.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Coach();

    return Coach(
      deporte: json['deporte'] as String?,
      disponibilidad: json['disponibilidad'] as String?,
      especialidad: json['especialidad'] as String?,
      experiencia: json['experiencia'] as String?,
      id: json['id'] as String?,
      nombre: json['nombre'] as String?,
      precio: json['precio'] as String?,
      rankInSport: _asInt(json['rankInSport']),
      rating: _asDouble(json['rating']),
      sessionsDelivered: _asInt(json['sessionsDelivered']),
      totalCoachesInSport: _asInt(json['totalCoachesInSport']),
      totalReviews: _asInt(json['totalReviews']),
      tournamentWins: _asInt(json['tournamentWins']),
      verified: _asBool(json['verified']),
      whatsapp: json['whatsapp'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deporte': deporte,
      'disponibilidad': disponibilidad,
      'especialidad': especialidad,
      'experiencia': experiencia,
      'nombre': nombre,
      'precio': precio,
      'rankInSport': rankInSport,
      'rating': rating,
      'sessionsDelivered': sessionsDelivered,
      'totalCoachesInSport': totalCoachesInSport,
      'totalReviews': totalReviews,
      'tournamentWins': tournamentWins,
      'verified': verified,
      'whatsapp': whatsapp,
    };
  }

  Map<String, dynamic> toJson() => toFirestore();
}
