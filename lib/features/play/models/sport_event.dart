import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_modality.dart';

class SportEvent {
  final String id;
  final String createdBy; // UID del usuario que creó el evento
  final String title;
  final String sport;
  final EventModality modality;
  final String description;
  final String location;
  final DateTime scheduledAt;
  final int maxParticipants;
  final List<String> participants; // UIDs de usuarios participantes
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  SportEvent({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.sport,
    required this.modality,
    required this.description,
    required this.location,
    required this.scheduledAt,
    required this.maxParticipants,
    required this.participants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Getter para participantes actuales
  int get currentParticipants => participants.length;

  // Getter para espacios disponibles
  int get availableSpots => maxParticipants - currentParticipants;

  // Getter para estado de disponibilidad
  bool get isFull => availableSpots <= 0;

  // Convertir a JSON para Firestore
  Map<String, dynamic> toJson() {
    return {
      'createdBy': createdBy,
      'title': title,
      'sport': sport,
      'modality': modality.code,
      'description': description,
      'location': location,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'maxParticipants': maxParticipants,
      'participants': participants,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Crear desde documento Firestore
  factory SportEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SportEvent(
      id: doc.id,
      createdBy: data['createdBy'] ?? '',
      title: data['title'] ?? '',
      sport: data['sport'] ?? '',
      modality: EventModality.fromCode(data['modality'] ?? 'casual'),
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxParticipants: data['maxParticipants'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Crear copia con cambios
  SportEvent copyWith({
    String? id,
    String? createdBy,
    String? title,
    String? sport,
    EventModality? modality,
    String? description,
    String? location,
    DateTime? scheduledAt,
    int? maxParticipants,
    List<String>? participants,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SportEvent(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      sport: sport ?? this.sport,
      modality: modality ?? this.modality,
      description: description ?? this.description,
      location: location ?? this.location,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


