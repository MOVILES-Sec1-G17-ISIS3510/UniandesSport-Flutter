import '../models/time_slot.dart';

class VoiceSlotsExtractor {
  bool get isSupported => false;
  bool get isRecording => false;

  Future<bool> ensurePermission() async => false;

  Future<void> startRecording() async {
    throw UnsupportedError('Voice extraction is not supported on this platform.');
  }

  Future<List<TimeSlot>> stopAndExtract() async {
    throw UnsupportedError('Voice extraction is not supported on this platform.');
  }

  Future<void> dispose() async {}
}

