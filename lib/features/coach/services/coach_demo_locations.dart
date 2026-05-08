import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLng demoCoachLatLngFor(String? coachId) {
  switch ((coachId ?? '').trim()) {
    case '1':
      return const LatLng(4.6012, -74.0657);
    case '2':
      return const LatLng(4.6034, -74.0721);
    case '3':
      return const LatLng(4.5989, -74.0623);
    case '4':
      return const LatLng(4.6071, -74.0698);
    default:
      return const LatLng(4.6029, -74.0669);
  }
}
