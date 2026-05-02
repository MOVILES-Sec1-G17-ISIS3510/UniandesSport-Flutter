import 'dart:convert';

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
  final int? creatorSemester;

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
    this.creatorSemester,
  });

  // Getter para participantes actuales
  int get currentParticipants => participants.length;

  // Getter para espacios disponibles
  int get availableSpots => maxParticipants - currentParticipants;

  // Getter para estado de disponibilidad
  bool get isFull => availableSpots <= 0;

  // Convertir a JSON para Firestore
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
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

    if (creatorSemester != null) {
      json['metadata'] = {'creatorSemester': creatorSemester};
    }

    return json;
  }

  Map<String, Object?> toLocalMap({bool isSynced = false}) {
    return {
      'id': id,
      'created_by': createdBy,
      'creator_semester': creatorSemester,
      'title': title,
      'sport': sport,
      'modality': modality.code,
      'description': description,
      'location': location,
      'scheduled_at': scheduledAt.toIso8601String(),
      'max_participants': maxParticipants,
      'participants_json': jsonEncode(participants),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory SportEvent.fromLocalMap(Map<String, Object?> map) {
    final participantsRaw = map['participants_json']?.toString() ?? '[]';
    final participantsDecoded = jsonDecode(participantsRaw);

    return SportEvent(
      id: map['id']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      creatorSemester: map['creator_semester'] as int?,
      title: map['title']?.toString() ?? '',
      sport: map['sport']?.toString() ?? '',
      modality: EventModality.fromCode(map['modality']?.toString() ?? 'casual'),
      description: map['description']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      scheduledAt: DateTime.tryParse(map['scheduled_at']?.toString() ?? '') ?? DateTime.now(),
      maxParticipants: int.tryParse(map['max_participants']?.toString() ?? '') ?? 0,
      participants: participantsDecoded is List
          ? participantsDecoded.map((e) => e.toString()).toList()
          : <String>[],
      status: map['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // Crear desde documento Firestore
  factory SportEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final metadata = data['metadata'];
    final creatorSemester = metadata is Map ? metadata['creatorSemester'] as int? : null;

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
      creatorSemester: creatorSemester,
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
    int? creatorSemester,
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
      creatorSemester: creatorSemester ?? this.creatorSemester,
    );
  }
}

