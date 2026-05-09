# Servicio de IA para Análisis de Calistenia

## Descripción General

El `CalisthenicsAIService` es un servicio singleton que utiliza Google Gemini 2.5-flash para analizar imágenes de ejercicios de calistenia y proporcionar retroalimentación detallada sobre la postura.

## Flujo de Análisis

1. **Captura de Imagen**: La cámara captura bytes de imagen JPEG
2. **Almacenamiento Local**: La imagen se guarda en el directorio temporal de la app (`getTemporaryDirectory()`)
3. **Análisis con IA**: Se envía a Gemini 2.5-flash con sistema de instrucciones específico
4. **Parseo JSON**: La respuesta se parsea y estructura en `CalisthenicsResultModel`
5. **Persistencia**: El resultado se almacena en Hive con timestamp del análisis
6. **Gestión de Errores**: Si hay error de conexión, se lanza `CalisthenicsAIServiceException` con `isNetworkError=true`

## Configuración de API Key

**Importante**: Reemplaza `'YOUR_API_KEY_HERE'` con tu clave de API de Google Gemini.

```dart
static const String _apiKey = 'YOUR_API_KEY_HERE';
```

La clave debe ser válida y tener permisos para usar:
- Google Generative AI (Gemini)
- Procesamiento de imágenes
- Modelo: `gemini-2.5-flash`

## Estructura del Prompt de IA

El servicio utiliza un `systemInstruction` predefinido que:

### Reglas Principales
1. **Identificación del Ejercicio**: Detecta automáticamente el tipo de ejercicio (push-up, pull-up, dips, handstand, etc.)
2. **Evaluación de Postura**: Califica la postura en escala 0-100 considerando:
   - Alineación del cuerpo
   - Posición de las articulaciones
   - Distribución del peso
   - Simetría y balance
3. **Detección de Riesgos**: Identifica áreas vulnerables a lesiones
4. **Retroalimentación**: Proporciona consejos prácticos y específicos
5. **Progresión**: Sugiere ejercicios similares para progresar
6. **Respuesta Estructurada**: Devuelve solo JSON válido sin explicaciones adicionales

### Formato de Respuesta Esperada

```json
{
  "postureScore": 85,
  "postureAnalysis": "Tu posición es bastante correcta. Los brazos están alineados, pero la espalda podría estar un poco más recta.",
  "feedback": "Buen esfuerzo. Mantén el core más activado para evitar que la espalda se doble.",
  "recommendations": [
    "Practica planks para fortalecer el core",
    "Realiza ejercicios de movilidad de hombros",
    "Mantén una respiración constante durante el ejercicio"
  ],
  "similarExercises": [
    "Push-up inclinado (más fácil)",
    "Diamond push-up (más difícil)"
  ],
  "detectedExercise": "Push-up estándar",
  "riskAreas": [
    "Espalda baja (por no activar core)",
    "Hombros (por falta de movilidad)"
  ],
  "tips": [
    "Contrae el abdomen antes de bajar",
    "Los codos deben estar cercanos al cuerpo",
    "Baja hasta que tu pecho casi toque el suelo"
  ]
}
```

## API del Servicio

### Inicialización

```dart
final service = CalisthenicsAIService();
await service.initialize(); // Abre la caja de Hive
```

### Análisis de Imagen

```dart
try {
  final List<int> imageBytes = ...; // Bytes de la imagen capturada
  final result = await service.analyzeExerciseImage(imageBytes);
  
  print(result.detectedExercise);
  print(result.postureScore);
  print(result.feedback);
} on CalisthenicsAIServiceException catch (e) {
  if (e.isNetworkError) {
    // Error de conexión: permite reintentos
    print('Error de red: ${e.message}');
  } else {
    // Error no relacionado con red: podría ser fallo de JSON parsing
    print('Error: ${e.message}');
  }
}
```

### Obtener Análisis Guardados

```dart
// Último análisis
final last = service.getLastAnalysis();

// Todos los análisis
final all = service.getAllAnalyses();

// Limpiar todo
await service.clearAllAnalyses();
```

## Manejo de Errores

La excepción `CalisthenicsAIServiceException` tiene dos categorías:

### Errores de Red (isNetworkError = true)
- `SocketException`: Problemas de conectividad
- `TimeoutException`: La solicitud tardó demasiado (> 30 segundos)
- Otros errores de red

**Acción Recomendada**: Permitir reintentos automáticos

### Errores No-Red (isNetworkError = false)
- JSON inválido en la respuesta de Gemini
- Imagen no guardada localmente
- Errores de Hive
- Respuesta vacía de Gemini

**Acción Recomendada**: Notificar al usuario y registrar el error

## Configuración de Generación

```dart
GenerationConfig(
  responseMimeType: 'application/json',  // Fuerza respuesta en JSON
  temperature: 0.1,                       // Baja temperatura para respuestas consistentes
)
```

## Almacenamiento Local

### Imágenes
- Ubicación: Directorio temporal de la app (`getTemporaryDirectory()`)
- Nombre: `exercise_<timestamp>.jpg`
- Se guardan automáticamente durante el análisis

### Resultados de Análisis
- Almacén: Hive Box (`calisthenics_results`)
- Clave: Timestamp en milisegundos desde época (ms)
- Modelo: `CalisthenicsResultModel` con timestamp del análisis

## Ejemplo de Uso Completo

```dart
class CalisthenicsAnalysisScreen extends StatefulWidget {
  @override
  State<CalisthenicsAnalysisScreen> createState() =>
      _CalisthenicsAnalysisScreenState();
}

class _CalisthenicsAnalysisScreenState extends State<CalisthenicsAnalysisScreen> {
  final CalisthenicsAIService _service = CalisthenicsAIService();
  bool _isAnalyzing = false;
  String? _error;
  CalisthenicsResultModel? _result;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _service.initialize();
    } catch (e) {
      setState(() => _error = 'Error initializing service: $e');
    }
  }

  Future<void> _analyzeImage(List<int> imageBytes) async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final result = await _service.analyzeExerciseImage(imageBytes);
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    } on CalisthenicsAIServiceException catch (e) {
      setState(() {
        _isAnalyzing = false;
        if (e.isNetworkError) {
          _error = 'Connection error. Please check your internet and try again.';
        } else {
          _error = 'Analysis failed: ${e.message}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(_error!),
            ),
            const SizedBox(height: 16),
          ],
          if (_isAnalyzing)
            const Center(child: CircularProgressIndicator())
          else if (_result != null) ...[
            _buildResultCard(_result!),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                // Capturar imagen de cámara y llamar a _analyzeImage
              },
              child: const Text('Analyze Exercise'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(CalisthenicsResultModel result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.detectedExercise,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Posture Score: ${result.postureScore}/100'),
        const SizedBox(height: 16),
        Text(result.feedback),
        const SizedBox(height: 16),
        Text('Tips:', style: Theme.of(context).textTheme.titleSmall),
        ...result.tips.map((tip) => Text('• $tip')),
      ],
    );
  }
}
```

## Notas Importantes

1. **Timeout**: Las solicitudes tienen un timeout de 30 segundos
2. **API Key**: Mantén la clave segura y no la expongas en código público
3. **Persistencia**: Los resultados se guardan automáticamente con timestamp
4. **Singleton**: Solo existe una instancia del servicio en la app
5. **Reintentos**: Implementa lógica de reintentos para errores de red
6. **Temperatura Baja**: La temperatura de 0.1 asegura respuestas consistentes y predecibles

