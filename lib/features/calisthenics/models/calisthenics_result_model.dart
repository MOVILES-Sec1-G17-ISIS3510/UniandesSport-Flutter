import 'package:hive/hive.dart';

part 'calisthenics_result_model.g.dart';

/// Modelo que representa el análisis de IA para un ejercicio de calistenia.
/// Se almacena en Hive para caché ultrarrápida.
///
/// Propiedades:
/// - postureScore: Puntuación 0-100 de la postura detectada
/// - postureAnalysis: Descripción detallada de la postura
/// - feedback: Retroalimentación principal sobre el ejercicio
/// - recommendations: Lista de recomendaciones personalizadas
/// - similarExercises: Ejercicios similares sugeridos
/// - detectedExercise: Nombre del ejercicio detectado por IA
/// - riskAreas: Áreas de riesgo de lesión identificadas
/// - tips: Consejos prácticos para mejorar
/// - analyzedAt: Timestamp del análisis para validación diaria
@HiveType(typeId: 0)
class CalisthenicsResultModel {
  @HiveField(0)
  final int postureScore;

  @HiveField(1)
  final String postureAnalysis;

  @HiveField(2)
  final String feedback;

  @HiveField(3)
  final List<String> recommendations;

  @HiveField(4)
  final List<String> similarExercises;

  @HiveField(5)
  final String detectedExercise;

  @HiveField(6)
  final List<String> riskAreas;

  @HiveField(7)
  final List<String> tips;

  @HiveField(8)
  final DateTime analyzedAt;

  CalisthenicsResultModel({
    required this.postureScore,
    required this.postureAnalysis,
    required this.feedback,
    required this.recommendations,
    required this.similarExercises,
    required this.detectedExercise,
    required this.riskAreas,
    required this.tips,
    required this.analyzedAt,
  });

  /// Crea una instancia desde JSON (respuesta de la IA).
  /// Espera un JSON estructurado como:
  /// ```json
  /// {
  ///   "postureScore": 85,
  ///   "postureAnalysis": "...",
  ///   "feedback": "...",
  ///   "recommendations": ["...", "..."],
  ///   "similarExercises": ["...", "..."],
  ///   "detectedExercise": "Push-up",
  ///   "riskAreas": ["shoulders", "lower back"],
  ///   "tips": ["...", "..."]
  /// }
  /// ```
  factory CalisthenicsResultModel.fromJson(Map<String, dynamic> json) {
    return CalisthenicsResultModel(
      postureScore: json['postureScore'] as int? ?? 0,
      postureAnalysis: json['postureAnalysis'] as String? ?? 'No disponible',
      feedback: json['feedback'] as String? ?? 'No disponible',
      recommendations: List<String>.from(
        (json['recommendations'] as List<dynamic>?) ?? [],
      ),
      similarExercises: List<String>.from(
        (json['similarExercises'] as List<dynamic>?) ?? [],
      ),
      detectedExercise: json['detectedExercise'] as String? ?? 'Desconocido',
      riskAreas: List<String>.from(
        (json['riskAreas'] as List<dynamic>?) ?? [],
      ),
      tips: List<String>.from(
        (json['tips'] as List<dynamic>?) ?? [],
      ),
      analyzedAt: DateTime.now(),
    );
  }

  /// Convierte el modelo a JSON para persistencia o transmisión.
  Map<String, dynamic> toJson() {
    return {
      'postureScore': postureScore,
      'postureAnalysis': postureAnalysis,
      'feedback': feedback,
      'recommendations': recommendations,
      'similarExercises': similarExercises,
      'detectedExercise': detectedExercise,
      'riskAreas': riskAreas,
      'tips': tips,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'CalisthenicsResultModel(exercise: $detectedExercise, score: $postureScore)';
}

