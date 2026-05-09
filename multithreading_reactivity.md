# Implementación de Multithreading y Reactividad en UniandesSport

Este documento detalla las implementaciones realizadas para optimizar el rendimiento de la aplicación mediante el uso de **Isolates** (Multithreading) en la compresión de imágenes y **Streams** (Reactividad) en el motor de sincronización de datos.

## 1. Aislamiento (Isolates) para Compresión de Imagen

Procesar imágenes pesadas en el hilo principal (UI Thread) bloquea el frame rate de la aplicación, causando lo que comúnmente se conoce como *jank* (congelamientos temporales de la interfaz). Para solucionar esto, movimos el trabajo intensivo de compresión a un hilo secundario (Isolate).

### Archivos Modificados/Creados
- **`lib/features/calisthenics/viewmodels/calisthenics_viewmodel.dart`** (NUEVO)

### Implementación Detallada
Se implementó un patrón MVVM introduciendo el `CalisthenicsViewModel` (hereda de `ChangeNotifier`). 
Dentro de este archivo, se creó la siguiente función de alto nivel (top-level):
```dart
Future<Uint8List?> _compressImageTask(String imagePath) async {
  return await FlutterImageCompress.compressWithFile(
    imagePath,
    minWidth: 1024,
    minHeight: 1024,
    quality: 80,
  );
}
```
**¿Por qué usar `Isolate.run()`?**
A partir de Flutter 3.7, `Isolate.run()` simplifica inmensamente el uso de hilos secundarios. En el ViewModel, la llamada se hace así:
```dart
final compressedBytes = await Isolate.run(() => _compressImageTask(imagePath));
```
Esto genera un nuevo Isolate, ejecuta la tarea intensiva llamando al paquete nativo de compresión, retorna el `Uint8List` y luego destruye el Isolate. Todo esto ocurre en segundo plano, por lo que cualquier animación de carga (`CircularProgressIndicator`) continuará renderizándose a 60 fps sin interrupciones.

## 2. Reactividad (Streams) en el Motor de Sincronización

El `SyncEngineService` es el responsable de procesar colas de eventos en modo "Offline-First". Se optimizó para que el servicio sea "Network-Aware" de forma reactiva, mejorando la eficiencia de procesamiento y evitando el consumo innecesario de batería o CPU.

### Archivos Modificados/Creados
- **`lib/core/network/sync_engine_service.dart`** (MODIFICADO)

### Implementación Detallada
1. **Suscripción a Cambios de Red (Connectivity Stream):**
Se actualizó el método `initialize()` para suscribirse al Stream provisto por el paquete `connectivity_plus`.
```dart
void initialize() {
  _connectivitySub ??= Connectivity().onConnectivityChanged.listen((dynamic result) {
    final bool hasConn = _hasConnectionDynamic(result);
    _isConnected = hasConn;
    
    if (hasConn) {
      // Si recuperamos la conexión, activamos el procesamiento inmediatamente
      processQueue();
    }
  });
  // ...
}
```

2. **Interrupción Inmediata por Desconexión:**
Se introdujo una variable de estado global en el servicio `bool _isConnected`. 
Durante la ejecución cíclica de las tareas en `processQueue()`, se evalúa constantemente este estado. Si el teléfono pierde conexión (por ejemplo, entra a un túnel), el ciclo se rompe de inmediato:
```dart
for (final task in pending) {
  // Detener inmediatamente si se pierde la conexión
  if (!_isConnected) {
    _isProcessing = false;
    break;
  }
  // Procesamiento de la tarea...
}
```
**Ventaja Arquitectónica:** Esto evita lanzar excepciones de `SocketException` o `TimeoutException` de forma masiva cuando sabemos que la red no está disponible, ahorrando CPU y ciclos de espera inútiles. La suscripción al Stream nos asegura que el procesamiento se reanudará milisegundos después de que la red vuelva a estar disponible.

## Reglas Arquitectónicas Aplicadas
- **MVVM:** La UI delegará la manipulación de estado al `CalisthenicsViewModel`, ignorando por completo la existencia de Isolates.
- **Manejo de Errores Seguros:** Se añadieron bloques `try-catch` para capturar errores lanzados desde el Isolate o la API.
- **Prevención de Fugas de Memoria:** El StreamSubscription (`_connectivitySub`) en `SyncEngineService` está preparado para ser cancelado en el método `dispose()`.
