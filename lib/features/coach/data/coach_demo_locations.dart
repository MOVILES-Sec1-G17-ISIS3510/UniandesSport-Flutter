import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLng demoCoachLatLngFor(String? coachId) {
  switch (coachId) {
    case 'coach_1':
      return const LatLng(4.7110, -74.0721);
    case 'coach_2':
      return const LatLng(4.7090, -74.0650);
    case 'coach_3':
      return const LatLng(4.7165, -74.0780);
    default:
      return const LatLng(4.710989, -74.072090);
  }
}