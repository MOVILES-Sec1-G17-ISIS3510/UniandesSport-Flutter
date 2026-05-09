# Cache Verification Guide - Profile Picture

Esta guía te ayuda a verificar que el caching L1/L2 (`cached_network_image` + `flutter_cache_manager`) está funcionando correctamente.

## 1. VERIFICACIÓN EN TIEMPO REAL (Console Logs)

### A. Habilitar Debug Logging

Añade este código al `ProfileViewModel` para ver logs de caché:

```dart
// En profile_viewmodel.dart, en el método changeProfilePicture, después de actualizar:

debugPrint('[ProfileViewModel] Cache: Old URL = $oldUrl');
debugPrint('[ProfileViewModel] Cache: New URL = $downloadUrl');
debugPrint('[ProfileViewModel] Cache: Cleaning old cache...');
debugPrint('[ProfileViewModel] Cache: Pre-caching new image...');
```

### B. Ejecutar con Logs Detallados

```bash
cd "C:\Users\USUARIO\StudioProjects\UniandesSport-Flutter"
flutter run -v 2>&1 | grep -i cache
```

**Qué buscar en los logs:**
```
[ProfileViewModel] Cache: Old URL = https://firebasestorage.googleapis.com/...
[ProfileViewModel] Cache: New URL = https://firebasestorage.googleapis.com/...
[ProfileViewModel] Cache: Cleaning old cache...
[ProfileViewModel] Cache: Pre-caching new image...
```

---

## 2. VERIFICACIÓN EN DISCO LOCAL

### Ubicación de archivos en caché (por plataforma):

**Android:**
```
/data/data/com.uniandes.sport/cache/flutter_cache/
```

**iOS:**
```
~/Library/Caches/flutter_cache/
```

**Windows (Emulador Android):**
```
Usa adb para acceder:
adb shell "ls -la /data/data/com.uniandes.sport/cache/flutter_cache/"
```

### Verificar con ADB (Android Device Bridge):

```bash
# Conectar dispositivo/emulador
adb devices

# Listar archivos en caché
adb shell "ls -lh /data/data/com.uniandes.sport/cache/flutter_cache/"

# Ver tamaño total del caché
adb shell "du -sh /data/data/com.uniandes.sport/cache/flutter_cache/"

# Descargar caché a local para inspeccionar
adb pull /data/data/com.uniandes.sport/cache/flutter_cache/ ./profile_cache_backup/
```

---

## 3. PRUEBA MANUAL EN LA APP

### Test Case 1: Verificar Carga Inicial

1. **Abre la app** y navega a la pantalla de perfil
2. **Observa:**
   - ¿Aparece placeholder mientras se carga la imagen?
   - ¿Se muestra la imagen correctamente?
   - ¿Cuánto tiempo tarda?

**Logs esperados:**
```
flutter: [ProfileViewModel] Initializing profile...
flutter: I/OpenGLRenderer: Loaded glGetString(GL_RENDERER) =
```

### Test Case 2: Cambiar Foto de Perfil

1. **Toca el botón "Change photo"**
2. **Selecciona "Take a photo"** o **"Choose from gallery"**
3. **Observa la barra de progreso** en el avatar

**Logs esperados:**
```
flutter: [ProfileViewModel] Cache: Old URL = ...
flutter: [ProfileViewModel] Cache: Cleaning old cache...
flutter: [ProfileViewModel] Cache: Pre-caching new image...
flutter: Profile picture updated successfully
```

### Test Case 3: Verificar Caché L1 (En Memoria)

1. **Después de cambiar la foto**, cierra y **reabre inmediatamente** la pantalla de perfil
2. **Observa:**
   - ¿La imagen se muestra instantáneamente (sin placeholder)?
   - ¿NO hace request a Firebase Storage?

**Indicador:** Si aparece sin delay y sin placeholder, **el caché L1 funciona**.

### Test Case 4: Verificar Caché L2 (Disco)

1. **Después de cambiar la foto**, cierra completamente la app (fuerza cierre)
2. **Abre la app nuevamente** y navega a perfil
3. **Observa:**
   - ¿La imagen se muestra rápidamente (1-2 segundos)?
   - ¿Sin placeholder o con placeholder muy breve?

**Indicador:** Si carga rápido desde disco sin ir a la red, **el caché L2 funciona**.

---

## 4. MONITOREO CON DevTools

### Opción A: Flutter DevTools (Recomendado)

```bash
# Ejecutar app con DevTools activado
flutter run --devtools

# O iniciar DevTools por separado
flutter pub global run devtools

# Acceder en browser: http://localhost:9100
```

**En DevTools, busca:**
- **Memory tab:** Observa uso de memoria cuando cambias foto
- **Network tab:** Ve peticiones HTTP a Firebase Storage

### Opción B: Logcat (Android)

```bash
# Filtrar logs específicos de caché
adb logcat | grep -E "flutter|cache|network"

# Ver todos los logs y guardar en archivo
adb logcat > logcat_output.txt
```

---

## 5. VALIDACIÓN TÉCNICA (Firebase + Código)

### A. Confirmar URL en Firestore

```bash
# Con Firebase CLI
firebase firestore:get users/{userId}

# Verifica que el campo 'photoUrl' contenga una URL válida y nueva
```

### B. Confirmar Archivo en Storage

```bash
# Con Firebase CLI o Console
firebase storage:ls gs://proyecto.appspot.com/users/{userId}/

# Debería mostrar: profile_picture.jpg con tamaño < 200KB (comprimida)
```

### C. Verificar Clave de Caché en Código

```dart
// En profile_avatar.dart, el cacheKey es:
final cacheKey = userId != null && userId!.isNotEmpty
    ? 'profile_avatar_user_$userId'  // ← Se usa userId como parte de la clave
    : 'profile_avatar_${Uri.parse(photoUrl!).pathSegments.last}';
```

**Esto significa:**
- Cada usuario tiene su propia clave de caché única
- Al cambiar de usuario, automáticamente se usa caché distinto
- Evita conflictos entre usuarios

---

## 6. CASOS DE FALLO Y SOLUCIONES

| Problema | Causa Probable | Solución |
|----------|---|---|
| Imagen vieja después de cambiar | Caché no se limpió | Ejecutar `DefaultCacheManager().removeFile(oldUrl)` |
| Imagen nunca carga | URL incorrecta o red sin conexión | Verificar URL en Firestore y conexión internet |
| Placeholder infinito | Timeout o URL rota | Aumentar timeout en `CachedNetworkImage` |
| Memoria crece indefinidamente | Caché L1 no limitado | `CachedNetworkImage` limita automáticamente a 100MB por defecto |
| Caché muy grande en disco | Muchas imágenes acumuladas | Ejecutar: `DefaultCacheManager().emptyCache()` |

---

## 7. LIMPIEZA MANUAL DE CACHÉ

### Desde la App (Agregar botón de debug):

```dart
// En settings o perfil, agregar botón:
ElevatedButton(
  onPressed: () async {
    await DefaultCacheManager().emptyCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared')),
    );
  },
  child: const Text('Clear Cache'),
)
```

### Desde Terminal:

```bash
# Android
adb shell "rm -rf /data/data/com.uniandes.sport/cache/flutter_cache/"

# O desinstalar la app completa (borra todo caché)
adb uninstall com.uniandes.sport
flutter run
```

---

## 8. MÉTRICAS DE ÉXITO

✅ **Caché funciona correctamente si:**

1. **L1 (Memoria):** Imagen se muestra instantáneamente al reabrir pantalla
2. **L2 (Disco):** Imagen carga en < 2 segundos tras cerrar app
3. **Limpieza:** Al cambiar foto, la vieja se elimina de caché
4. **Tamaño:** Foto comprimida es < 150KB
5. **Firebase Storage:** Archivo existe en `users/{userId}/profile_picture.jpg`
6. **Firestore:** Campo `photoUrl` contiene URL válida y actualizada

---

## 9. COMANDO RÁPIDO PARA VERIFICACIÓN COMPLETA

```bash
# Script que verifica todo de una vez:

echo "=== CACHE VERIFICATION REPORT ==="
echo ""
echo "1. Firebase Storage:"
firebase storage:ls gs://proyecto.appspot.com/users/ 2>/dev/null || echo "Requiere firebase CLI"
echo ""
echo "2. Local Cache (Android):"
adb shell "du -sh /data/data/com.uniandes.sport/cache/flutter_cache/" 2>/dev/null || echo "Requiere device conectado"
echo ""
echo "3. Flutter Logs (últimas 10 líneas):"
adb logcat -n 10 2>/dev/null | grep -E "ProfileViewModel|cache" || echo "Requiere device conectado"
```

---

## 10. PREGUNTAS FRECUENTES

**P: ¿Cada cuánto se recarga la imagen?**
R: Una vez en caché, se usa indefinidamente. Se recarga solo si llamas a `DefaultCacheManager().removeFile(url)`.

**P: ¿Cómo fuerzo a descargar la imagen nuevamente?**
R: Ejecuta `DefaultCacheManager().removeFile(cachedUrl);` y luego navega nuevamente.

**P: ¿Puedo ver el caché en Firebase Console?**
R: **Sí**, en Storage → carpeta `users/` → archivo `profile_picture.jpg`.

**P: ¿Qué pasa si el usuario cambia de teléfono?**
R: El caché L2 (disco) se pierde. Se descargará de Firebase Storage automáticamente.


