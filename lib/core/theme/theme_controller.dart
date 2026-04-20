import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Controls dynamic app theming based on ambient light and battery level.
///
/// Decision rules:
/// - Low battery forces dark mode to reduce energy usage on many displays.
/// - Ambient light from camera samples toggles between dark/light modes.
/// - Smoothing and confidence counters avoid flickering caused by noisy frames.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  /// Registers lifecycle observer so theme monitoring can pause/resume with app state.
  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const double _darkLightThreshold = 0.34;
  static const double _lightLightThreshold = 0.42;
  static const double _strongLightThreshold = 0.55;
  static const double _instantDarkThreshold = 0.20;
  static const double _smoothingFactor = 0.75;
  static const int _requiredDarkSamples = 1;
  static const int _requiredLightSamples = 2;
  static const int _lowBatteryThreshold = 20;
  static const Duration _batteryRefreshInterval = Duration(minutes: 1);
  static const Duration _cameraSampleInterval = Duration(milliseconds: 300);
  static const int _bgraSampleStride = 16;
  static const int _yPlaneSampleStride = 32;
  static const List<ImageFormatGroup> _preferredImageFormats = [
    ImageFormatGroup.unknown,
    ImageFormatGroup.yuv420,
    ImageFormatGroup.bgra8888,
  ];

  final Battery _battery = Battery();

  ThemeMode _themeMode = ThemeMode.light;
  Timer? _batteryTimer;
  CameraController? _cameraController;
  bool _monitoringStarted = false;
  bool _isCameraInitializing = false;
  bool _isDisposed = false;
  int? _batteryLevel;
  double? _ambientLight;
  double? _smoothedAmbientLight;
  int _darkConfidence = 0;
  int _lightConfidence = 0;
  DateTime _lastCameraSample = DateTime.fromMillisecondsSinceEpoch(0);

  /// Current mode consumed by MaterialApp.themeMode.
  ThemeMode get themeMode => _themeMode;

  /// Starts battery polling and camera sampling, then applies theme rules.
  ///
  /// Safe to call multiple times; monitoring starts only once per dependency.
  Future<void> startMonitoring() async {
    if (_isDisposed) {
      return;
    }

    if (!_monitoringStarted) {
      await _refreshBatteryLevel();
      _batteryTimer?.cancel();
      _batteryTimer = Timer.periodic(_batteryRefreshInterval, (_) {
        unawaited(_refreshBatteryLevel());
      });
      _monitoringStarted = true;
    }

    if (_cameraController == null) {
      await _startCameraMonitoring();
    }

    _applyThemePreference();
  }

  /// Refreshes battery percentage used by the low-battery dark-mode rule.
  Future<void> _refreshBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _applyThemePreference();
    } catch (_) {
      // Some desktop/web targets do not expose battery information.
    }
  }

  /// Initializes front camera and starts image streaming for light estimation.
  ///
  /// Includes defensive checks for unsupported targets and concurrent starts.
  Future<void> _startCameraMonitoring() async {
    if (_isDisposed ||
        kIsWeb ||
        _cameraController != null ||
        _isCameraInitializing) {
      return;
    }

    _isCameraInitializing = true;

    final isMobileTarget =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobileTarget) {
      _isCameraInitializing = false;
      return;
    }

    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      debugPrint('ThemeController: camera permission not granted.');
      _isCameraInitializing = false;
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _isCameraInitializing = false;
        return;
      }

      final orderedCameras = <CameraDescription>[
        ...cameras.where(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        ),
        ...cameras.where(
          (camera) => camera.lensDirection == CameraLensDirection.external,
        ),
        ...cameras.where(
          (camera) =>
              camera.lensDirection != CameraLensDirection.front &&
              camera.lensDirection != CameraLensDirection.external,
        ),
      ];

      for (final candidateCamera in orderedCameras) {
        final controller = await _tryCreateStreamingController(candidateCamera);
        if (controller == null) {
          continue;
        }

        if (_isDisposed) {
          await controller.dispose();
          return;
        }

        _cameraController = controller;
        debugPrint(
          'ThemeController: camera stream started with ${candidateCamera.name}.',
        );
        return;
      }

      debugPrint('ThemeController: failed to initialize any camera stream.');
      _cameraController = null;
    } catch (error) {
      debugPrint('ThemeController: camera initialization error: $error');
      _cameraController = null;
    } finally {
      _isCameraInitializing = false;
    }
  }

  Future<CameraController?> _tryCreateStreamingController(
    CameraDescription camera,
  ) async {
    for (final format in _preferredImageFormats) {
      CameraController? controller;
      try {
        controller = CameraController(
          camera,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: format,
        );

        await controller.initialize();
        await controller.startImageStream(_handleCameraImage);
        return controller;
      } catch (error) {
        debugPrint(
          'ThemeController: camera ${camera.name} failed with format $format: $error',
        );
        if (controller != null) {
          try {
            if (controller.value.isStreamingImages) {
              await controller.stopImageStream();
            }
          } catch (_) {}

          try {
            await controller.dispose();
          } catch (_) {}
        }
      }
    }

    return null;
  }

  /// Processes camera frames at a controlled cadence and updates smoothed light.
  void _handleCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastCameraSample) < _cameraSampleInterval) {
      return;
    }

    _lastCameraSample = now;
    _ambientLight = _estimateBrightness(image);

    final previousSmoothed = _smoothedAmbientLight;
    if (previousSmoothed == null) {
      _smoothedAmbientLight = _ambientLight;
    } else {
      _smoothedAmbientLight =
          (previousSmoothed * (1 - _smoothingFactor)) +
          (_ambientLight! * _smoothingFactor);
    }

    _applyThemePreference();
  }

  /// Approximates brightness from camera planes and normalizes to [0, 1].
  double _estimateBrightness(CameraImage image) {
    if (image.planes.isEmpty) {
      return 1;
    }

    final Uint8List bytes = image.planes.first.bytes;
    if (bytes.isEmpty) {
      return 1;
    }

    if (image.format.group == ImageFormatGroup.bgra8888 && bytes.length >= 4) {
      var redTotal = 0;
      var greenTotal = 0;
      var blueTotal = 0;
      var sampleCount = 0;

      for (
        var index = 0;
        index + 3 < bytes.length;
        index += _bgraSampleStride
      ) {
        blueTotal += bytes[index];
        greenTotal += bytes[index + 1];
        redTotal += bytes[index + 2];
        sampleCount++;
      }

      if (sampleCount == 0) {
        return 1;
      }

      final average =
          (redTotal + greenTotal + blueTotal) / (3 * sampleCount * 255);
      return average.clamp(0.0, 1.0);
    }

    var total = 0;
    var sampleCount = 0;

    for (var index = 0; index < bytes.length; index += _yPlaneSampleStride) {
      total += bytes[index];
      sampleCount++;
    }

    if (sampleCount == 0) {
      return 1;
    }

    return (total / (sampleCount * 255)).clamp(0.0, 1.0);
  }

  /// Applies theme decision logic using battery-first then ambient-light rules.
  void _applyThemePreference() {
    final batteryLow = (_batteryLevel ?? 100) <= _lowBatteryThreshold;
    final rawAmbientLight = _ambientLight;
    final ambientLight = _smoothedAmbientLight ?? rawAmbientLight;

    ThemeMode nextThemeMode = _themeMode;
    if (batteryLow) {
      _darkConfidence = 0;
      _lightConfidence = 0;
      nextThemeMode = ThemeMode.dark;
    } else if (rawAmbientLight != null &&
        rawAmbientLight <= _instantDarkThreshold) {
      _darkConfidence = _requiredDarkSamples;
      _lightConfidence = 0;
      nextThemeMode = ThemeMode.dark;
    } else if (ambientLight == null) {
      // Keep current mode until we have a reliable camera sample.
      nextThemeMode = _themeMode;
    } else if (ambientLight <= _darkLightThreshold) {
      _darkConfidence++;
      _lightConfidence = 0;
      if (_darkConfidence >= _requiredDarkSamples) {
        nextThemeMode = ThemeMode.dark;
      }
    } else if (ambientLight >= _lightLightThreshold) {
      _lightConfidence++;
      _darkConfidence = 0;
      final enoughLightConfidence = _lightConfidence >= _requiredLightSamples;
      final strongAmbientLight = ambientLight >= _strongLightThreshold;
      if (enoughLightConfidence || strongAmbientLight) {
        nextThemeMode = ThemeMode.light;
      }
    } else {
      _darkConfidence = 0;
      _lightConfidence = 0;
    }

    if (nextThemeMode != _themeMode) {
      _themeMode = nextThemeMode;
      notifyListeners();
    }
  }

  /// Pauses/restarts camera monitoring based on app lifecycle transitions.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(startMonitoring());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_pauseAndDisposeCamera());
    }
  }

  /// Stops image stream and disposes the active camera controller safely.
  Future<void> _pauseAndDisposeCamera() async {
    final controller = _cameraController;
    if (controller == null) {
      return;
    }

    _cameraController = null;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore stream shutdown issues when the app is backgrounded.
    }

    try {
      await controller.dispose();
    } catch (_) {
      // Ignore disposal errors during shutdown.
    }
  }

  /// Releases timers, lifecycle observer, and camera resources.
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _batteryTimer?.cancel();
    unawaited(_pauseAndDisposeCamera());
    super.dispose();
  }
}
