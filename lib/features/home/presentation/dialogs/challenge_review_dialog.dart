import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/validation/app_field_limits.dart';

class ChallengeReviewDialog extends StatefulWidget {
  const ChallengeReviewDialog({
    super.key,
    required this.challengeId,
    required this.challengeTitle,
  });

  final String challengeId;
  final String challengeTitle;

  @override
  State<ChallengeReviewDialog> createState() => _ChallengeReviewDialogState();
}

class _ChallengeReviewDialogState extends State<ChallengeReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final SpeechToText _speech = SpeechToText();

  int _rating = 0;
  bool _isSubmitting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _microphonePermissionGranted = false;
  String? _speechLocaleId;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _initSpeech();
    await _loadExistingReview();
  }

  Future<bool> _ensureMicrophonePermission() async {
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isGranted) {
      return true;
    }

    final requestedStatus = await Permission.microphone.request();
    if (requestedStatus.isPermanentlyDenied) {
      await openAppSettings();
    }

    return requestedStatus.isGranted;
  }

  Future<void> _initSpeech() async {
    try {
      _microphonePermissionGranted = await _ensureMicrophonePermission();
      if (!_microphonePermissionGranted) {
        _speechAvailable = false;
        return;
      }

      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && mounted) {
            setState(() => _isListening = false);
          }
        },
      );

      if (_speechAvailable) {
        try {
          final locales = await _speech.locales();
          final spanishLocale = locales.where((locale) {
            return locale.localeId.toLowerCase().startsWith('es');
          }).toList();

          _speechLocaleId = spanishLocale.isNotEmpty
              ? spanishLocale.first.localeId
              : null;
        } catch (_) {
          _speechLocaleId = null;
        }
      }
    } catch (_) {
      _speechAvailable = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final existing = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .collection('reviews')
          .doc(user.uid)
          .get();

      if (!existing.exists) return;
      final data = existing.data() ?? const <String, dynamic>{};
      final existingRating = (data['rating'] as num?)?.toInt() ?? 0;
      final existingComment = (data['comment'] as String?)?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        _rating = existingRating.clamp(0, 5);
        _commentController.text = existingComment;
      });
    } catch (_) {
      // Non-blocking: users can still submit without preloading previous review.
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 75);
    if (picked == null || !mounted) return;

    setState(() => _selectedImage = File(picked.path));
  }

  void _showImageSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice dictation is not available on this device.'),
        ),
      );
      return;
    }

    if (!_microphonePermissionGranted) {
      _microphonePermissionGranted = await _ensureMicrophonePermission();
      if (!_microphonePermissionGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Grant microphone permission to use voice dictation.',
            ),
          ),
        );
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isListening = true);
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _commentController.text = result.recognizedWords;
            _commentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _commentController.text.length),
            );
          });
        },
        localeId: _speechLocaleId ?? 'es_CO',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start dictation. Check microphone access.',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _uploadReviewImage() async {
    if (_selectedImage == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(
      'challenge_reviews/${widget.challengeId}/$fileName',
    );
    await ref.putFile(_selectedImage!);
    return ref.getDownloadURL();
  }

  Future<String> _resolveUserName(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      return FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';
    }

    final data = userDoc.data() ?? const <String, dynamic>{};
    final fullName = (data['fullName'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    return FirebaseAuth.instance.currentUser?.email ?? 'Anonymous';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.length < AppValidationRules.challengeReviewMinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a more complete review.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to sign in to add a review.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId);
      final reviewRef = challengeRef.collection('reviews').doc(user.uid);

      final existingReviewSnapshot = await reviewRef.get();
      final existingData =
          existingReviewSnapshot.data() ?? const <String, dynamic>{};
      final previousRating = (existingData['rating'] as num?)?.toDouble();
      final existingImageUrl = (existingData['imageUrl'] as String?)?.trim();

      final uploadedImageUrl = await _uploadReviewImage();
      final imageUrl =
          uploadedImageUrl ??
          ((existingImageUrl != null && existingImageUrl.isNotEmpty)
              ? existingImageUrl
              : null);

      final userName = await _resolveUserName(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final challengeSnapshot = await transaction.get(challengeRef);
        if (!challengeSnapshot.exists) {
          throw StateError('Challenge not found');
        }

        final challengeData =
            challengeSnapshot.data() ?? const <String, dynamic>{};

        final currentCount =
            (challengeData['ratingCount'] as num?)?.toInt() ?? 0;
        final currentAverage =
            (challengeData['ratingAverage'] as num?)?.toDouble() ?? 0.0;

        double totalScore = currentAverage * currentCount;
        int nextCount = currentCount;

        if (previousRating != null && currentCount > 0) {
          totalScore -= previousRating;
        } else {
          nextCount += 1;
        }

        totalScore += _rating;
        final nextAverage = nextCount > 0 ? (totalScore / nextCount) : 0.0;

        final reviewPayload = <String, dynamic>{
          'challengeId': widget.challengeId,
          'challengeTitle': widget.challengeTitle,
          'userId': user.uid,
          'userName': userName,
          'rating': _rating,
          'comment': comment,
          'updatedAt': FieldValue.serverTimestamp(),
          if (previousRating == null) 'createdAt': FieldValue.serverTimestamp(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        };

        transaction.set(reviewRef, reviewPayload, SetOptions(merge: true));
        transaction.update(challengeRef, {
          'ratingAverage': double.parse(nextAverage.toStringAsFixed(2)),
          'ratingCount': nextCount,
          'reviewsCount': nextCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit review: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Review challenge',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.challengeTitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Rating',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(5, (index) {
                  final stars = index + 1;
                  return InkWell(
                    onTap: () => setState(() => _rating = stars),
                    borderRadius: BorderRadius.circular(20),
                    child: Icon(
                      Icons.star,
                      color: _rating >= stars ? Colors.amber : Colors.grey,
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _commentController,
                maxLength: AppFieldLimits.challengeReview,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    AppFieldLimits.challengeReview,
                  ),
                ],
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Your review',
                  hintText: 'How was this challenge for you?',
                  suffixIcon: _speechAvailable
                      ? IconButton(
                          tooltip: _isListening
                              ? 'Stop voice dictation'
                              : 'Start voice dictation',
                          onPressed: _toggleListening,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : null,
                          ),
                        )
                      : IconButton(
                          tooltip: 'Voice dictation unavailable',
                          onPressed: null,
                          icon: const Icon(Icons.mic_off),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add image'),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 4),
                    const Expanded(child: Text('Image selected')),
                  ],
                ],
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
