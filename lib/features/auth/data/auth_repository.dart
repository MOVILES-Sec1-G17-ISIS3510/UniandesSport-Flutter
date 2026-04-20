import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_sports.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/user_role.dart';

/// Repositorio de autenticacion y perfil de usuario.
///
/// Conexion con Firebase:
/// - Auth: FirebaseAuth (login, registro, logout, stream de sesion)
/// - Perfil: Cloud Firestore /users/{uid}
///
/// Convencion de datos en /users/{uid}:
/// - uid, email, fullName, role
/// - university, program, semester
/// - mainSport, inferredPreferences
/// - createdAt, updatedAt
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  /// Emite cambios de sesion en tiempo real.
  ///
  /// AuthGate usa este stream para decidir si mostrar LoginPage o AppShell.
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Inicia sesion con email/password en Firebase Auth.
  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Cierra sesion del usuario actual.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Registra usuario en Firebase Auth y crea su perfil en Firestore.
  ///
  /// Flujo:
  /// 1) createUserWithEmailAndPassword() -> obtiene uid
  /// 2) construye UserProfile con datos base y preferencias iniciales
  /// 3) persiste /users/{uid}
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? university,
    String? program,
    int? semester,
    String? mainSport,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final normalizedMainSport = mainSport?.trim().isEmpty ?? true
        ? null
        : AppSports.normalizeSportKey(mainSport!);

    final uid = credential.user!.uid;
    final profile = UserProfile(
      uid: uid,
      email: email.trim(),
      fullName: fullName.trim(),
      role: role,
      university: university?.trim().isEmpty ?? true
          ? null
          : university?.trim(),
      program: program?.trim().isEmpty ?? true ? null : program?.trim(),
      semester: semester,
      mainSport: normalizedMainSport,
      inferredPreferences: AppSports.buildInitialInferredPreferences(
        favoriteSport: normalizedMainSport,
      ),
      createdAt: DateTime.now(),
    );

    // Se escribe el perfil completo al crear la cuenta.
    await _firestore.collection('users').doc(uid).set(profile.toJson());
  }

  /// Obtiene el perfil del usuario desde Firestore.
  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return UserProfile.fromJson(snapshot.data()!);
  }

  /// Stream reactivo de cambios de perfil para UI en tiempo real.
  Stream<UserProfile?> userProfileChanges(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfile.fromJson(snapshot.data()!);
    });
  }

  /// Actualiza parcialmente campos del perfil (merge).
  ///
  /// Nota:
  /// - No sobreescribe el documento completo.
  /// - updatedAt se mantiene con serverTimestamp para trazabilidad.
  Future<void> updateUserProfile({
    required String uid,
    String? fullName,
    String? university,
    String? program,
    int? semester,
    String? mainSport,
  }) async {
    final updates = <String, dynamic>{
      if (fullName != null) 'fullName': fullName.trim(),
      if (university != null)
        'university': university.trim().isEmpty ? null : university.trim(),
      if (program != null)
        'program': program.trim().isEmpty ? null : program.trim(),
      if (semester != null) 'semester': semester,
      if (mainSport != null)
        'mainSport': mainSport.trim().isEmpty
            ? null
            : AppSports.normalizeSportKey(mainSport),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  /// Traduce errores tecnicos de Firebase a mensajes legibles para UI.
  String getReadableError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The email is not valid.';
        case 'user-disabled':
          return 'This account is disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        default:
          return error.message ?? 'Authentication error.';
      }
    }

    if (error is FirebaseException) {
      return error.message ?? 'Firebase error.';
    }

    return 'An unexpected error occurred.';
  }
}
