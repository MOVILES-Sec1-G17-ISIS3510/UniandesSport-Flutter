
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/calisthenics_ai_service.dart';
import '../../models/calisthenics_result_model.dart';

/// Ejemplo de pantalla para capturar imagen y analizar ejercicio de calistenia.
///
/// Este archivo es un EJEMPLO de cómo usar CalisthenicsAIService.
/// Puedes adaptarlo según tu arquitectura de app (MVVM, BLoC, etc).
class CalisthenicsAnalysisExampleScreen extends StatefulWidget {
  final bool startWithGallery;
  final bool viewOnlyMode;
  
  const CalisthenicsAnalysisExampleScreen({
    super.key, 
    this.startWithGallery = false,
    this.viewOnlyMode = false,
  });

  @override
  State<CalisthenicsAnalysisExampleScreen> createState() =>
      _CalisthenicsAnalysisExampleScreenState();
}

class _CalisthenicsAnalysisExampleScreenState
    extends State<CalisthenicsAnalysisExampleScreen> {
  final CalisthenicsAIService _service = CalisthenicsAIService();

  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;
  String? _errorMessage;
  CalisthenicsResultModel? _analysisResult;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initializeService().then((_) {
      if (widget.viewOnlyMode) {
        _loadLastAnalysis();
      } else {
        _initializeCamera();
        
        if (widget.startWithGallery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pickFromGallery();
          });
        }
      }
    });
  }

  Future<void> _initializeService() async {
    try {
      await _service.initialize();
    } catch (e) {
      _showError('Failed to initialize service: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
      );

      await _cameraController.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (!_isCameraInitialized) return;

    try {
      setState(() => _isAnalyzing = true);
      final xFile = await _cameraController.takePicture();
      final bytes = await xFile.readAsBytes();

      await _analyzeWithRetry(bytes);
    } catch (e) {
      _showError('Failed to capture image: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _isAnalyzing = true);
        final bytes = await image.readAsBytes();
        await _analyzeWithRetry(bytes);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  /// Analiza la imagen con reintentos automáticos en caso de error de red.
  Future<void> _analyzeWithRetry(List<int> imageBytes) async {
    _retryCount = 0;

    while (_retryCount < _maxRetries) {
      try {
        final result = await _service.analyzeExerciseImage(imageBytes);
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
          _errorMessage = null;
          _retryCount = 0;
        });
        return;
      } on CalisthenicsAIServiceException catch (e) {
        if (e.isNetworkError && _retryCount < _maxRetries - 1) {
          // Error de red: reintentar
          _retryCount++;
          await Future.delayed(Duration(seconds: 2 * _retryCount));
          continue;
        } else {
          // Error no recuperable o máximo de reintentos alcanzado
          setState(() {
            _isAnalyzing = false;
            _errorMessage = e.isNetworkError
                ? 'Network error. Please check your connection and try again.'
                : 'Analysis failed: ${e.message}';
          });
          return;
        }
      }
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _clearResult() {
    if (widget.viewOnlyMode) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _analysisResult = null;
      _errorMessage = null;
    });
  }

  Future<void> _loadLastAnalysis() async {
    final last = _service.getLastAnalysis();
    if (last != null) {
      setState(() => _analysisResult = last);
    } else {
      _showError('No previous analysis found');
    }
  }

  Future<void> _clearAllAnalyses() async {
    await _service.clearAllAnalyses();
    if (!mounted) return;
    setState(() => _analysisResult = null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All analyses cleared')),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Analysis'),
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearResult,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    // Mostrar error
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    // Mostrar resultado del análisis
    if (_analysisResult != null) {
      return _buildAnalysisResultView();
    }

    // Mostrar cámara
    if (_isCameraInitialized) {
      return _buildCameraView();
    }

    // Cargando
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        CameraPreview(_cameraController),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_isAnalyzing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadLastAnalysis,
                    icon: const Icon(Icons.history),
                    label: const Text('Last Analysis'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisResultView() {
    final result = _analysisResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Local Image
          FutureBuilder<File?>(
            future: _service.getLastImageFile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(snapshot.data!),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Exercise name and score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.detectedExercise,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Posture Score: '),
                    Text(
                      '${result.postureScore}/100',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(result.postureScore),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: result.postureScore / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getScoreColor(result.postureScore),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Analysis timestamp
          Text(
            'Analyzed at: ${result.analyzedAt}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),

          // Posture analysis
          _buildSection(
            title: 'Posture Analysis',
            content: result.postureAnalysis,
          ),
          const SizedBox(height: 16),

          // Main feedback
          _buildSection(
            title: 'Feedback',
            content: result.feedback,
          ),
          const SizedBox(height: 16),

          // Risk areas
          if (result.riskAreas.isNotEmpty)
            _buildListSection(
              title: '⚠️ Risk Areas',
              items: result.riskAreas,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              borderColor: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.2),
              textColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          const SizedBox(height: 16),

          // Tips
          if (result.tips.isNotEmpty)
            _buildListSection(
              title: '💡 Tips',
              items: result.tips,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              borderColor: Colors.green.withValues(alpha: 0.2),
              textColor: Theme.of(context).colorScheme.onSurface,
            ),
          const SizedBox(height: 16),

          // Recommendations
          if (result.recommendations.isNotEmpty)
            _buildListSection(
              title: '📋 Recommendations',
              items: result.recommendations,
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
              borderColor: Colors.orange.withValues(alpha: 0.2),
              textColor: Theme.of(context).colorScheme.onSurface,
            ),
          const SizedBox(height: 16),

          // Similar exercises
          if (result.similarExercises.isNotEmpty)
            _buildListSection(
              title: '🔄 Similar Exercises',
              items: result.similarExercises,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderColor: Theme.of(context).colorScheme.outlineVariant,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: 32),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _clearResult,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Analyze Another'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _clearAllAnalyses,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear History'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearResult,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $item',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget? _buildFloatingActionButton() {
    if (_analysisResult != null) return null;

    return FloatingActionButton(
      onPressed: _isAnalyzing ? null : _captureAndAnalyze,
      child: _isAnalyzing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.camera_alt),
    );
  }
}

