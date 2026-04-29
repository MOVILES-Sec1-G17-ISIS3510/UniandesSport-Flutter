import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../services/gemini_availability_service.dart';
import '../models/time_slot.dart';

class ProfileAvailabilityWidget extends StatefulWidget {
  final String userId;

  const ProfileAvailabilityWidget({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileAvailabilityWidget> createState() =>
      _ProfileAvailabilityWidgetState();
}

class _ProfileAvailabilityWidgetState extends State<ProfileAvailabilityWidget> {
  AudioRecorder? _recorder;
  GeminiAvailabilityService? _geminiService;
  String? _initError;

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _audioPath;
  List<TimeSlot> _slots = const [];

  @override
  void dispose() {
    _recorder?.dispose();
    super.dispose();
  }

  Future<bool> _ensureServicesReady() async {
    if (_recorder != null && _geminiService != null) return true;

    try {
      _recorder ??= AudioRecorder();
      _geminiService ??= GeminiAvailabilityService();
      if (_initError != null && mounted) {
        setState(() => _initError = null);
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'No se pudo inicializar disponibilidad por voz: $e';
        });
      }
      return false;
    }
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;

    final ready = await _ensureServicesReady();
    if (!ready || _recorder == null) {
      _showMessage(_initError ?? 'Grabador no disponible.');
      return;
    }

    if (_isRecording) {
      await _stopRecordingAndProcess();
      return;
    }

    final hasPermission = await _recorder!.hasPermission();
    if (!hasPermission) {
      _showMessage('No se otorgo permiso de microfono.');
      return;
    }

    final path =
        '${Directory.systemTemp.path}/availability_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _audioPath = path;
    });
  }

  Future<void> _stopRecordingAndProcess() async {
    if (_recorder == null || _geminiService == null) {
      _showMessage(_initError ?? 'Servicio no disponible.');
      return;
    }

    try {
      final outputPath = await _recorder!.stop();
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      final pathToProcess = outputPath ?? _audioPath;
      if (pathToProcess == null || pathToProcess.isEmpty) {
        throw Exception('No se encontro el archivo de audio para procesar.');
      }

      final slots = await _geminiService!.extractAvailabilityFromAudio(
        pathToProcess,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
            'free_time_slots': slots.map((slot) => slot.toJson()).toList(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _slots = slots;
      });

      _showMessage('Disponibilidad actualizada correctamente.');
    } catch (e) {
      _showMessage('Error procesando disponibilidad: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponibilidad inteligente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _initError!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilidad inteligente',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Graba una nota de voz con tus huecos para que UniandesSport actualice tus horarios libres.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Detener' : 'Grabar disponibilidad'),
              ),
              const SizedBox(width: 12),
              if (_isProcessing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
            ],
          ),
          if (_slots.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Bloques detectados',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots
                  .map(
                    (slot) => Chip(
                      label: Text(
                        '${slot.dia}: ${slot.horaInicio}-${slot.horaFin}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
