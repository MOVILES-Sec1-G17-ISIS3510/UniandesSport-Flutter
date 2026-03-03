enum UserRole { athlete, tutor, organizer }

extension UserRoleX on UserRole {
  String get code {
    switch (this) {
      case UserRole.athlete:
        return 'athlete';
      case UserRole.tutor:
        return 'tutor';
      case UserRole.organizer:
        return 'organizer';
    }
  }

  String get label {
    switch (this) {
      case UserRole.athlete:
        return 'Deportista';
      case UserRole.tutor:
        return 'Tutor / Instructor';
      case UserRole.organizer:
        return 'Organizador';
    }
  }

  static UserRole fromCode(String value) {
    return UserRole.values.firstWhere(
      (role) => role.code == value,
      orElse: () => UserRole.athlete,
    );
  }
}
