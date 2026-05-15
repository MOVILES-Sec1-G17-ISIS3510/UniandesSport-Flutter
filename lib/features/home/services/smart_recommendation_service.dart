import 'package:cloud_firestore/cloud_firestore.dart';

export 'gemini_smart_recommendation_service.dart';
import 'gemini_smart_recommendation_service.dart';
import '../models/smart_recommendation.dart';

/// Lightweight compatibility wrapper so widgets can import
/// `SmartRecommendationService` (historic name) while the
/// implementation lives in `GeminiSmartRecommendationService`.
class SmartRecommendationService {
  final GeminiSmartRecommendationService _impl;

  SmartRecommendationService._(this._impl);

  factory SmartRecommendationService({FirebaseFirestore? firestore}) =>
      SmartRecommendationService._(
        GeminiSmartRecommendationService.getInstance(firestore: firestore),
      );

  Future<SmartRecommendation?> generateAndStoreForUser(String uid) async {
    return await _impl.generateAndStoreForUser(uid);
  }
}
