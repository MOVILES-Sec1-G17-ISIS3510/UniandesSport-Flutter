import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/models/user_profile.dart';
import '../services/profile_repository.dart';

/// ViewModel para gestionar la edición y visualización del perfil del usuario.
///
/// Responsabilidades (patrón MVVM):
/// - Mantener el estado del perfil (UserProfile actual, estado de carga, errores)
/// - Orquestar el flujo completo de cambio de foto (captura/selección, compresión, carga)
/// - Notificar a la UI de cambios de estado sin hacer llamadas asíncronas directas desde la vista
/// - Manejar excepciones y exponer mensajes de error a la UI
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  // Estado del perfil
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  // Estado de carga y errores
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final ImagePicker _imagePicker = ImagePicker();

  /// Inicializa el ViewModel cargando el perfil del usuario actual.
  ///
  /// [userId]: UID del usuario autenticado
  Future<void> initialize(String userId) async {
    _setLoading(true);
    try {
      _profile = await _repository.getProfile(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error loading profile: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// Permite al usuario cambiar su foto de perfil desde galería o cámara.
  ///
  /// Flujo (UI Optimista):
  /// 1. Mostrar indicador de carga
  /// 2. Obtener imagen con image_picker
  /// 3. Comprimir y subir a Firebase Storage (en el servicio)
  /// 4. Actualizar Firestore con la nueva URL
  /// 5. Actualizar el ViewModel localmente
  /// 6. Notificar a la UI
  ///
  /// [source]: Origen de la imagen (galería o cámara)
  /// [userId]: UID del usuario propietario de la foto
  Future<void> changeProfilePicture({
    required ImageSource source,
    required String userId,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. Obtener imagen del dispositivo usando image_picker
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95, // Calidad inicial antes de compresión en el servicio
      );

      if (pickedFile == null) {
        // Usuario canceló la selección
        _setLoading(false);
        return;
      }

      // 2. Convertir XFile a File
      final File imageFile = File(pickedFile.path);

      // 3. Subir a Firebase Storage (comprime automáticamente en el servicio)
      final String downloadUrl = await _repository.storageService.uploadProfilePicture(
        imageFile: imageFile,
        userId: userId,
      );

      // 4. Actualizar URL en Firestore
      await _repository.updateProfilePicture(
        userId: userId,
        photoUrl: downloadUrl,
      );

      // 5. Actualizar el perfil local
      if (_profile != null) {
        _profile = UserProfile(
          uid: _profile!.uid,
          email: _profile!.email,
          fullName: _profile!.fullName,
          role: _profile!.role,
          university: _profile!.university,
          program: _profile!.program,
          semester: _profile!.semester,
          mainSport: _profile!.mainSport,
          inferredPreferences: _profile!.inferredPreferences,
          photoUrl: downloadUrl, // URL actualizada
          createdAt: _profile!.createdAt,
        );
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error changing profile picture: ${e.toString()}';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza el estado de carga y notifica a los listeners.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Limpia el mensaje de error.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

