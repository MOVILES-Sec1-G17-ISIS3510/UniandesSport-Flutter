import 'package:uniandessport_flutter/features/home/domain/models/time_slot.dart';

class GoogleCalendarService {
  GoogleCalendarService._internal();

  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();

  static GoogleCalendarService getInstance() => _instance;

  bool _isSignedIn = false;

  bool get isSignedIn => _isSignedIn;

  Future<bool> initialize() async => true;

  Future<bool> signIn() async {
    _isSignedIn = true;
    return true;
  }

  Future<void> signOut() async {
    _isSignedIn = false;
  }

  Future<List<TimeSlot>> getAvailableTimeSlots([DateTime? referenceDate]) async {
    return const [];
  }
}