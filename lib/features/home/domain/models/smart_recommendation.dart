enum RecommendationType { join, create }

class EventDraft {
  final String deporte;
  final String horaInicio;
  final String lugar;

  const EventDraft({
    required this.deporte,
    required this.horaInicio,
    required this.lugar,
  });

  factory EventDraft.fromJson(Map<String, dynamic> json) {
    return EventDraft(
      deporte: (json['deporte'] ?? '').toString(),
      horaInicio: (json['hora_inicio'] ?? '').toString(),
      lugar: (json['lugar'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deporte': deporte,
      'hora_inicio': horaInicio,
      'lugar': lugar,
    };
  }
}

class SmartRecommendation {
  final RecommendationType type;
  final String? eventId;
  final EventDraft? eventDraft;
  final String uiTitle;
  final String uiBody;
  final String ctaText;

  const SmartRecommendation({
    required this.type,
    required this.eventId,
    required this.eventDraft,
    required this.uiTitle,
    required this.uiBody,
    required this.ctaText,
  });

  factory SmartRecommendation.fromJson(Map<String, dynamic> json) {
    final rawType = (json['tipo_recomendacion'] ?? '').toString().toLowerCase();

    final type = rawType == 'create'
        ? RecommendationType.create
        : RecommendationType.join;

    final draftJson = json['borrador_evento'];

    return SmartRecommendation(
      type: type,
      eventId: json['evento_id']?.toString(),
      eventDraft: draftJson is Map<String, dynamic>
          ? EventDraft.fromJson(draftJson)
          : null,
      uiTitle: (json['ui_title'] ?? '').toString(),
      uiBody: (json['ui_body'] ?? '').toString(),
      ctaText: (json['cta_text'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo_recomendacion':
          type == RecommendationType.create ? 'create' : 'join',
      'evento_id': eventId,
      'borrador_evento': eventDraft?.toJson(),
      'ui_title': uiTitle,
      'ui_body': uiBody,
      'cta_text': ctaText,
    };
  }
}
