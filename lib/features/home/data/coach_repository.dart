import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uniandessport_flutter/features/coach/domain/entities/coach_model.dart';

abstract class CoachRepository {
  Future<List<Coach>> getCoaches();
}

class CoachRepositoryImpl implements CoachRepository {
  final FirebaseFirestore _firestore;

  CoachRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Coach>> getCoaches() async {
    try {
      final snapshot = await _firestore.collection('profesores').get();

      return snapshot.docs.map((doc) => Coach.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error loading coaches: $e');
    }
  }
}
