import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);

    try {
      await _repository.signIn(email: email, password: password);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _repository.getReadableError(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? university,
    String? program,
    int? semester,
    String? mainSport,
  }) async {
    _setLoading(true);

    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        university: university,
        program: program,
        semester: semester,
        mainSport: mainSport,
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _repository.getReadableError(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() => _repository.signOut();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
