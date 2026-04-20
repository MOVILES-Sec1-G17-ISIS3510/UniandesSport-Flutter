import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Puntos de demostración en Bogotá, Colombia (zonas aproximadas, solo para demo).
const List<LatLng> kBogotaDemoCoachLocations = [
  LatLng(4.6682, -74.0533), // Chapinero / Zona Rosa
  LatLng(4.6495, -74.0634),
  LatLng(4.6956, -74.0309), // Usaquén
  LatLng(4.5981, -74.0758), // La Candelaria
  LatLng(4.6483, -74.0959), // Teusaquillo
  LatLng(4.7020, -74.1090), // Salitre
  LatLng(4.6371, -74.0809), // Kennedy
  LatLng(4.7110, -74.0721), // Centro financiero
];

/// Ubicación de ejemplo estable para un coach (determinística por id).
LatLng demoCoachLatLngFor(String? coachId) {
  if (coachId == null || coachId.isEmpty) {
    return kBogotaDemoCoachLocations.first;
  }
  var h = 0;
  for (final c in coachId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return kBogotaDemoCoachLocations[h % kBogotaDemoCoachLocations.length];
}
