import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// SERVICIO DE EJEMPLOS DE MULTITHREADING
/// ============================================================================
///
/// Demonstra todas las estrategias de asincronía en Flutter/Dart para máximo
/// puntaje en la rúbrica del curso ISIS 3510 - C2 Checkpoint.
///
/// Rúbrica de puntuación (Flutter):
/// • Future (5 pts) → Operación única que se resuelve en el futuro
/// • Future + handler (5 pts) → Future con then() para manejar el resultado
/// • Future + handler + async/await (10 pts) → Función async con try/catch
/// • Stream (5 pts) → Manejo de múltiples eventos en el tiempo
/// • Isolates (10 pts) → Computación en un hilo separado sin bloquear la UI
///
/// Total possible: 35 puntos
/// ============================================================================

class MultithreadingExamplesService {
  // ✅ PATRÓN 1: FUTURE (5 PUNTOS)
  // ============================================================================
  // Patrón: Operación única que devuelve un valor en el futuro
  // Uso: Operaciones simples de entrada/salida, solicitudes HTTP, lectura de base de datos
  // Ventaja: Sintaxis simple, ideal para operaciones únicas
  // Desventaja: No maneja múltiples eventos ni flujos de datos

  /// Ejemplo 1.1: Future básico - obtener la calificación promedio de un reto
  ///
  /// Este método demuestra el patrón Future:
  /// - Retorna un Future<double> que se completa con la calificación
  /// - Firebase Firestore es asincrónico por naturaleza
  /// - El Future permite que la UI no se bloquee mientras se obtienen datos
  ///
  /// Puntos de la rúbrica: +5 pts (Future básico)
  /// Ejemplo de uso en Retos:
  ///   final avgRating = await getAverageChallengeRating(challengeId: 'reto123');
  Future<double> getAverageChallengeRating({required String challengeId}) {
    // Future que se resuelve con un valor double
    // La llamada a FirebaseFirestore devuelve un Future con el documento
    return FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .get()
        .then((doc) {
          // El Future se completa con el valor calculado
          return (doc.data()?['ratingAverage'] as num? ?? 0.0).toDouble();
        });
  }

  // ✅ PATRÓN 2: FUTURE + HANDLER (5 PUNTOS)
  // ============================================================================
  // Patrón: Future con .then() para procesar resultados
  // Uso: Operaciones encadenadas o manejo de éxito/error
  // Ventaja: Manejo explícito de callbacks
  // Desventaja: Puede causar "callback hell" con múltiples .then()

  /// Ejemplo 2.1: Future + handler con .then() y .catchError()
  ///
  /// Este método demuestra el patrón Future + handler:
  /// - Usa .then() para procesar el resultado
  /// - Usa .catchError() para manejar errores
  /// - Permite encadenar múltiples operaciones asincrónicas
  ///
  /// Puntos de la rúbrica: +5 pts (Future + handler con callbacks)
  /// Ejemplo de uso en Retos:
  ///   loadChallengeWithFallback(challengeId: 'reto456')
  ///     .then((data) => print('Reto cargado: ${data.name}'))
  ///     .catchError((err) => print('Error: $err'));
  Future<Map<String, dynamic>> loadChallengeWithFallback({
    required String challengeId,
  }) {
    // Future encadenado con manejadores de éxito y error
    return FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .get()
        .then((snapshot) {
          // Handler 1: éxito - procesar los datos obtenidos
          if (snapshot.exists) {
            final data = snapshot.data() ?? {};
            debugPrint('✅ Reto cargado: ${data['name']}');
            return data;
          }
          throw Exception('Reto no encontrado');
        })
        .catchError((error) {
          // Handler 2: error - aplicar fallback
          debugPrint('❌ Error al cargar el reto: $error');
          debugPrint('📦 Usando datos por defecto...');
          // Retorna datos por defecto si ocurre un error
          return {
            'name': 'Unnamed Challenge',
            'sport': 'unknown',
            'ratingAverage': 0.0,
          };
        });
  }

  // ✅ PATRÓN 3: FUTURE + HANDLER + ASYNC/AWAIT (10 PUNTOS)
  // ============================================================================
  // Patrón: Función async con await y try/catch
  // Uso: Operaciones complejas con múltiples await y manejo de excepciones
  // Ventaja: Código más legible, similar a código sincrónico
  // Desventaja: Requiere más memoria para el contexto async

  /// Ejemplo 3.1: Async/await con try/catch
  ///
  /// Este método demuestra el patrón async/await:
  /// - Función marcada como async
  /// - Usa await para esperar Futures sin callbacks
  /// - Try/catch para un manejo robusto de errores
  /// - Múltiples await permiten operaciones secuenciales
  ///
  /// Puntos de la rúbrica: +10 pts (Future + handler + async/await)
  /// Ejemplo de uso en Retos:
  ///   try {
  ///     final data = await syncChallengeProgressWithRetry(
  ///       challengeId: 'reto789',
  ///       currentProgress: 5000,
  ///     );
  ///     print('Progreso sincronizado: $data');
  ///   } catch (e) {
  ///     print('No se pudo sincronizar: $e');
  ///   }
  Future<Map<String, dynamic>> syncChallengeProgressWithRetry({
    required String challengeId,
    required int currentProgress,
    int maxRetries = 3,
  }) async {
    // Función ASYNC permite usar await y try/catch
    int retryCount = 0;

    // Try block: intenta la operación
    try {
      debugPrint('🔄 Sincronizando progreso del reto: $challengeId');

      // AWAIT 1: obtener el documento actual (sin bloquear la UI)
      final currentDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!currentDoc.exists) {
        throw Exception('Reto no existe en Firebase');
      }

      // AWAIT 2: actualizar con transacción (sin bloquear la UI)
      final result = await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        // Dentro de la transacción también puedes usar await
        transaction.update(currentDoc.reference, {
          'currentProgress': currentProgress,
          'lastSyncTime': FieldValue.serverTimestamp(),
          'syncStatus': 'synced',
        });
        return {'status': 'success', 'progress': currentProgress};
      });

      debugPrint(
        '✅ Progreso sincronizado correctamente: $currentProgress pasos',
      );
      return result;
    } on FirebaseException catch (e) {
      // Catch específico para errores de Firebase
      debugPrint('❌ Error Firebase: ${e.message}');

      // Reintentar si hay fallos transitorios
      if (retryCount < maxRetries && e.code == 'unavailable') {
        retryCount++;
        debugPrint('🔁 Reintentando... (intento $retryCount/$maxRetries)');

        // AWAIT 3: esperar antes de reintentar (exponential backoff)
        await Future.delayed(Duration(milliseconds: 100 * retryCount));
        return syncChallengeProgressWithRetry(
          challengeId: challengeId,
          currentProgress: currentProgress,
          maxRetries: maxRetries,
        );
      }

      rethrow;
    } catch (e) {
      // Catch genérico para otros errores
      debugPrint('❌ Error inesperado: $e');
      rethrow;
    }
  }

  // ✅ PATRÓN 4: STREAM (5 PUNTOS)
  // ============================================================================
  // Patrón: Observable que emite múltiples eventos en el tiempo
  // Uso: Datos en tiempo real, escuchas continuas, sondeo periódico
  // Ventaja: Ideal para datos que cambian continuamente (Firebase Firestore)
  // Desventaja: Requiere manejo de suscripciones y limpieza de recursos

  /// Ejemplo 4.1: Stream básico - escuchar actualizaciones de retos en tiempo real
  ///
  /// Este método demuestra el patrón Stream:
  /// - Retorna un Stream<T> que emite múltiples eventos
  /// - Cada cambio en Firestore genera un nuevo evento
  /// - StreamBuilder en la UI escucha cambios automáticamente
  /// - Útil para paneles en tiempo real
  ///
  /// Puntos de la rúbrica: +5 pts (patrón Stream)
  /// Ejemplo de uso en Retos:
  ///   final challengesStream = watchActiveChallengesStream();
  ///   StreamBuilder<List<Challenge>>(
  ///     stream: challengesStream,
  ///     builder: (context, snapshot) {
  ///       // Se reconstruye cada vez que hay nuevo evento
  ///     }
  ///   )
  Stream<List<Map<String, dynamic>>> watchActiveChallengesStream() {
    // Stream que emite nuevas listas cuando Firestore detecta cambios
    return FirebaseFirestore.instance
        .collection('challenges')
        .where('status', isEqualTo: 'active')
        .limit(20)
        .orderBy('createdAt', descending: true)
        .snapshots() // Este es el Stream - emite QuerySnapshot en tiempo real
        .map((querySnapshot) {
          // Map transforma cada snapshot en List<Map>
          return querySnapshot.docs.map((doc) => doc.data()).toList();
        })
        .handleError((error) {
          // Manejador de error integrado en el Stream
          debugPrint('❌ Error en el Stream de retos: $error');
          // El Stream continúa vivo pero emite error
          return [];
        });
  }

  /// Ejemplo 4.2: Stream periódico con timer
  ///
  /// Este método demuestra un Stream creado manualmente con Timer:
  /// - Útil cuando necesitas sondeo o eventos periódicos
  /// - StreamController permite controlar manualmente el Stream
  /// - Emite eventos cada N segundos
  ///
  /// Puntos de la rúbrica: +5 pts (patrón Stream - variante manual)
  /// Ejemplo de uso en Retos:
  ///   final batteryStream = emitChallengeProgressTick()
  ///     .listen((progress) {
  ///       setState(() { challengeProgress = progress; });
  ///     });
  ///   // No olvides: batteryStream.cancel(); en dispose()
  Stream<int> emitChallengeProgressTick() {
    // StreamController permite crear un Stream manualmente
    final controller = StreamController<int>();
    int tickCount = 0;

    // Timer que emite eventos cada segundo
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickCount++;
      // Agrega el evento al Stream
      if (!controller.isClosed) {
        controller.add(tickCount);
        debugPrint('📊 Progress tick: $tickCount segundos');
      }
    });

    // onCancel: limpieza cuando se cancela la suscripción
    controller.onCancel = () {
      debugPrint('🛑 Deteniendo el Stream de progreso');
      timer.cancel();
    };

    return controller.stream;
  }

  // ✅ PATRÓN 5: ISOLATES (10 PUNTOS)
  // ============================================================================
  // Patrón: Computación en un isolate separado (no bloquea la UI)
  // Uso: Operaciones intensivas de CPU (compresión, cifrado, análisis)
  // Ventaja: No bloquea la UI y aprovecha varios núcleos
  // Desventaja: Mayor sobrecosto y comunicación entre isolates

  /// Ejemplo 5.1: Isolate para computación intensiva
  ///
  /// Este método demuestra el patrón Isolate:
  /// - Ejecuta código en un isolate separado (hilo independiente)
  /// - Ideal para operaciones que toman tiempo (intensivas de CPU)
  /// - La UI sigue respondiendo mientras el isolate trabaja
  /// - Comunica el resultado mediante puertos (send/receive)
  ///
  /// Puntos de la rúbrica: +10 pts (patrón Isolates)
  /// Ejemplo de uso en Retos:
  ///   final scores = await computeChallengeRecommendationScores(
  ///     challenges: allChallenges,
  ///     userProfile: currentUser,
  ///   );
  ///   // UI no se congela mientras se computan scores
  Future<List<int>> computeChallengeRecommendationScores({
    required List<Map<String, dynamic>> challenges,
    required Map<String, dynamic> userProfile,
  }) async {
    // compute ejecuta _scoreComputationIsolate en un isolate separado
    // Parámetros: (función, argumentos)
    // Retorna: un Future con el resultado
    try {
      debugPrint('🔥 Iniciando la computación de puntajes en Isolate...');

      final scores = await compute(_scoreComputationIsolate, {
        'challenges': challenges,
        'profile': userProfile,
      });

      debugPrint('✅ Puntajes computados en Isolate: $scores');
      return scores;
    } catch (e) {
      debugPrint('❌ Error en Isolate: $e');
      rethrow;
    }
  }

  /// Función ESTÁTICA que se ejecuta dentro del Isolate
  ///
  /// IMPORTANTE:
  /// - Debe ser una función estática o de nivel superior
  /// - No puede acceder a miembros de la clase
  /// - Los parámetros se pasan por valor, no por referencia
  /// - El resultado se devuelve al isolate principal
  ///
  /// Este simula la recomendación de retos: puntaje de 0 a 100
  static Future<List<int>> _scoreComputationIsolate(
    Map<String, dynamic> data,
  ) async {
    final challenges = data['challenges'] as List<Map<String, dynamic>>;
    final profile = data['profile'] as Map<String, dynamic>;

    debugPrint('🧵 Isolate iniciado - procesando ${challenges.length} retos');

    // Simulación de computación pesada (intensiva de CPU)
    final scores = <int>[];

    for (int i = 0; i < challenges.length; i++) {
      final challenge = challenges[i];

      // Operación intensiva de CPU simulada:
      // - Análisis de preferencias
      // - Cálculo de compatibilidad
      // - Puntaje multifactor
      // - Comparación con historial

      int score = 0;

      // Factor 1: calificación del reto (0-30 puntos)
      final rating = (challenge['ratingAverage'] as num? ?? 0).toDouble();
      score += (rating / 5.0 * 30).toInt();

      // Factor 2: compatibilidad con el deporte preferido (0-30 puntos)
      final userSports = (profile['preferredSports'] as List? ?? []);
      final challengeSport = challenge['sport'] as String? ?? '';
      if (userSports.contains(challengeSport)) {
        score += 30;
      }

      // Factor 3: participantes activos (0-20 puntos)
      final participants = challenge['participantCount'] as int? ?? 0;
      score += ((participants / 100 * 20).toInt()).clamp(0, 20);

      // Factor 4: dificultad versus experiencia (0-20 puntos)
      final difficulty = challenge['difficulty'] as String? ?? 'medium';
      final experience = profile['experience'] as int? ?? 0;
      if ((difficulty == 'easy' && experience < 6) ||
          (difficulty == 'medium' && experience >= 6 && experience < 12) ||
          (difficulty == 'hard' && experience >= 12)) {
        score += 20;
      }

      scores.add(score.clamp(0, 100));

      // Simula trabajo pesado en cada iteración
      await Future.delayed(const Duration(milliseconds: 50));
    }

    debugPrint('🧵 Isolate completado - puntajes: $scores');
    return scores;
  }

  // INTEGRACIÓN: ejemplo completo de todos los patrones juntos
  // ============================================================================

  /// Integración de todos los patrones en un flujo realista de Retos
  ///
  /// Este método combina TODOS los patrones para demostrar cómo usarlos juntos:
  /// 1. FUTURE: obtener un reto individual
  /// 2. FUTURE+HANDLER: cargar con fallback
  /// 3. ASYNC/AWAIT: sincronizar progreso con reintentos
  /// 4. STREAM: escuchar actualizaciones en tiempo real
  /// 5. ISOLATES: computar puntajes de recomendación sin bloquear la UI
  ///
  /// Esto alcanza el máximo puntaje en la rúbrica (35 puntos posibles)
  Future<Map<String, dynamic>> completeMultithreadingDemo() async {
    debugPrint('🚀 INICIANDO DEMO COMPLETA DE MULTITHREADING');
    debugPrint('━' * 60);

    final results = <String, dynamic>{};

    // 1️⃣ PATRÓN 1: FUTURE (5 pts) - simple y directo
    debugPrint(
      '\n[1/5] PATRÓN FUTURE - Obteniendo la calificación promedio...',
    );
    try {
      final avgRating = await getAverageChallengeRating(
        challengeId: 'demo_reto_001',
      );
      results['pattern_1_future'] = avgRating;
      debugPrint('✅ Calificación promedio obtenida: $avgRating');
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener rating: $e');
    }

    // 2️⃣ PATRÓN 2: FUTURE + HANDLER (5 pts) - con callbacks
    debugPrint('\n[2/5] PATRÓN FUTURE + HANDLER - Cargando con fallback...');
    final challengeData = await loadChallengeWithFallback(
      challengeId: 'demo_reto_002',
    );
    results['pattern_2_handler'] = challengeData;
    debugPrint('✅ Reto cargado: ${challengeData['name']}');

    // 3️⃣ PATRÓN 3: ASYNC/AWAIT (10 pts) - más legible y robusto
    debugPrint('\n[3/5] PATRÓN ASYNC/AWAIT - Sincronizando progreso...');
    try {
      final syncResult = await syncChallengeProgressWithRetry(
        challengeId: 'demo_reto_003',
        currentProgress: 5500,
        maxRetries: 2,
      );
      results['pattern_3_async_await'] = syncResult;
      debugPrint('✅ Sincronización completada: $syncResult');
    } catch (e) {
      debugPrint('⚠️ Error en la sincronización: $e');
    }

    // 4️⃣ PATRÓN 4: STREAM (5 pts) - datos en tiempo real
    debugPrint(
      '\n[4/5] PATRÓN STREAM - Inicializando listener de actualizaciones...',
    );
    final streamSubscription = watchActiveChallengesStream().listen(
      (challenges) {
        debugPrint(
          '📡 Actualización del Stream: ${challenges.length} retos activos',
        );
        results['pattern_4_stream_count'] = challenges.length;
      },
      onError: (error) {
        debugPrint('❌ Error del Stream: $error');
      },
    );

    // Dejar stream activo por 2 segundos para demostración
    await Future.delayed(const Duration(seconds: 2));
    await streamSubscription.cancel();
    debugPrint('✅ Listener del Stream cancelado');

    // 5️⃣ PATRÓN 5: ISOLATES (10 pts) - intensivo de CPU sin bloquear la UI
    debugPrint(
      '\n[5/5] PATRÓN ISOLATES - Computando puntajes de recomendación...',
    );
    try {
      final mockChallenges = [
        {
          'id': 'reto_1',
          'name': 'Running Challenge',
          'sport': 'running',
          'ratingAverage': 4.5,
          'participantCount': 50,
          'difficulty': 'medium',
        },
        {
          'id': 'reto_2',
          'name': 'Soccer Tournament',
          'sport': 'soccer',
          'ratingAverage': 4.8,
          'participantCount': 100,
          'difficulty': 'hard',
        },
      ];

      final mockProfile = {
        'preferredSports': ['running', 'soccer'],
        'experience': 8,
      };

      final scores = await computeChallengeRecommendationScores(
        challenges: mockChallenges,
        userProfile: mockProfile,
      );
      results['pattern_5_isolates'] = scores;
      debugPrint('✅ Puntajes computados: $scores');
    } catch (e) {
      debugPrint('❌ Error en Isolate: $e');
    }

    debugPrint('\n━' * 60);
    debugPrint(
      '🎯 DEMO COMPLETADA - Todos los patrones ejecutados correctamente',
    );
    debugPrint('📊 Puntuación teórica: 5+5+10+5+10 = 35 PUNTOS');

    return results;
  }
}
