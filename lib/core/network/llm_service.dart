import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio singleton para usar Google Generative AI (Gemini).
///
/// Centraliza todas las interacciones con IA para:
/// - Generar descripciones de eventos
/// - Sugerir nuevos deportes
/// - Crear textos personalizados
/// - Generar recomendaciones
///
/// IMPORTANTE: Necesita obtener la API key en https://aistudio.google.com
/// Luego, pasar como: flutter run --dart-define=GEMINI_API_KEY=your_key
///
/// Ejemplo de uso:
/// ```dart
/// final llm = LLMService.instance;
/// final text = await llm.generateDailyRecommendationText(
///   eventTitle: 'Fútbol 5v5',
///   sport: 'futbol',
///   time: DateTime.now().add(Duration(hours: 3)),
///   location: 'UniAndes Courts',
///   userName: 'Juan',
/// );
/// ```
class LLMService {
  // ─── Singleton Pattern ────────────────────────────────────────────────────

  static const String _apiKeyPrefKey = 'gemini_api_key';
  static const String _geminiModel = 'gemini-1.5-flash';

  static LLMService? _instance;

  /// Constructor privado para singleton.
  LLMService._internal();

  String? _apiKey;
  Future<void>? _bootstrapFuture;

  /// Obtener la instancia singleton del servicio.
  static LLMService get instance {
    _instance ??= LLMService._internal();
    return _instance!;
  }

  /// Indica si hay API key disponible (env o almacenamiento local).
  bool get isConfigured {
    final envKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.trim().isNotEmpty) return true;
    return (_apiKey ?? '').trim().isNotEmpty;
  }

  /// Guarda una API key para usos futuros en el mismo dispositivo.
  ///
  /// Nota: esto evita tener que reingresarla en debug, pero no reemplaza
  /// una estrategia segura de backend para producción.
  Future<void> saveApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) return;

    _apiKey = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, normalized);
  }

  Future<void> _ensureBootstrapped() {
    _bootstrapFuture ??= _loadPersistedApiKey();
    return _bootstrapFuture!;
  }

  Future<void> _loadPersistedApiKey() async {
    if ((_apiKey ?? '').trim().isNotEmpty) return;

    final envKey = const String.fromEnvironment('GEMINI_API_KEY').trim();
    if (envKey.isNotEmpty) {
      _apiKey = envKey;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyPrefKey)?.trim();
  }

  String _resolvedApiKey() {
    final envKey = const String.fromEnvironment('GEMINI_API_KEY').trim();
    if (envKey.isNotEmpty) return envKey;
    return (_apiKey ?? '').trim();
  }

  Future<String?> _generateWithGemini(String prompt) async {
    await _ensureBootstrapped();

    final apiKey = _resolvedApiKey();
    if (apiKey.isEmpty) {
      debugPrint('[LLMService] GEMINI_API_KEY no configurada. Usando fallback.');
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$apiKey',
      );

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 180,
          },
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[LLMService] Gemini HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = (data['candidates'] as List?) ?? const [];
      if (candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = (content?['parts'] as List?) ?? const [];
      if (parts.isEmpty) return null;

      final text = (parts.first['text'] as String?)?.trim();
      if (text == null || text.isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('[LLMService] Error llamando Gemini: $e');
      return null;
    }
  }

  Future<String> _generateTextFromPrompt({
    required String prompt,
    required String fallback,
  }) async {
    final generated = await _generateWithGemini(prompt);
    if (generated != null && generated.trim().isNotEmpty) {
      return generated.trim();
    }

    debugPrint(
      '[LLMService] Fallback local activo. Prompt length=${prompt.length}',
    );
    return fallback;
  }

  // ─── Métodos públicos ─────────────────────────────────────────────────────

  /// Generar descripción sugerida para un evento.
  ///
  /// Genera un texto corto y atractivo (máximo 2-3 líneas) que pueda ser usado
  /// como descripción de evento o en anuncios.
  ///
  /// Ejemplo respuesta:
  /// "🎾 Ven a disfrutar de un emocionante partido de tenis casual en los
  /// mejores courts de UniAndes. Nivel para todos. ¡No te lo pierdas!"
  Future<String> generateEventDescription({
    required String sport,
    required String modality,
    required String location,
    required int maxPlayers,
  }) async {
    try {
      final prompt = '''
Genera una descripción corta, atractiva y motivadora (máximo 2 líneas) para un evento deportivo:
- Deporte: $sport
- Tipo: ${modality == 'casual' ? 'Juego relajado' : 'Competición competitiva'}
- Ubicación: $location
- Máximo de jugadores: $maxPlayers

Instrucciones:
1. En español
2. Máximo 2-3 líneas
3. Motivador para estudiantes de UniAndes
4. Incluye un emoji al inicio
5. Sin asteriscos ni formato especial
6. SOLO texto plano

Responde SOLO con la descripción.
''';

      debugPrint('[LLMService] Generando descripción para $sport...');

      final description = await _generateTextFromPrompt(
        prompt: prompt,
        fallback: _getDefaultDescription(sport),
      );

      debugPrint('[LLMService] ✅ Descripción generada');
      return description;
    } catch (e) {
      debugPrint('[LLMService] ❌ Error generando descripción: $e');
      return _getDefaultDescription(sport);
    }
  }

  /// Generar texto de recomendación diaria para invitar al usuario a un evento.
  ///
  /// Crea un mensaje personalizado y motivador (máximo 2 líneas) que invita
  /// al usuario a registrarse en un evento específico.
  ///
  /// Ejemplo:
  /// "Hola Juan, hay un increíble partido de tenis hoy a las 3:00 PM con
  /// cupos disponibles. ¡Ven y disfruta!"
  Future<String> generateDailyRecommendationText({
    required String eventTitle,
    required String sport,
    required String modality,
    required DateTime time,
    required String location,
    required String eventDescription,
    required int availableSpots,
    required String userName,
  }) async {
    try {
      final timeStr = _formatTime(time);
      final normalizedDescription = eventDescription.trim().isEmpty
          ? 'A short and social session open for students.'
          : eventDescription.trim();

      final prompt = '''
Write a short recommendation message in English for a university sports app.

Context:
- User: $userName
- Event title: $eventTitle
- Sport: $sport
- Modality: $modality
- Time: $timeStr
- Location: $location
- Available spots: $availableSpots
- Event description: $normalizedDescription

Requirements:
1. 2 short sentences maximum.
2. Explain WHY this event is useful/relevant for the user (fitness, practice, social, consistency, etc.).
3. Include a compact summary of location and event description.
4. Friendly and motivating tone.
5. Plain text only (no emojis, no markdown).

Return only the final message.
''';

      debugPrint('[LLMService] Generating daily recommendation text...');

      final fallback =
          'This $sport $modality helps you stay active and improve your consistency. '
          'It is at $location ($timeStr): $normalizedDescription';

      final text = await _generateTextFromPrompt(
        prompt: prompt,
        fallback: fallback,
      );

      debugPrint('[LLMService] ✅ Daily recommendation text generated');
      return text;
    } catch (e) {
      debugPrint('[LLMService] ❌ Error generating daily text: $e');
      final normalizedDescription = eventDescription.trim().isEmpty
          ? 'A short and social session open for students.'
          : eventDescription.trim();
      return 'This $sport $modality helps you stay active and improve your consistency. '
          'It is at $location (${_formatTime(time)}): $normalizedDescription';
    }
  }

  /// Generate a short, personalized headline for the daily recommendation card.
  Future<String> generateDailyRecommendationTitle({
    required String sport,
    required String modality,
    required String userName,
  }) async {
    try {
      final prompt = '''
Create a short English headline (max 7 words) for a sports event recommendation card.

Context:
- User: $userName
- Sport: $sport
- Modality: $modality

Rules:
1. Plain text only
2. No emojis
3. Friendly and motivating tone
4. Keep it concise

Return only the headline.
''';

      final title = await _generateTextFromPrompt(
        prompt: prompt,
        fallback: 'Your Daily ${_capitalize(sport)} Pick',
      );

      return title.trim();
    } catch (e) {
      debugPrint('[LLMService] Error generating daily title: $e');
      return 'Your Daily ${_capitalize(sport)} Pick';
    }
  }

  /// Sugerir nuevos deportes basado en preferencias actuales.
  ///
  /// Analiza los deportes que el usuario ya practica y sugiere nuevos deportes
  /// complementarios que podrían interesarle.
  ///
  /// Retorna lista de nombres de deportes sugeridos (máximo 3).
  Future<List<String>> suggestNewSports({
    required List<String> currentPreferences,
    required int semester,
  }) async {
    if (currentPreferences.isEmpty) return [];

    try {
      final sportsStr = currentPreferences.join(', ');
      final prompt = '''
Usuario de UniAndes, semestre $semester.
Deportes que disfruta: $sportsStr

Sugiere 3 NUEVOS deportes complementarios que podrían disfrutar.

IMPORTANTE:
- Responde SOLO con nombres de deportes
- Separados por comas
- En español
- Sin explicaciones
- Máximo 3

Ejemplo: badminton, padel, raquetbol
''';

      debugPrint('[LLMService] Sugiriendo deportes...');

      final raw = await _generateTextFromPrompt(
        prompt: prompt,
        fallback: '',
      );
      final suggestions = raw
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      debugPrint('[LLMService] Sugerencias: $suggestions');
      return suggestions.take(3).toList();
    } catch (e) {
      debugPrint('[LLMService] Error sugiriendo deportes: $e');
      return [];
    }
  }

  /// Generar mensaje de motivación personalizado para el usuario.
  ///
  /// Crea un mensaje breve e inspirador (máximo 1 línea) considerando
  /// los eventos en los que está registrado.
  Future<String> generateDailyMotivation({
    required String userName,
    required List<String> registeredEvents,
  }) async {
    try {
      final eventsStr = registeredEvents.isEmpty
          ? 'sin eventos programados'
          : 'registrado en ${registeredEvents.length} evento(s)';

      final prompt = '''
Crea un mensaje corto, motivador e inspirador (máximo 1 línea) para:
- Nombre: $userName
- Estado: $eventsStr

El mensaje debe:
1. Empezar con el nombre del usuario
2. Ser inspirador sobre deporte/salud
3. En español
4. Sin asteriscos ni formato especial
5. Sin emojis

Ejemplo: Juan, hoy es tu día para brillar y disfrutar del deporte.

Responde SOLO con el mensaje.
''';

      debugPrint('[LLMService] Generando motivación...');

      final message = await _generateTextFromPrompt(
        prompt: prompt,
        fallback: '$userName, today is your day to shine in sports.',
      );

      return message;
    } catch (e) {
      debugPrint('[LLMService] Error generando motivación: $e');
      return '$userName, today is your day to shine in sports.';
    }
  }

  // ─── Métodos privados ─────────────────────────────────────────────────────

  /// Obtener descripción por defecto para un deporte.
  String _getDefaultDescription(String sport) {
    final descriptions = {
      'futbol': '⚽ Ven a disfrutar de un emocionante partido de fútbol.',
      'basketball': '🏀 Únete a un juego de basketball con otros estudiantes.',
      'tennis': '🎾 Disfruta un gran partido de tenis con nosotros.',
      'running': '🏃 Únete a una carrera casual con amigos.',
      'natacion': '🏊 Ven a nadar y divertirte en la piscina.',
      'squash': '🎯 Juega squash competitivo o casual.',
      'calistenia': '💪 Entrena calistenia con otros athletes.',
      'pingpong': '🏓 Juega ping pong casual o competitivo.',
    };

    final lower = sport.toLowerCase();
    return descriptions[lower] ??
        '⚽ Ven y disfruta de un emocionante evento deportivo.';
  }

  /// Formatear la hora para mostrar de forma legible.
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

