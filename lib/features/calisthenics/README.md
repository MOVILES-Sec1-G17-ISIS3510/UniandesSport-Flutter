# Calisthenics AI Analysis Feature

Análisis en tiempo real de ejercicios de calistenia utilizando Google Gemini 2.5-flash y almacenamiento local con Hive.

## 🚀 Quick Start

### 1. Reemplazar API Key
```dart
// lib/features/calisthenics/services/calisthenics_ai_service.dart (línea 50)
static const String _apiKey = 'tu-gemini-api-key';
```

### 2. Inicializar en main.dart
```dart
final service = CalisthenicsAIService();
await service.initialize();
```

### 3. Usar en tu código
```dart
final result = await service.analyzeExerciseImage(imageBytes);
print('${result.detectedExercise}: ${result.postureScore}/100');
```

## 📁 Estructura

```
lib/features/calisthenics/
├── models/
│   └── calisthenics_result_model.dart       # Modelo de datos
├── services/
│   └── calisthenics_ai_service.dart         # Servicio principal
└── presentation/
    └── pages/
        └── calisthenics_analysis_example.dart  # UI ejemplo
```

## 🎯 API

### CalisthenicsAIService

```dart
// Inicialización
Future<void> initialize()

// Análisis
Future<CalisthenicsResultModel> analyzeExerciseImage(List<int> imageBytes)

// Acceso a datos
CalisthenicsResultModel? getLastAnalysis()
List<CalisthenicsResultModel> getAllAnalyses()

// Limpieza
Future<void> clearAllAnalyses()
```

## 💡 Características

- ✅ Análisis de postura 0-100
- ✅ Detección automática del ejercicio
- ✅ Identificación de áreas de riesgo
- ✅ Recomendaciones personalizadas
- ✅ Ejercicios similares sugeridos
- ✅ Almacenamiento en Hive
- ✅ Manejo robusto de errores
- ✅ Reintentos automáticos en errores de red
- ✅ Timestamp de análisis

## 📊 Respuesta Ejemplo

```json
{
  "postureScore": 85,
  "postureAnalysis": "Postura correcta. Los brazos están alineados...",
  "feedback": "Buen esfuerzo. Mantén el core activado...",
  "recommendations": [
    "Practica planks",
    "Realiza ejercicios de movilidad",
    "Intenta variaciones más difíciles"
  ],
  "similarExercises": [
    "Push-up inclinado",
    "Diamond push-up"
  ],
  "detectedExercise": "Push-up",
  "riskAreas": ["Espalda baja", "Hombros"],
  "tips": [
    "Contrae el abdomen antes de bajar",
    "Los codos cerca del cuerpo",
    "Baja lentamente"
  ],
  "analyzedAt": "2026-05-07T12:30:45.123Z"
}
```

## 🛡️ Manejo de Errores

```dart
try {
  final result = await service.analyzeExerciseImage(bytes);
} on CalisthenicsAIServiceException catch (e) {
  if (e.isNetworkError) {
    // Reintentar automáticamente
  } else {
    // Error no recuperable
  }
}
```

## 📖 Documentación

- `docs/calisthenics_ai_service.md` - Manual completo
- `docs/CALISTHENICS_IMPLEMENTATION_GUIDE.md` - Integración
- `docs/CALISTHENICS_PROMPT_DETAILS.md` - Técnica de prompts
- `docs/CALISTHENICS_CHECKLIST.md` - Checklist de implementación

## 🔧 Configuración

### Permisos (Android)
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
```

### Permisos (iOS)
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Analizamos tu forma de ejercitarse.</string>
```

### Generar Código Hive
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 💻 Ejemplo de Integración MVVM

```dart
class CalisthenicsViewModel extends ChangeNotifier {
  final CalisthenicsAIService _service = CalisthenicsAIService();
  
  bool isAnalyzing = false;
  CalisthenicsResultModel? result;
  String? error;
  
  Future<void> analyzeImage(List<int> bytes) async {
    isAnalyzing = true;
    notifyListeners();
    
    try {
      result = await _service.analyzeExerciseImage(bytes);
      error = null;
    } on CalisthenicsAIServiceException catch (e) {
      error = e.message;
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }
}
```

## 🚀 Deployment

### Pre-producción
- [ ] Reemplazar API key con variable de entorno
- [ ] Testar en dispositivo real
- [ ] Verificar permisos de cámara
- [ ] Pruebas de conexión lenta/offline

### Producción
- [ ] API key en Firebase Remote Config
- [ ] Monitoreo de errores en Sentry/Firebase Crashlytics
- [ ] Rate limiting si es necesario
- [ ] Analytics de uso

## 🐛 Troubleshooting

| Problema | Solución |
|----------|----------|
| "Empty response from Gemini" | Verificar imagen, conexión, API key |
| "Invalid JSON response" | Revisar systemInstruction, aumentar temperatura |
| "Timeout after 30 seconds" | Comprimir imagen, verificar internet |
| "Network error" | Reintentar automáticamente (ya implementado) |
| "API key invalid" | Generar nueva en https://aistudio.google.com |

## 📞 Soporte

Revisa los logs en debug mode:
```
[CalisthenicsAIService] Starting exercise analysis
[CalisthenicsAIService] Image saved to: /tmp/exercise_xxx.jpg
[CalisthenicsAIService] Sending request to Gemini 2.5-flash...
```

## 📜 Licencia

Este código es parte del proyecto UniandesSport Flutter.

## 👨‍💻 Autor

Generado por GitHub Copilot - 7 Mayo 2026

