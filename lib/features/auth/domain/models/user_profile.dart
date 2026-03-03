import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.university,
    this.program,
    this.semester,
    this.mainSport,
    this.photoUrl,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? university;
  final String? program;
  final int? semester;
  final String? mainSport;
  final String? photoUrl;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role.code,
      'university': university,
      'program': program,
      'semester': semester,
      'mainSport': mainSport,
      'photoUrl': photoUrl,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt'];

    return UserProfile(
      uid: (json['uid'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      role: UserRoleX.fromCode((json['role'] as String?) ?? 'athlete'),
      university: json['university'] as String?,
      program: json['program'] as String?,
      semester: (json['semester'] as num?)?.toInt(),
      mainSport: json['mainSport'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }
}
