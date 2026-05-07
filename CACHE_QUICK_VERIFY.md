# VERIFICACIÓN RÁPIDA DEL CACHÉ - PASOS EXACTOS

## 🎯 VERIFICACIÓN EN 5 MINUTOS

### PASO 1: Ejecutar app con logs
```powershell
cd "C:\Users\USUARIO\StudioProjects\UniandesSport-Flutter"
flutter run -v 2>&1 | Select-String "Cache"
```

**Qué buscar en la consola:**
```
[ProfileViewModel:Cache] 🗑️ Removing old cache: https://firebasestorage...
[ProfileViewModel:Cache] ✅ Old cache removed successfully
[ProfileViewModel:Cache] 📥 Pre-caching new image: https://firebasestorage...
[ProfileViewModel:Cache] ✅ Pre-cached successfully (125000 bytes)
```

Si ves estos mensajes ✅ **El caché funciona**

---

### PASO 2: Prueba L1 (Caché en Memoria)
1. En la app, ve a **Profile**
2. Toca **"Change photo"** → Selecciona una imagen
3. Espera a que se cargue (verás el indicador)
4. **Sin cerrar la app**, navega hacia atrás y regresa a Profile
5. **Observa:** ¿La imagen aparece **instantáneamente** sin placeholder?

✅ **Si aparece sin delay** = Caché L1 funciona

---

### PASO 3: Prueba L2 (Caché en Disco)
1. Cambia otra foto en Profile
2. Espera a que termine de cargar
3. **Cierra completamente la app** (no solo minimizar)
4. **Reabre la app**
5. **Observa:** ¿La imagen carga en 1-2 segundos sin ir a internet?

✅ **Si carga rápido desde el disco** = Caché L2 funciona

---

### PASO 4: Verificar en Firebase Console

**Storage:**
```
Firebase Console 
  → Storage 
  → Busca carpeta: users/
  → Abre: users/{userId}/
  → Busca: profile_picture.jpg
  → Verifica: Tamaño < 200KB (significa que se comprimió)
```

**Firestore:**
```
Firebase Console 
  → Firestore Database 
  → Colección: users
  → Documento: {userId}
  → Campo: photoUrl
  → Verifica: Contiene URL válida (https://firebasestorage...)
```

✅ **Si ambos existen y están actualizados** = Guardado OK

---

### PASO 5: Ver tamaño del caché local (Android)

```powershell
# Ver tamaño total del caché
adb shell "du -sh /data/data/com.uniandes.sport/cache/flutter_cache/"

# Resultado esperado: algo como "12M" (12 megabytes)

# Si es > 100MB, ejecutar limpieza:
adb shell "rm -rf /data/data/com.uniandes.sport/cache/flutter_cache/"
```

---

## 📊 TABLA DE DIAGNÓSTICO

| Síntoma | L1 | L2 | Storage | Firestore |
|---------|-----|-----|---------|-----------|
| Imagen aparece lento primera vez | ❌ | ❌ | ❌ | ✅ |
| Imagen aparece rápido segunda vez | ✅ | ✅ | ✅ | ✅ |
| Imagen vieja persiste tras cambiar | ❌ | ❌ | ✅ | ✅ |
| Imagen nunca carga | ❌ | ❌ | ❌ | ❌ |
| Tamaño es 2MB (sin comprimir) | ✅ | ✅ | ❌ | ✅ |

---

## 🐛 PROBLEMAS COMUNES Y SOLUCIONES

### ❌ "Los logs no aparecen"
**Causa:** No estás filtrando bien  
**Solución:**
```powershell
# Opción 1: Buscar exactamente
flutter run -v 2>&1 | Select-String "ProfileViewModel"

# Opción 2: Sin filtro (verás todo, déjalo correr)
flutter run
# Luego toca "Change photo" y observa los logs
```

### ❌ "La imagen vieja aparece después de cambiar"
**Causa:** El caché no se limpió  
**Verificar:**
- ¿Ves el log "🗑️ Removing old cache"?
- ¿Ves "✅ Old cache removed"?

**Solución manual:**
```powershell
# Limpia todo el caché
adb shell "rm -rf /data/data/com.uniandes.sport/cache/"
flutter run
```

### ❌ "Tarda mucho en cambiar foto"
**Causa:** Posible - archivo no se comprime bien  
**Verificar:**
- En Firebase Storage, ¿el archivo es < 150KB?
- ¿Ves el log con el tamaño final?

**Solución:** Aumentar compresión en `profile_storage_service.dart`:
```dart
quality: 75,  // Cambiar de 85 a 75
```

### ❌ "Dice 'Pre-cache failed'"
**Causa:** No es crítico, la imagen se cargará de todas formas  
**Verificar:** ¿Aparece la imagen correctamente?  
**Nota:** Este error es informativo, no afecta funcionalidad

---

## ✅ CHECKLIST FINAL

- [ ] Logs muestran "🗑️ Removing" y "✅ Removed"
- [ ] Logs muestran "📥 Pre-caching" y "✅ Pre-cached"
- [ ] Imagen aparece instantáneamente al reabrir perfil (L1)
- [ ] Imagen aparece en 1-2 seg tras cerrar app (L2)
- [ ] Firebase Storage tiene archivo < 150KB
- [ ] Firestore tiene campo photoUrl actualizado
- [ ] Caché local es < 100MB

**Si todas las cajas están marcadas ✅ → CACHÉ FUNCIONA PERFECTAMENTE**

---

## 🔗 RECURSOS

- **Guía completa:** CACHE_VERIFICATION_GUIDE.md
- **Script auto:** cache_verify.ps1
- **Logs en tiempo real:**
  ```powershell
  flutter run | findstr "Cache"
  ```


