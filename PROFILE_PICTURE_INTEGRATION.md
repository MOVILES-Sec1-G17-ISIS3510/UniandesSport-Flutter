"""
INTEGRACIÓN DE LA FUNCIONALIDAD DE EDICIÓN DE FOTO DE PERFIL
==============================================================

Arquitectura MVVM Feature-First (Ubicación: lib/features/profile/)

## 1. DEPENDENCIAS INSTALADAS

Asegúrate de que estos paquetes están en pubspec.yaml:
- image_picker: ^1.1.2 (ya instalado)
- cached_network_image: ^3.3.1 (AÑADIDO)
- flutter_image_compress: ^1.2.1 (AÑADIDO)
- firebase_storage: ^12.3.7 (ya instalado)

Para instalar: flutter pub get

## 2. ESTRUCTURA DE ARCHIVOS

lib/features/profile/
├── viewmodels/
│   └── profile_viewmodel.dart (CREADO)
├── services/
│   ├── profile_storage_service.dart (CREADO)
│   └── profile_repository.dart (CREADO)
├── widgets/
│   ├── profile_avatar.dart (CREADO)
│   └── profile_picture_dialog.dart (CREADO)
└── views/
    └── profile_page.dart (CREADO)

## 3. FLUJO ARQUITECTÓNICO

┌─────────────────────────────────────────────────────────┐
│                    UI (Flutter Widget)                   │
│              - ProfilePage (StatefulWidget)              │
│              - ProfileAvatar (CachedNetworkImage)        │
│              - ProfilePictureDialog / BottomSheet        │
└─────────────────┬───────────────────────────────────────┘
                  │ notifyListeners() ↓ watch
                  │
┌─────────────────────────────────────────────────────────┐
│           ViewModel (ChangeNotifier)                     │
│      ProfileViewModel: Orquesta el flujo completo        │
│      - changeProfilePicture(source, userId)             │
│      - Maneja: carga, errores, estado del perfil       │
└─────────────────┬───────────────────────────────────────┘
                  │ llamadas async
                  │
┌─────────────────────────────────────────────────────────┐
│                 Servicios (Lógica)                       │
│   ┌────────────────────────────────────────────────┐    │
│   │ ProfileStorageService                         │    │
│   ├─ uploadProfilePicture(file, userId)           │    │
│   │  → Comprime con flutter_image_compress        │    │
│   │  → Sube a Firebase Storage                    │    │
│   │  → Retorna downloadURL                        │    │
│   └────────────────────────────────────────────────┘    │
│                                                         │
│   ┌────────────────────────────────────────────────┐    │
│   │ ProfileRepository                             │    │
│   ├─ updateProfilePicture(userId, photoUrl)       │    │
│   │  → Actualiza Firestore: /users/{uid}          │    │
│   └────────────────────────────────────────────────┘    │
└─────────────────┬───────────────────────────────────────┘
                  │ Firebase
                  ↓
        ┌──────────────────┐
        │ Firebase Storage │
        │ Firestore        │
        └──────────────────┘

## 4. INTEGRACIÓN EN APP.DART (Provider Setup)

Registra el ViewModel en el árbol de Provider en app.dart o donde corresponda:

```dart
// En MultiProvider o ChangeNotifierProvider
ChangeNotifierProvider<ProfileViewModel>(
  create: (_) => ProfileViewModel(
    repository: ProfileRepository(),
  ),
  child: const YourApp(),
),
```

## 5. USO EN VISTAS EXISTENTES

### Integrar ProfileAvatar en tu actual vista de perfil:

```dart
Consumer<ProfileViewModel>(
  builder: (context, viewModel, _) {
    return ProfileAvatar(
      photoUrl: viewModel.profile?.photoUrl,
      userName: viewModel.profile?.fullName ?? 'User',
      radius: 60,
      onTap: () => showDialog(
        context: context,
        builder: (_) => ProfilePictureDialog(userId: userId),
      ),
    );
  },
)
```

### Mostrar indicador de carga:

```dart
if (viewModel.isLoading) {
  Center(
    child: CircularProgressIndicator(),
  )
}
```

### Mostrar errores:

```dart
if (viewModel.errorMessage != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(viewModel.errorMessage!)),
  );
}
```

## 6. CARACTERÍSTICAS IMPLEMENTADAS

✅ Selección de imagen desde galería o cámara
✅ Compresión local ANTES de subir (optimiza datos)
✅ Carga a Firebase Storage con ruta: users/{userId}/profile_picture.jpg
✅ Actualización en Firestore: photoUrl
✅ CachedNetworkImage con caché L1 (RAM) y L2 (Disco)
✅ UI Optimista: Avatar se actualiza antes de confirmación de red
✅ Manejo robusto de errores con try-catch
✅ Placeholder y error widgets en avatar
✅ Indicador de carga visual (spinner)
✅ Arquitectura MVVM pura (separación de responsabilidades)

## 7. PERMISOS REQUERIDOS

### Android (AndroidManifest.xml - ya registrados usualmente):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS (Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take profile pictures</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to set profile pictures</string>
```

## 8. CONFIGURACIÓN DE FIREBASE STORAGE

Asegúrate de que tu regla de Firebase Storage permite uploads de usuarios autenticados:

```rules
match /users/{userId}/profile_picture.jpg {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}
```

## 9. TESTING

Para probar localmente:
1. Ejecuta: flutter pub get
2. Asegúrate de que Firebase está configurado en tu proyecto
3. Abre ProfilePage en tu app
4. Haz clic en "Change Photo" o el botón de edición
5. Selecciona una foto desde galería o cámara
6. Verifica que:
   - El avatar se actualiza inmediatamente (UI optimista)
   - La foto se carga a Firebase Storage
   - La URL se actualiza en Firestore
   - El caché funciona en recargas

## 10. NOTAS DE RENDIMIENTO

- CachedNetworkImage cachea automáticamente en RAM y disco
- flutter_image_compress comprime a JPEG 80% (ajustable)
- El avatar muestra iniciales del usuario si no hay foto
- Las imágenes se comprimen ANTES de subir (ahorra ancho de banda)
- El placeholder muestra un spinner mientras carga

## 11. TROUBLESHOOTING

Si la foto no se actualiza:
- Verifica que Firebase Storage está configurado
- Asegúrate de que el usuario está autenticado
- Revisa los permisos de Storage en Firebase
- Verifica que CachedNetworkImage está correctamente integrado

Si falla la compresión:
- Verifica que flutter_image_compress está instalado
- Intenta con una imagen más pequeña
- Revisa los logs de Flutter
"""

