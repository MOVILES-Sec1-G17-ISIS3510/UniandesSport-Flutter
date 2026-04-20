import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wrapper para el sensor de pasos del dispositivo.
///
/// Esta capa desacopla la UI del plugin [pedometer] para poder:
/// - centralizar errores de plataforma/permisos,
/// - exponer un stream sencillo con el total de pasos del sistema,
/// - facilitar pruebas reemplazando esta clase por un fake/mocked service.
class StepSensorService {
  StreamSubscription<StepCount>? _stepSubscription;
  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();

  int? _latestTotalSteps;
  Object? _lastError;
  bool _initialized = false;

  Future<bool> _ensureActivityRecognitionPermission() async {
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) {
      return true;
    }

    final requested = await Permission.activityRecognition.request();
    return requested.isGranted;
  }

  /// Inicializa la escucha del sensor una sola vez.
  Future<void> initialize() async {
    if (_initialized) return;

    final permissionGranted = await _ensureActivityRecognitionPermission();
    if (!permissionGranted) {
      _lastError = StateError('Activity recognition permission not granted');
      return;
    }

    _stepSubscription = Pedometer.stepCountStream.listen(
      (event) {
        _latestTotalSteps = event.steps;
        _stepsController.add(event.steps);
      },
      onError: (error) {
        _lastError = error;
        if (!_stepsController.isClosed) {
          _stepsController.addError(error);
        }
      },
      onDone: () {
        _initialized = false;
      },
      cancelOnError: false,
    );

    _initialized = true;
  }

  /// Ultimo total de pasos conocido por el sensor desde boot del sistema.
  int? get latestTotalSteps => _latestTotalSteps;

  /// Stream con actualizaciones de pasos acumulados.
  Stream<int> get stepsStream => _stepsController.stream;

  /// Ultimo error capturado al leer el sensor.
  Object? get lastError => _lastError;

  /// Obtiene un snapshot util del sensor.
  ///
  /// Si no hay lectura previa, espera el primer evento por [timeout].
  Future<int?> getCurrentTotalSteps({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) {
        return null;
      }
    }

    if (_latestTotalSteps != null) {
      return _latestTotalSteps;
    }

    try {
      return await stepsStream.first.timeout(timeout);
    } catch (error) {
      _lastError = error;
      debugPrint('[StepSensorService] Could not get current steps: $error');
      return null;
    }
  }

  /// Libera listeners nativos del plugin cuando la pantalla ya no se usa.
  Future<void> dispose() async {
    await _stepSubscription?.cancel();
    await _stepsController.close();
    _stepSubscription = null;
    _initialized = false;
  }
}
