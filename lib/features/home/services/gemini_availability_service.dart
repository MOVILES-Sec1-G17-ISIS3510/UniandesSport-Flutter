import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/time_slot.dart';

// Debug logging
void _log(String message) {
  if (kDebugMode) {
    print('[GeminiAvailabilityService] $message');
  }
}

class GeminiAvailabilityService {
  GeminiAvailabilityService();

  static const String _apiKey =
      'AIzaSyDdC2I3Y62cVLYu60G7q4TFJSFQWsnv5Uo';

  static const String _systemInstruction =
      "Eres el motor de extracción de datos para UniandesSport. Tu única tarea es analizar el mensaje de voz de un estudiante y extraer los bloques exactos de tiempo libre que tiene en su horario. Reglas: 1. Identifica días y rangos de tiempo. 2. Usa formato 24 horas (HH:MM). 3. Días en español con inicial mayúscula. 4. Interpreta jerga universitaria ('hueco', 'libre') como disponibilidad. 5. Resuelve ambigüedades lógicas. Debes devolver ÚNICAMENTE un arreglo JSON válido. Ejemplo: [{'dia': 'Lunes', 'hora_inicio': '14:00', 'hora_fin': '16:00'}]";

  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.1,
    ),
    systemInstruction: Content.system(_systemInstruction),
  );

  Future<List<TimeSlot>> extractAvailabilityFromAudio(
    String audioPath,
  ) async {
    _log('Starting audio extraction from: $audioPath');

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    final bytes = await file.readAsBytes();
    _log('Audio file read: ${bytes.length} bytes');

    final mimeType = _inferMimeType(audioPath);
    _log('Detected MIME type: $mimeType');

    final prompt = TextPart(
      'Extrae los bloques de disponibilidad del audio y responde solo JSON.',
    );
    final audioPart = DataPart(mimeType, bytes);

    _log('Sending request to Gemini 2.5-flash...');
    final response = await _model.generateContent([
      Content.multi([prompt, audioPart]),
    ]);

    final rawText = response.text;
    _log('Raw Gemini response: $rawText');

    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('Gemini returned an empty response');
    }

    _log('Attempting to parse JSON response...');
    return parseTimeSlotsJson(rawText);
  }

  @visibleForTesting
  static List<TimeSlot> parseTimeSlotsJson(String rawText) {
    final normalized = rawText.trim();
    _log('Normalized text: $normalized');

    final sanitized = _stripMarkdownJsonFence(normalized);
    _log('Sanitized text: $sanitized');

    try {
      final dynamic decoded = jsonDecode(sanitized);
      _log('Decoded JSON type: ${decoded.runtimeType}');

      if (decoded is! List) {
        _log('ERROR: Response is not a List, got: ${decoded.runtimeType}');
        throw Exception('Invalid response format: expected a JSON array');
      }

      final slots = decoded
          .whereType<Map<String, dynamic>>()
          .map(TimeSlot.fromJson)
          .where(
            (slot) =>
                slot.dia.isNotEmpty &&
                slot.horaInicio.isNotEmpty &&
                slot.horaFin.isNotEmpty,
          )
          .toList();

      _log('Successfully parsed ${slots.length} time slot(s)');
      return slots;
    } catch (e) {
      _log('JSON parsing error: $e');
      rethrow;
    }
  }

  static String _stripMarkdownJsonFence(String input) {
    if (!input.startsWith('```')) return input;

    final lines = input.split('\n');
    final filtered = lines.where((line) => !line.trim().startsWith('```'));
    return filtered.join('\n').trim();
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.m4a')) return 'audio/m4a';
    if (lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';

    return 'audio/m4a';
  }
}
