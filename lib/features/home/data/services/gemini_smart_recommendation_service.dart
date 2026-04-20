import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/models/smart_recommendation.dart';

class SmartRecommendationGenerationException implements Exception {
  final String message;

  const SmartRecommendationGenerationException(this.message);

  @override
  String toString() => message;
}

class GeminiSmartRecommendationService {
  // Constructor público de compatibilidad: redirige al singleton.
  factory GeminiSmartRecommendationService({
    FirebaseFirestore? firestore,
  }) {
    return getInstance(firestore: firestore);
  }

  static const String _apiKey =
      'AIzaSyDdC2I3Y62cVLYu60G7q4TFJSFQWsnv5Uo';
  static const String _modelName = 'gemini-2.5-flash';

  final FirebaseFirestore _firestore;

  late final GenerativeModel _model = GenerativeModel(
    model: _modelName,
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.2,
    ),
    systemInstruction: Content.system(
      'You are the Smart Matchmaking engine for UniandesSport. '
      'Return strict JSON only. '
      'The app UI is in English and all ui_title/ui_body/cta_text must be in natural English. '
      'Use student context from Universidad de los Andes when persuasive copy helps.',
    ),
  );

  static GeminiSmartRecommendationService? _instance;

  // Constructor privado: evita new directo externo, como en el pseudocódigo.
  GeminiSmartRecommendationService._internal({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Método singleton explícito tipo getInstance/obtenerInstancia.
  static GeminiSmartRecommendationService getInstance({
    FirebaseFirestore? firestore,
  }) {
    if (_instance == null) {
      // Dart en Flutter inicializa esto de forma segura por isolate;
      // mantenemos doble chequeo semántico del pseudocódigo.
      final created = GeminiSmartRecommendationService._internal(
        firestore: firestore,
      );
      if (_instance == null) {
        _instance = created;
      }
    }
    return _instance!;
  }

  @visibleForTesting
  static void resetSingletonForTest() {
    _instance = null;
  }

  Future<SmartRecommendation?> generateAndStoreForUser(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    final Map<String, dynamic>? userData;
    try {
      final userSnap = await userRef.get();
      userData = userSnap.data();
    } on FirebaseException catch (error) {
      throw SmartRecommendationGenerationException(
        _firebaseMessage(error, fallback: 'Could not read your profile data.'),
      );
    }

    if (userData == null) {
      throw const SmartRecommendationGenerationException(
        'Your profile was not found. Please sign in again.',
      );
    }

    final freeSlots = _parseFreeSlots(userData['free_time_slots']);
    if (freeSlots.isEmpty) return null;

    List<Map<String, dynamic>> todayEvents;
    try {
      todayEvents = await _fetchTodayEvents();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[GeminiSmartRecommendationService] Events query failed, continuing with fallback context: $error',
        );
      }
      todayEvents = const [];
    }

    final prompt = _buildPrompt(
      userData: userData,
      freeSlots: freeSlots,
      todayEvents: todayEvents,
    );

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      final decoded = jsonDecode(_sanitizeJson(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Gemini response is not a JSON object.');
      }

      final recommendation = SmartRecommendation.fromJson(decoded);
      if (!_isValidRecommendation(recommendation)) {
        throw Exception('Gemini response missing required recommendation fields.');
      }

      await _persistRecommendation(uid: uid, recommendation: recommendation);
      return recommendation;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[GeminiSmartRecommendationService] $error');
      }

      final fallback = _buildFallbackRecommendation(
        userData: userData,
        freeSlots: freeSlots,
        todayEvents: todayEvents,
      );

      try {
        await _persistRecommendation(
          uid: uid,
          recommendation: fallback,
          source: 'client_gemini_fallback',
        );
      } on SmartRecommendationGenerationException {
        rethrow;
      } catch (persistError) {
        throw SmartRecommendationGenerationException(
          _errorToMessage(
            persistError,
            fallback:
                'Could not save the recommendation. Check your network and permissions.',
          ),
        );
      }

      return fallback;
    }
  }

  Future<void> _persistRecommendation({
    required String uid,
    required SmartRecommendation recommendation,
    String source = 'client_gemini',
  }) async {
    final payload = <String, dynamic>{
      ...recommendation.toJson(),
      'generatedAt': FieldValue.serverTimestamp(),
      'source': source,
    };

    try {
      await _firestore.collection('users').doc(uid).set({
        'smart_recommendation': payload,
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw SmartRecommendationGenerationException(
        _firebaseMessage(
          error,
          fallback:
              'Could not save recommendation in your profile. Please verify permissions.',
        ),
      );
    }

    // Escritura legacy opcional: no debe romper si esta colección está bloqueada.
    try {
      await _firestore.collection('smart_recommendations').doc(uid).set(
            payload,
            SetOptions(merge: true),
          );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[GeminiSmartRecommendationService] Optional write to smart_recommendations failed: $error',
        );
      }
    }
  }

  bool _isValidRecommendation(SmartRecommendation recommendation) {
    if (recommendation.uiTitle.trim().isEmpty) return false;
    if (recommendation.uiBody.trim().isEmpty) return false;
    if (recommendation.ctaText.trim().isEmpty) return false;

    if (recommendation.type == RecommendationType.join) {
      return (recommendation.eventId ?? '').trim().isNotEmpty;
    }

    final draft = recommendation.eventDraft;
    return draft != null && draft.deporte.trim().isNotEmpty;
  }

  SmartRecommendation _buildFallbackRecommendation({
    required Map<String, dynamic> userData,
    required List<Map<String, String>> freeSlots,
    required List<Map<String, dynamic>> todayEvents,
  }) {
    final firstSlot = freeSlots.isNotEmpty ? freeSlots.first : null;
    final firstEvent = todayEvents.isNotEmpty ? todayEvents.first : null;

    if (firstEvent != null && (firstEvent['id'] ?? '').toString().isNotEmpty) {
      final slotHour = (firstSlot?['hora_inicio'] ?? '18:00').trim();
      final title = (firstEvent['title'] ?? '').toString().trim();

      return SmartRecommendation(
        type: RecommendationType.join,
        eventId: firstEvent['id']?.toString(),
        eventDraft: null,
        uiTitle: title.isNotEmpty
            ? 'A great event fits your schedule today'
            : 'You have a good event option right now',
        uiBody:
            'You seem available around $slotHour. This event matches your free time and can be an easy win between classes.',
        ctaText: 'View event',
      );
    }

    final sport = (userData['mainSport'] ?? 'soccer').toString().trim();
    final hour = (firstSlot?['hora_inicio'] ?? '18:00').trim();
    final place = (firstSlot?['lugar'] ?? 'Campus').trim();

    return SmartRecommendation(
      type: RecommendationType.create,
      eventId: null,
      eventDraft: EventDraft(
        deporte: sport.isEmpty ? 'soccer' : sport,
        horaInicio: hour.isEmpty ? '18:00' : hour,
        lugar: place.isEmpty ? 'Campus' : place,
      ),
      uiTitle: 'Perfect moment to create your own match',
      uiBody:
          'You have a free slot around $hour. Creating an event now can fill that gap and help you find teammates quickly.',
      ctaText: 'Create event',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTodayEvents() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _firestore
        .collection('events')
        .where('status', isEqualTo: 'active')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .limit(30)
        .get();

    return snap.docs
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': (data['title'] ?? '').toString(),
            'sport': (data['sport'] ?? '').toString(),
            'location': (data['location'] ?? '').toString(),
            'hora_inicio': _formatHour(data['scheduledAt']),
            'maxParticipants': data['maxParticipants'],
            'currentParticipants':
                (data['participants'] is List) ? (data['participants'] as List).length : 0,
          };
        })
        .toList();
  }

  String _buildPrompt({
    required Map<String, dynamic> userData,
    required List<Map<String, String>> freeSlots,
    required List<Map<String, dynamic>> todayEvents,
  }) {
    final payload = {
      'user': {
        'uid': userData['uid'],
        'fullName': userData['fullName'],
        'program': userData['program'],
        'semester': userData['semester'],
        'mainSport': userData['mainSport'],
      },
      'free_time_slots': freeSlots,
      'today_events': todayEvents,
    };

    return '''
Analyze the following UniandesSport context and return EXACTLY one strict JSON object.

Rules:
1) Decide between "join" and "create".
2) If "join", evento_id must be one of today_events.id and borrador_evento must be null.
3) If "create", evento_id must be null and borrador_evento must include deporte, hora_inicio, lugar.
4) ui_title, ui_body and cta_text must be engaging English copy for a university student.
5) Keep ui_body concise (max 2 sentences).

Return format:
{
  "tipo_recomendacion": "join" | "create",
  "evento_id": "string or null",
  "borrador_evento": {"deporte":"", "hora_inicio":"", "lugar":""} | null,
  "ui_title": "",
  "ui_body": "",
  "cta_text": ""
}

Context JSON:
${jsonEncode(payload)}
''';
  }

  List<Map<String, String>> _parseFreeSlots(Object? raw) {
    if (raw is! List) return const [];

    return raw.whereType<Map>().map((slot) {
      final map = Map<String, dynamic>.from(slot);
      return {
        'dia': (map['dia'] ?? '').toString(),
        'hora_inicio': (map['hora_inicio'] ?? '').toString(),
        'hora_fin': (map['hora_fin'] ?? '').toString(),
        'lugar': (map['lugar'] ?? '').toString(),
      };
    }).where((slot) {
      return slot['dia']!.trim().isNotEmpty &&
          slot['hora_inicio']!.trim().isNotEmpty &&
          slot['hora_fin']!.trim().isNotEmpty;
    }).toList();
  }

  String _sanitizeJson(String text) {
    final raw = text.trim();
    if (!raw.startsWith('```')) return raw;

    return raw
        .split('\n')
        .where((line) => !line.trim().startsWith('```'))
        .join('\n')
        .trim();
  }

  String _formatHour(Object? timestampValue) {
    if (timestampValue is! Timestamp) return '';
    final date = timestampValue.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _errorToMessage(Object error, {required String fallback}) {
    if (error is SmartRecommendationGenerationException) return error.message;
    if (error is FirebaseException) {
      return _firebaseMessage(error, fallback: fallback);
    }
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    if (text.startsWith('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }
    return text;
  }

  String _firebaseMessage(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied while saving recommendation. Check Firestore rules.';
      case 'unavailable':
        return 'Firestore is unavailable right now. Please try again.';
      case 'failed-precondition':
        return 'Firestore requires an index for this query. Please create it and try again.';
      default:
        return fallback;
    }
  }
}
