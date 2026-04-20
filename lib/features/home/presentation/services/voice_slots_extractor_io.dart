import 'dart:io';

import 'package:record/record.dart';

import '../../data/services/gemini_availability_service.dart';
import '../../domain/models/time_slot.dart';

class VoiceSlotsExtractor {
  VoiceSlotsExtractor();

  final AudioRecorder _recorder = AudioRecorder();
  final GeminiAvailabilityService _gemini = GeminiAvailabilityService();

  String? _path;
  bool _recording = false;

  bool get isSupported => true;
  bool get isRecording => _recording;

  Future<bool> ensurePermission() async {
    return _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied.');
    }

    _path =
        '${Directory.systemTemp.path}/availability_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _path!,
    );

    _recording = true;
  }

  Future<List<TimeSlot>> stopAndExtract() async {
    if (!_recording) return const [];

    final output = await _recorder.stop();
    _recording = false;

    final audioPath = output ?? _path;
    if (audioPath == null || audioPath.isEmpty) {
      throw Exception('Could not access the recorded audio file.');
    }

    return _gemini.extractAvailabilityFromAudio(audioPath);
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

