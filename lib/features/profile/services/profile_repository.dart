import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/local_storage/database_helper.dart';
import '../../auth/models/user_profile.dart';
import 'profile_storage_service.dart';

/// Repositorio de perfil del usuario que orquesta la persistencia en Firestore.
///
/// Responsabilidades:
/// - Actualizar datos de perfil en Firestore (photoUrl, nombre, etc.)
/// - Mantener coherencia entre datos locales y remotos
/// - Aislar la lógica de acceso a datos del resto de la aplicación
class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ProfileStorageService _storageService = ProfileStorageService();

  /// Ruta de colección para usuarios en Firestore
  static const String _usersCollection = 'users';

  /// Actualiza la URL de la foto de perfil en Firestore.
  ///
  /// [userId]: UID del usuario
  /// [photoUrl]: URL de la foto subida a Firebase Storage
  ///
  /// Lanza: Exception si la actualización en Firestore falla
  Future<void> updateProfilePicture({
    required String userId,
    required String photoUrl,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating profile picture in Firestore: $e');
    }
  }

  /// Obtiene el perfil actual del usuario desde Firestore.
  ///
  /// [userId]: UID del usuario
  /// Retorna: UserProfile del usuario o null si no existe
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return UserProfile.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  /// Obtiene el servicio de Storage para uso en ViewModel.
  /// Permite que el ViewModel orqueste la carga de fotos.
  ProfileStorageService get storageService => _storageService;
}

