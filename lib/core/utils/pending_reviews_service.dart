import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pending review payload persisted locally when the device is offline.
class PendingReview {
  const PendingReview({
    required this.coachId,
    required this.coachSport,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.userId,
    this.userName,
    this.imageBytesBase64,
    this.imageFileName,
  });

  final String coachId;
  final String coachSport;
  final int rating;
  final String comment;
  final String? userId;
  final String? userName;
  final DateTime createdAt;
  final String? imageBytesBase64;
  final String? imageFileName;

  bool get hasImage => imageBytesBase64 != null && imageBytesBase64!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'coachId': coachId,
      'coachSport': coachSport,
      'rating': rating,
      'comment': comment,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
      'imageBytesBase64': imageBytesBase64,
      'imageFileName': imageFileName,
    };
  }

  factory PendingReview.fromJson(Map<String, dynamic> json) {
    return PendingReview(
      coachId: json['coachId']?.toString() ?? '',
      coachSport: json['coachSport']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString() ?? '',
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageBytesBase64: json['imageBytesBase64'] as String?,
      imageFileName: json['imageFileName'] as String?,
    );
  }
}

/// Local queue that stores coach reviews until connectivity is restored.
///
/// The queue is kept in SharedPreferences because reviews are small and the
/// app only needs lightweight offline persistence.
class PendingReviewsService {
  PendingReviewsService._internal();

  static final PendingReviewsService instance =
      PendingReviewsService._internal();

  static const String _queueKey = 'pending_reviews_queue';

  Future<void> addPendingReview(PendingReview review) async {
    final queue = await _loadQueue();
    queue.add(review);
    await _saveQueue(queue);
  }

  Future<int> syncToFirestore() async {
    final queue = await _loadQueue();
    if (queue.isEmpty) {
      return 0;
    }

    final user = FirebaseAuth.instance.currentUser;
    final remaining = <PendingReview>[];
    var syncedCount = 0;

    for (final review in queue) {
      try {
        await _syncSingleReview(review, fallbackUserId: user?.uid);
        syncedCount++;
      } catch (_) {
        remaining.add(review);
      }
    }

    await _saveQueue(remaining);
    return syncedCount;
  }

  Future<void> _syncSingleReview(
    PendingReview review, {
    required String? fallbackUserId,
  }) async {
    final userId = review.userId ?? fallbackUserId;
    final userName = review.userName ?? 'Anonymous';

    String? imageUrl;
    if (review.hasImage) {
      final bytes = base64Decode(review.imageBytesBase64!);
      imageUrl = await _uploadImageBytes(
        coachId: review.coachId,
        bytes: bytes,
        fileName: review.imageFileName,
      );
    }

    final coachRef = FirebaseFirestore.instance
        .collection('profesores')
        .doc(review.coachId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final coachDoc = await transaction.get(coachRef);
      final coachData = coachDoc.data() ?? {};
      final currentRating = (coachData['rating'] as num?)?.toDouble() ?? 0.0;
      final currentTotal = (coachData['totalReviews'] as num?)?.toInt() ?? 0;
      final nextTotal = currentTotal + 1;
      final nextRating =
          ((currentRating * currentTotal) + review.rating) / nextTotal;

      final reviewRef = coachRef.collection('reviews').doc();
      transaction.set(reviewRef, {
        'rating': review.rating,
        'comment': review.comment,
        'userId': userId,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'syncedFromOffline': true,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      transaction.update(coachRef, {
        'rating': double.parse(nextRating.toStringAsFixed(1)),
        'totalReviews': nextTotal,
      });
    });
  }

  Future<String> _uploadImageBytes({
    required String coachId,
    required Uint8List bytes,
    String? fileName,
  }) async {
    final safeFileName =
        fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(
      'reviews/$coachId/$safeFileName',
    );
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<List<PendingReview>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_queueKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <PendingReview>[];
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return <PendingReview>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => PendingReview.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveQueue(List<PendingReview> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }

    await prefs.setString(
      _queueKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }
}
