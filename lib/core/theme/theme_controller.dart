import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const double _darkLightThreshold = 0.30;
  static const double _lightLightThreshold = 0.36;
  static const double _strongLightThreshold = 0.50;
  static const double _smoothingFactor = 0.40;
  static const int _requiredDarkSamples = 2;
  static const int _requiredLightSamples = 1;
  static const int _lowBatteryThreshold = 20;
  static const Duration _batteryRefreshInterval = Duration(minutes: 1);
  static const Duration _cameraSampleInterval = Duration(milliseconds: 800);

  final Battery _battery = Battery();

  ThemeMode _themeMode = ThemeMode.light;
  Timer? _batteryTimer;
  CameraController? _cameraController;
  bool _monitoringStarted = false;
  bool _isDisposed = false;
  int? _batteryLevel;
  double? _ambientLight;
  double? _smoothedAmbientLight;
  int _darkConfidence = 0;
  int _lightConfidence = 0;
  DateTime _lastCameraSample = DateTime.fromMillisecondsSinceEpoch(0);

  ThemeMode get themeMode => _themeMode;

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

  Future<void> _refreshBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _applyThemePreference();
    } catch (_) {
      // Some desktop/web targets do not expose battery information.
    }
  }

  Future<void> _startCameraMonitoring() async {
    if (_isDisposed || kIsWeb) {
      return;
    }

    final isMobileTarget =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobileTarget) {
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (_isDisposed) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      await controller.startImageStream(_handleCameraImage);
    } catch (_) {
      _cameraController = null;
    }
  }

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
          (previousSmoothed * (1 - _smoothingFactor)) + (_ambientLight! * _smoothingFactor);
    }

    _applyThemePreference();
  }

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

      for (var index = 0; index + 3 < bytes.length; index += 16) {
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

    for (var index = 0; index < bytes.length; index += 32) {
      total += bytes[index];
      sampleCount++;
    }

    if (sampleCount == 0) {
      return 1;
    }

    return (total / (sampleCount * 255)).clamp(0.0, 1.0);
  }

  void _applyThemePreference() {
    final batteryLow = (_batteryLevel ?? 100) <= _lowBatteryThreshold;
    final ambientLight = _smoothedAmbientLight ?? _ambientLight;

    ThemeMode nextThemeMode = _themeMode;
    if (batteryLow) {
      _darkConfidence = 0;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(startMonitoring());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_pauseAndDisposeCamera());
    }
  }

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

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _batteryTimer?.cancel();
    unawaited(_pauseAndDisposeCamera());
    super.dispose();
  }
}
