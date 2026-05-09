import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Servicio dedicado a la gestión de almacenamiento de fotos de perfil en Firebase Storage.
///
/// Responsabilidades:
/// - Comprimir imágenes localmente ANTES de subirlas (ahorro de datos y almacenamiento)
/// - Subir a Firebase Storage en ruta lógica: users/{userId}/profile_picture.jpg
/// - Retornar la URL de descarga de la imagen subida
/// - Manejar excepciones de Storage de forma aislada
///
/// Dependencias requeridas en pubspec.yaml:
/// - firebase_storage: ^12.3.7
/// - flutter_image_compress: ^1.2.1
class ProfileStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Ruta base para fotos de perfil en Firebase Storage
  static const String _profilePicturesPath = 'users';

  /// Compresión de imagen por defecto (0-100)
  static const int _defaultQuality = 85;

  /// Tamaño máximo de ancho/alto para fotos de perfil (px)
  static const int _maxDimension = 800;

  /// Sube una foto de perfil a Firebase Storage con compresión automática.
  ///
  /// Flujo:
  /// 1. Valida que el archivo exista
  /// 2. Comprime la imagen localmente (reduce tamaño)
  /// 3. Sube al path: users/{userId}/profile_picture.jpg (sobrescribe anterior)
  /// 4. Obtiene y retorna la URL de descarga pública
  ///
  /// [imageFile]: Archivo de imagen del dispositivo (File)
  /// [userId]: UID del usuario propietario de la foto
  ///
  /// Retorna: URL de descarga pública (String) de la imagen en Storage
  /// Lanza: Exception si la validación, compresión o carga falla
  Future<String> uploadProfilePicture({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // 1. Validar que el archivo existe
      if (!await imageFile.exists()) {
        throw Exception('Archivo de imagen no encontrado');
      }

      // 2. Comprimir la imagen localmente
      final compressedFile = await _compressImage(imageFile);

      // 3. Definir ruta en Storage (sobrescribe foto anterior)
      final storageRef = _storage.ref().child(
            '$_profilePicturesPath/$userId/profile_picture.jpg',
          );

      // 4. Subir archivo comprimido
      await storageRef.putFile(
        compressedFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'userId': userId,
          },
        ),
      );

      // 5. Obtener URL de descarga pública
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading profile picture to Storage: $e');
    }
  }

  /// Comprime una imagen localmente para reducir tamaño antes de subir.
  ///
  /// Parámetros de compresión:
  /// - Calidad: 85% (balance entre tamaño y claridad)
  /// - Dimensiones máximas: 800x800 px (suficiente para avatares)
  /// - Formato: JPEG (mejor compresión que PNG para fotos)
  ///
  /// [originalFile]: Archivo de imagen original
  /// Retorna: Archivo comprimido (File)
  /// Lanza: Exception si la compresión falla
  Future<File> _compressImage(File originalFile) async {
    try {
      final String tempDir = Directory.systemTemp.path;
      final String targetPath =
          '$tempDir/profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Utilizar flutter_image_compress para comprimir
      // Nota: usar compressWithFile para la versión 0.8.0
      final List<int>? compressedBytes = await FlutterImageCompress.compressWithFile(
        originalFile.absolute.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _defaultQuality,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        throw Exception('Compresión de imagen falló');
      }

      // Guardar bytes comprimidos en archivo temporal
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      throw Exception('Error compressing image: $e');
    }
  }

  /// Elimina la foto de perfil anterior de Firebase Storage (opcional).
  ///
  /// Útil para limpiar Storage cuando un usuario actualiza su foto múltiples veces.
  /// No lanza error si el archivo no existe (es seguro de llamar siempre).
  ///
  /// [userId]: UID del usuario
  Future<void> deleteOldProfilePicture({required String userId}) async {
    try {
      final storageRef = _storage.ref().child(
            '$_profilePicturesPath/$userId/profile_picture.jpg',
          );

      // Intentar eliminar (no falla si no existe)
      await storageRef.delete();
    } catch (e) {
      // Log pero no falla - la foto anterior puede no existir
      debugPrint('[ProfileStorageService] Info: Could not delete old profile picture: $e');
    }
  }
}
