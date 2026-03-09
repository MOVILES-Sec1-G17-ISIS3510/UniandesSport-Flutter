import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_sports.dart';
import '../domain/models/user_profile.dart';
import '../domain/models/user_role.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

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

    await _firestore.collection('users').doc(uid).set(profile.toJson());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return UserProfile.fromJson(snapshot.data()!);
  }

  Stream<UserProfile?> userProfileChanges(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfile.fromJson(snapshot.data()!);
    });
  }

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

  String getReadableError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'El correo no es válido.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Este correo ya está registrado.';
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'network-request-failed':
          return 'Error de red. Revisa tu conexión.';
        default:
          return error.message ?? 'Error de autenticación.';
      }
    }

    if (error is FirebaseException) {
      return error.message ?? 'Error de Firebase.';
    }

    return 'Ocurrió un error inesperado.';
  }
}
