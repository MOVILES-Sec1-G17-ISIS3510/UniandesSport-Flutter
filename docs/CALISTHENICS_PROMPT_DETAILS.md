# Detalles del Prompt de Sistema para Análisis de Calistenia

## Prompt Actual

El servicio utiliza el siguiente `systemInstruction` para Gemini:

```
Eres el motor de análisis de ejercicios de calistenia para UniandesSport. Tu única tarea es analizar una imagen de una persona realizando un ejercicio de calistenia y proporcionar retroalimentación detallada.

REGLAS CRÍTICAS:
1. Identifica el ejercicio específico (ej: push-up, pull-up, dips, handstand, etc.)
2. Evalúa la postura en escala 0-100 basado en:
   - Alineación del cuerpo
   - Posición de las articulaciones
   - Distribución del peso
   - Simetría y balance
3. Identifica áreas de riesgo de lesión
4. Proporciona consejos prácticos y específicos
5. Sugiere ejercicios similares para progresión
6. Devuelve ÚNICAMENTE un JSON válido sin explicaciones adicionales

FORMATO DE RESPUESTA (OBLIGATORIO):
{
  "postureScore": <número 0-100>,
  "postureAnalysis": "<descripción detallada de la postura observada>",
  "feedback": "<retroalimentación principal sobre la ejecución>",
  "recommendations": ["<recomendación 1>", "<recomendación 2>", "<recomendación 3>"],
  "similarExercises": ["<ejercicio similar 1>", "<ejercicio similar 2>"],
  "detectedExercise": "<nombre del ejercicio>",
  "riskAreas": ["<área de riesgo 1>", "<área de riesgo 2>"],
  "tips": ["<tip práctico 1>", "<tip práctico 2>", "<tip práctico 3>"]
}

Todos los campos son obligatorios. Los arrays deben tener al menos 2 elementos.
```

## Configuración de Generación

```dart
GenerationConfig(
  responseMimeType: 'application/json',  // Fuerza respuesta JSON
  temperature: 0.1,                       // Baja variabilidad
)
```

### Por qué estos parámetros:

1. **responseMimeType = 'application/json'**
   - Obliga a Gemini a responder siempre en formato JSON
   - Reduce significativamente los errores de parsing
   - Gemini optimiza su respuesta para este formato

2. **temperature = 0.1**
   - Temperatura muy baja = respuestas consistentes
   - Ideal para análisis técnicos
   - Evita variabilidad innecesaria
   - Range: 0 (determinístico) a 2 (muy creativo)

## Timeouts

```dart
.timeout(const Duration(seconds: 30))
```

- **30 segundos**: Tiempo razonable para análisis de imagen
- Si se excede: Se lanza `TimeoutException` → se marca como `isNetworkError=true`
- Permitiendo reintentos automáticos

## Prompt en Tiempo de Llamada

Cuando se envía la imagen junto con el análisis:

```dart
final prompt = TextPart(
  'Analiza esta imagen de un ejercicio de calistenia. Identifica el ejercicio, evalúa la postura y proporciona retroalimentación detallada.',
);
```

### Estructura de la Solicitud

```
SystemInstruction (global)
↓
[Prompt + DataPart(image)]
↓
GenerativeModel.generateContent()
↓
JSON Response
```

## Optimizaciones para Mejor Rendimiento

### 1. Reducir Tamaño de Imagen
Si necesitas mejorar velocidad, puedes comprimir:

```dart
// Agregar a CalisthenicsAIService si es necesario
Future<List<int>> _compressImage(List<int> imageBytes) async {
  // Usar flutter_image_compress que ya está en pubspec.yaml
  final compressed = await FlutterImageCompress.compressWithList(
    imageBytes,
    minHeight: 640,
    minWidth: 480,
    quality: 85,
  );
  return compressed;
}
```

### 2. Cachear Prompts de Sistema
Ya lo hacemos con `late final`:
```dart
late final GenerativeModel _model = GenerativeModel(...);
```
Se crea una única vez, eficiente.

### 3. Manejo de Memoria
- Las imágenes se guardan en directorio temporal
- Se limpian automáticamente por el SO
- Hive mantiene referencia a resultados (no bytes)

## Criterios de Evaluación de Postura

El prompt instruye a Gemini a evaluar:

### 1. Alineación del Cuerpo
- Columna vertebral recta/neutral
- Cadera alineada con hombros
- Cabeza en posición neutra

### 2. Posición de Articulaciones
- Codos: Ángulo correcto para el ejercicio
- Rodillas: No deben bloquear excesivamente
- Muñecas: Neutras y sin tensión
- Hombros: Correctamente retractados/deprimidos

### 3. Distribución del Peso
- Peso distribuido uniformemente
- Sin compensaciones laterales
- Estabilidad general

### 4. Simetría y Balance
- Movimiento simétrico ambos lados
- Sin rotación de cadera
- Control total del movimiento

## Ejercicios Detectables

El modelo debería poder identificar:

### Movimientos Básicos
- Push-ups (estándar, inclinado, diamante)
- Pull-ups
- Dips
- Handstands
- Planks (estándar, lado, dinámico)
- Squats (pistol, búlgaro, sissy)
- Lunges
- Burpees
- Mountain climbers

### Movimientos Avanzados
- L-sits
- Front levers (progresiones)
- Back levers (progresiones)
- Muscle-ups
- Handstand push-ups
- Human flags

## Ejemplo de Análisis Real

### Input
- Imagen JPEG de persona haciendo push-up

### Output Esperado
```json
{
  "postureScore": 78,
  "postureAnalysis": "La postura es generalmente buena. La espalda está recta y la cadera alineada con los hombros. Sin embargo, los codos están ligeramente más separados del cuerpo de lo ideal, lo cual distribuye menos eficientemente la carga.",
  "feedback": "Muy bien ejecutado. Acerca un poco los codos al cuerpo para una mejor distribución de la fuerza y mejor seguridad de los hombros.",
  "recommendations": [
    "Practica con codos más cercanos al cuerpo",
    "Realiza rotaciones de hombros para mejorar movilidad",
    "Intenta progresiones: diamond push-ups o archer push-ups"
  ],
  "similarExercises": [
    "Diamond push-up (más enfoque en tríceps)",
    "Pseudo planche push-up (más desafiante)"
  ],
  "detectedExercise": "Push-up",
  "riskAreas": [
    "Hombros (si mantiene codos muy alejados)",
    "Espalda baja (si pierde alineación lumbar)"
  ],
  "tips": [
    "Los codos deben formar un ángulo de 45 grados respecto al cuerpo",
    "Baja lentamente y controla la bajada",
    "Mantén el core activado durante todo el movimiento"
  ]
}
```

## Casos Especiales

### 1. Imagen No Detecta Ejercicio de Calistenia
Gemini debería responder con:
```json
{
  "postureScore": 0,
  "postureAnalysis": "No se detectó un ejercicio de calistenia válido en la imagen",
  "feedback": "Por favor carga una imagen clara de una persona realizando un ejercicio de calistenia",
  "detectedExercise": "No detectado",
  // ... arrays vacíos o con valores por defecto
}
```

### 2. Imagen Borrosa o de Baja Calidad
- Gemini intentará analizar lo mejor posible
- El postureScore será más bajo
- Se incluirá nota sobre calidad en feedback

### 3. Múltiples Personas
- Gemini analizará la persona más clara
- En feedback puede mencionar presencia de múltiples personas

## Seguridad y Privacidad

### Datos Enviados a Google
- Solo bytes JPEG de la imagen
- No se envía metadata de usuario
- No se almacenan en servidores de Google (por defecto)

### Datos Locales
- Imágenes: Directorio temporal (se borran automáticamente)
- Resultados: Hive (base de datos local, no sincroniza)
- Histórico: Solo en dispositivo

## Mejoras Futuras Posibles

### 1. Multi-Frame Analysis
Analizar vídeo frame-by-frame para detectar compensaciones durante movimiento:
```dart
Future<List<CalisthenicsResultModel>> analyzeVideoFrames(String videoPath)
```

### 2. Comparación Histórica
Comparar postura vs análisis anterior:
```dart
Future<ProgressAnalysis> compareWithPrevious(CalisthenicsResultModel current)
```

### 3. Planes de Progresión
Generar plan de 4 semanas basado en score:
```dart
Future<ProgressionPlan> generateProgressionPlan(int baseScore)
```

### 4. Integración con Firebase
Sincronizar análisis a backend para:
- Leaderboards
- Trazabilidad longitudinal
- Recomendaciones personalizadas

## Troubleshooting

### "Empty response from Gemini"
- Verifica que la imagen tenga contenido
- Asegúrate de tener conexión
- Intenta con otra imagen

### "Invalid JSON response"
- El modelo devolvió texto no JSON
- Revisa el systemInstruction
- Aumenta ligeramente la temperatura si es muy restrictivo

### "Timeout after 30 seconds"
- La imagen es muy grande
- Considera comprimir antes de enviar
- Verifica velocidad de conexión

### "Network error: Socket exception"
- Sin conexión a internet
- Reintentar automáticamente (ya implementado)
- Mostrar UI offline

---

**Última actualización**: 7 Mayo 2026
**Versión de Gemini**: 2.5-flash
**Estado**: Production Ready ✅

