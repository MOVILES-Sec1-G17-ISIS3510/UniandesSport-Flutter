import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/calisthenics_result_model.dart';

// Debug logging
void _log(String message) {
  if (kDebugMode) {
    print('[CalisthenicsAIService] $message');
  }
}

class CalisthenicsAIServiceException implements Exception {
  final String message;
  final bool isNetworkError;

  const CalisthenicsAIServiceException(
    this.message, {
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

/// Servicio de IA para análisis de calistenia usando Gemini.
///
/// Flujo:
/// 1. Recibe una imagen capturada por cámara
/// 2. Guarda la imagen en local files (directorio temporal de la app)
/// 3. Envía la imagen a Gemini 2.5-flash con prompt específico
/// 4. Parsea la respuesta JSON
/// 5. Guarda el resultado en Hive con timestamp del análisis
/// 6. Si falla la conexión, lanza excepción con flag isNetworkError=true
///    permitiendo reintentos hasta éxito
class CalisthenicsAIService {
  CalisthenicsAIService._internal();

  static final CalisthenicsAIService _instance =
      CalisthenicsAIService._internal();

  factory CalisthenicsAIService() {
    return _instance;
  }

  // API Key (reemplazar con la nueva clave generada)
  static final String _apiKey = (() {
    final key = dotenv.env['GEMINI_API_KEY'];
   if (key == null || key.isEmpty) {
   throw StateError('GEMINI_API_KEY no está configurada');
   }
   return key;
   })();

  static const String _modelName = 'gemini-2.5-flash';
  static const String _boxName = 'calisthenics_results';

  late final GenerativeModel _model = GenerativeModel(
    model: _modelName,
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0.1,
    ),
    systemInstruction: Content.system(_systemInstruction),
  );

  static const String _systemInstruction = '''Eres el motor de análisis de ejercicios de calistenia para UniandesSport. Tu única tarea es analizar una imagen de una persona realizando un ejercicio de calistenia y proporcionar retroalimentación detallada.

REGLAS CRÍTICAS:
1. Identifica el ejercicio específico (ej: push-up, pull-up, dips, handstand, etc.)
2. Evalúa la postura en escala 0-100 basado en:
   - Alineación del cuerpo
   - Posición de las articulaciones
   - Distribución del peso
   - Simetría y balance
3. Identifica áreas de riesgo de lesión
4. Proporciona consejos prácticos y específicos
5. Sugiere ejercicios similares para progresión
6. Devuelve ÚNICAMENTE un JSON válido sin explicaciones adicionales

FORMATO DE RESPUESTA (OBLIGATORIO):
{
  "postureScore": <número 0-100>,
  "postureAnalysis": "<descripción detallada de la postura observada>",
  "feedback": "<retroalimentación principal sobre la ejecución>",
  "recommendations": ["<recomendación 1>", "<recomendación 2>", "<recomendación 3>"],
  "similarExercises": ["<ejercicio similar 1>", "<ejercicio similar 2>"],
  "detectedExercise": "<nombre del ejercicio>",
  "riskAreas": ["<área de riesgo 1>", "<área de riesgo 2>"],
  "tips": ["<tip práctico 1>", "<tip práctico 2>", "<tip práctico 3>"]
}

Todos los campos son obligatorios. Los arrays deben tener al menos 2 elementos.''';

  /// Inicializa el servicio y abre la caja de Hive.
  Future<void> initialize() async {
    try {
      _log('Initializing CalisthenicsAIService');

      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<CalisthenicsResultModel>(_boxName);
        _log('Hive box "$_boxName" opened');
      }
    } catch (e) {
      _log('Error initializing Hive box: $e');
      rethrow;
    }
  }

  /// Analiza una imagen capturada y devuelve el resultado.
  ///
  /// Flujo:
  /// 1. Guarda la imagen en local files
  /// 2. Envía a Gemini con el prompt
  /// 3. Parsea la respuesta
  /// 4. Guarda en Hive
  ///
  /// Lanza [CalisthenicsAIServiceException] con isNetworkError=true si hay
  /// problemas de conexión, permitiendo reintentos.
  Future<CalisthenicsResultModel> analyzeExerciseImage(
    List<int> imageBytes,
  ) async {
    _log('Starting exercise analysis');

    try {
      // 1. Guardar imagen en local files
      final imagePath = await _saveImageLocally(imageBytes);
      _log('Image saved to: $imagePath');

      // 2. Leer la imagen de nuevo para enviar a Gemini
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      _log('Image bytes read: ${bytes.length} bytes');

      // 3. Enviar a Gemini
      _log('Sending request to Gemini 2.5-flash...');
      final response = await _callGeminiWithImage(bytes);
      final rawText = response.text;
      _log('Raw Gemini response: $rawText');

      if (rawText == null || rawText.trim().isEmpty) {
        throw CalisthenicsAIServiceException(
          'Gemini returned empty response',
          isNetworkError: false,
        );
      }

      // 4. Parsear respuesta JSON
      final result = _parseGeminiResponse(rawText);
      _log('Successfully parsed response');

      // 5. Guardar en Hive
      await _saveToHive(result);
      _log('Result saved to Hive');

      return result;
    } on CalisthenicsAIServiceException {
      rethrow;
    } on SocketException catch (e) {
      final msg = 'Network error: ${e.message}';
      _log(msg);
      throw CalisthenicsAIServiceException(msg, isNetworkError: true);
    } on TimeoutException catch (e) {
      final msg = 'Request timeout: ${e.message}';
      _log(msg);
      throw CalisthenicsAIServiceException(msg, isNetworkError: true);
    } catch (e) {
      final msg = 'Unexpected error during analysis: $e';
      _log(msg);
      throw CalisthenicsAIServiceException(msg, isNetworkError: false);
    }
  }

  /// Obtiene el último análisis guardado en Hive (si existe).
  CalisthenicsResultModel? getLastAnalysis() {
    try {
      final box = Hive.box<CalisthenicsResultModel>(_boxName);
      if (box.isEmpty) return null;

      // El último análisis es el que tiene la clave más alta
      final keys = box.keys.toList();
      final lastKey = keys.isNotEmpty ? keys.last : null;
      return lastKey != null ? box.get(lastKey) : null;
    } catch (e) {
      _log('Error retrieving last analysis: $e');
      return null;
    }
  }

  /// Obtiene todos los análisis guardados en Hive.
  List<CalisthenicsResultModel> getAllAnalyses() {
    try {
      final box = Hive.box<CalisthenicsResultModel>(_boxName);
      return box.values.toList();
    } catch (e) {
      _log('Error retrieving all analyses: $e');
      return [];
    }
  }

  /// Limpia todos los análisis guardados en Hive.
  Future<void> clearAllAnalyses() async {
    try {
      final box = Hive.box<CalisthenicsResultModel>(_boxName);
      await box.clear();
      _log('All analyses cleared from Hive');
    } catch (e) {
      _log('Error clearing analyses: $e');
      rethrow;
    }
  }

  /// Guarda una imagen capturada en el directorio temporal de la app.
  Future<String> _saveImageLocally(List<int> imageBytes) async {
    try {
      final appDir = await getTemporaryDirectory();
      final fileName =
          'exercise_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${appDir.path}/$fileName');

      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      _log('Error saving image locally: $e');
      throw CalisthenicsAIServiceException(
        'Failed to save image: $e',
        isNetworkError: false,
      );
    }
  }

  /// Llama a Gemini con la imagen.
  Future<GenerateContentResponse> _callGeminiWithImage(
    List<int> imageBytes,
  ) async {
    try {
      const mimeType = 'image/jpeg';
      final prompt = TextPart(
        'Analiza esta imagen de un ejercicio de calistenia. Identifica el ejercicio, evalúa la postura y proporciona retroalimentación detallada.',
      );
      final imagePart = DataPart(mimeType, Uint8List.fromList(imageBytes));

      final response = await _model
          .generateContent([Content.multi([prompt, imagePart])])
          .timeout(const Duration(seconds: 30));

      return response;
    } on CalisthenicsAIServiceException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on SocketException {
      rethrow;
    } catch (e) {
      _log('Error calling Gemini: $e');

      // Detectar si es un error de red
      final isNetwork = e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('network');

      throw CalisthenicsAIServiceException(
        'Failed to call Gemini: $e',
        isNetworkError: isNetwork,
      );
    }
  }

  /// Parsea la respuesta JSON de Gemini.
  CalisthenicsResultModel _parseGeminiResponse(String rawText) {
    try {
      final cleanJson = _stripMarkdownJsonFence(rawText);
      final jsonData = jsonDecode(cleanJson) as Map<String, dynamic>;

      final result = CalisthenicsResultModel.fromJson(jsonData);
      return result;
    } on FormatException catch (e) {
      _log('JSON parsing error: $e');
      throw CalisthenicsAIServiceException(
        'Invalid JSON response from Gemini: $e',
        isNetworkError: false,
      );
    } catch (e) {
      _log('Error parsing response: $e');
      throw CalisthenicsAIServiceException(
        'Failed to parse Gemini response: $e',
        isNetworkError: false,
      );
    }
  }

  /// Elimina cercas de markdown ```json ... ``` si existen.
  static String _stripMarkdownJsonFence(String input) {
    if (!input.startsWith('```')) return input;

    final lines = input.split('\n');
    final filtered = lines.where((line) => !line.trim().startsWith('```'));
    return filtered.join('\n').trim();
  }

  /// Guarda el resultado en Hive.
  Future<void> _saveToHive(CalisthenicsResultModel result) async {
    try {
      final box = Hive.box<CalisthenicsResultModel>(_boxName);
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      await box.put(key, result);
      _log('Result stored in Hive with key: $key');
    } catch (e) {
      _log('Error saving to Hive: $e');
      throw CalisthenicsAIServiceException(
        'Failed to save analysis: $e',
        isNetworkError: false,
      );
    }
  }
}

