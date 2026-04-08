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
      rankInSport: data?['rankInSport'] as int?,
      rating: data?['rating'] as double?,
      sessionsDelivered: data?['sessionsDelivered'] as int?,
      totalCoachesInSport: data?['totalCoachesInSport'] as int?,
      totalReviews: data?['totalReviews'] as int?,
      tournamentWins: data?['tournamentWins'] as int?,
      verified: data?['verified'] as bool?,
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
      rankInSport: json['rankInSport'] as int?,
      rating: json['rating'] as double?,
      sessionsDelivered: json['sessionsDelivered'] as int?,
      totalCoachesInSport: json['totalCoachesInSport'] as int?,
      totalReviews: json['totalReviews'] as int?,
      tournamentWins: json['tournamentWins'] as int?,
      verified: json['verified'] as bool?,
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