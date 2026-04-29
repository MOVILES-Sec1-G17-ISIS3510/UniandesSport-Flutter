import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide ServiceStatus;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_theme.dart';
import '../services/coach_demo_locations.dart';
import '../models/coach_model.dart';

/// Google Maps en este proyecto solo está integrado en Android e iOS.
bool isCoachMapsSdkSupported() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Mapa con marcador del coach (demo, Bogotá) y ubicación del usuario en vivo.
class CoachMapPage extends StatefulWidget {
  const CoachMapPage({super.key, required this.coach});

  final Coach coach;

  @override
  State<CoachMapPage> createState() => _CoachMapPageState();
}

class _CoachMapPageState extends State<CoachMapPage> {
  GoogleMapController? _mapController;
  late final LatLng _coachLatLng;
  late final CameraPosition _initialCamera;
  late final Marker _coachMarker;

  /// Marcador propio para el usuario (más fiable que la capa azul de Maps + Play Services).
  Set<Marker> _markers = {};
  LatLng? _userLatLng;

  bool _userLocationTracking = false;
  StreamSubscription<Position>? _userPositionSub;

  @override
  void initState() {
    super.initState();
    _coachLatLng = demoCoachLatLngFor(widget.coach.id);
    _initialCamera = CameraPosition(target: _coachLatLng, zoom: 14);
    _coachMarker = Marker(
      markerId: const MarkerId('coach'),
      position: _coachLatLng,
      infoWindow: InfoWindow(
        title: widget.coach.nombre ?? 'Coach',
        snippet: 'Demo · Bogotá',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
    );
    _markers = {_coachMarker};
    if (isCoachMapsSdkSupported()) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _requestLocationForMap(),
      );
    }
  }

  bool _isLocationPermissionOk(PermissionStatus status) =>
      status.isGranted || status == PermissionStatus.limited;

  void _rebuildMarkers() {
    _markers = {
      _coachMarker,
      if (_userLatLng != null)
        Marker(
          markerId: const MarkerId('user'),
          position: _userLatLng!,
          infoWindow: const InfoWindow(
            title: 'Tú',
            snippet: 'Tu posición (GPS)',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };
  }

  void _startUserPositionStream() {
    _userPositionSub?.cancel();
    _userPositionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (pos) {
            if (!mounted) return;
            setState(() {
              _userLatLng = LatLng(pos.latitude, pos.longitude);
              _rebuildMarkers();
            });
          },
          onError: (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'No se pudo actualizar la posición en vivo.',
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        );
  }

  /// Pide permiso con [permission_handler]; la posición del usuario se pinta con marcador + stream.
  Future<void> _requestLocationForMap() async {
    if (!mounted) return;

    ServiceStatus serviceStatus;
    try {
      serviceStatus = await Permission.location.serviceStatus;
    } catch (_) {
      serviceStatus = ServiceStatus.enabled;
    }

    if (!mounted) return;
    if (serviceStatus == ServiceStatus.disabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'La ubicación está desactivada en el dispositivo; solo verás el punto del coach.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    var status = await Permission.location.status;
    if (!mounted) return;
    if (_isLocationPermissionOk(status)) {
      setState(() {
        _userLocationTracking = true;
        _rebuildMarkers();
      });
      _startUserPositionStream();
      return;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'El permiso de ubicación está bloqueado. Actívalo en Ajustes para ver tu posición en el mapa.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Ajustes',
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ubicación en el mapa',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Para mostrar tu posición en tiempo real junto al coach, la app '
            'necesita permiso de ubicación. El marcador del coach se ve igual sin este permiso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (!mounted || consent != true) return;

    // Importante: en varios Android el valor de retorno de [request] llega antes
    // de que el sistema actualice el estado; se confía en [status] tras un breve delay.
    await Permission.location.request();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    status = await Permission.location.status;
    if (!mounted) return;

    if (_isLocationPermissionOk(status)) {
      setState(() {
        _userLocationTracking = true;
        _rebuildMarkers();
      });
      _startUserPositionStream();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? 'Puedes activar el permiso más tarde en Ajustes de la app.'
                : 'Si acabas de aceptar el permiso y ves este mensaje, '
                      'revisa en Ajustes que la ubicación esté en “Permitir” para esta app.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Ajustes',
                  textColor: Colors.white,
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _userPositionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fitCoachAndUser() async {
    final c = _mapController;
    if (c == null) return;
    try {
      final user = await Geolocator.getCurrentPosition();
      final south = user.latitude < _coachLatLng.latitude
          ? user.latitude
          : _coachLatLng.latitude;
      final north = user.latitude > _coachLatLng.latitude
          ? user.latitude
          : _coachLatLng.latitude;
      final west = user.longitude < _coachLatLng.longitude
          ? user.longitude
          : _coachLatLng.longitude;
      final east = user.longitude > _coachLatLng.longitude
          ? user.longitude
          : _coachLatLng.longitude;
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          80,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vista ajustada: tú y ${widget.coach.nombre ?? "el coach"}',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _coachLatLng, zoom: 14),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isCoachMapsSdkSupported()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapa')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 56, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'El mapa con Google Maps está disponible en la app para '
                  'Android e iOS.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.coach.nombre ?? 'Coach',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            key: ValueKey(_userLocationTracking ? 'map_track' : 'map_base'),
            initialCameraPosition: _initialCamera,
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.teal, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo: coach in Bogotá. Your position is the blue pin “You” '
                        '(Live GPS).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_userLocationTracking)
            FloatingActionButton.small(
              heroTag: 'fit',
              backgroundColor: colorScheme.surface,
              foregroundColor: AppTheme.teal,
              onPressed: _fitCoachAndUser,
              child: const Icon(Icons.fit_screen),
            ),
          if (_userLocationTracking) const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'coach',
            backgroundColor: AppTheme.teal,
            foregroundColor: Colors.white,
            onPressed: () async {
              final c = _mapController;
              if (c == null) return;
              await c.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _coachLatLng, zoom: 15),
                ),
              );
            },
            child: const Icon(Icons.sports),
          ),
        ],
      ),
    );
  }
}
