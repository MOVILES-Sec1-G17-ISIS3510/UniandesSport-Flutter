import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/calisthenics_ai_service.dart';
import '../models/calisthenics_result_model.dart';

/// Tarea estática o top-level para compresión de imágenes en un Isolate secundario.
/// Permite mantener los 60fps en la UI principal mientras se realiza 
/// el procesamiento intensivo de la imagen.
Future<Uint8List?> _compressImageTask(String imagePath) async {
  // FlutterImageCompress admite ejecutarse en Isolates secundarios 
  // usando Isolate.run en versiones recientes de Flutter.
  return await FlutterImageCompress.compressWithFile(
    imagePath,
    minWidth: 1024,
    minHeight: 1024,
    quality: 80,
  );
}

class CalisthenicsViewModel extends ChangeNotifier {
  final CalisthenicsAIService _aiService = CalisthenicsAIService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  CalisthenicsResultModel? _result;
  CalisthenicsResultModel? get result => _result;

  /// Analiza una imagen de calistenia manejando la compresión en un Isolate.
  Future<void> analyzeImage(String imagePath) async {
    _isLoading = true;
    _errorMessage = null;
    _result = null;
    notifyListeners();

    try {
      // 1. Compresión de la imagen en un Isolate usando Isolate.run()
      // Esto previene el bloqueo del Thread Principal (UI Thread).
      final compressedBytes = await Isolate.run(() => _compressImageTask(imagePath));

      if (compressedBytes == null) {
        throw Exception("Failed to compress the image.");
      }

      // 2. Envío a Gemini mediante el servicio
      _result = await _aiService.analyzeExerciseImage(compressedBytes);
      
    } on CalisthenicsAIServiceException catch (e) {
      _errorMessage = e.isNetworkError 
          ? 'Network error. Please check your connection and try again.' 
          : 'Analysis failed: ${e.message}';
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpia el estado actual
  void clearResult() {
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }
}
