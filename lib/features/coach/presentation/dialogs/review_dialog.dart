import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uniandessport_flutter/core/services/analytics_service.dart';
import 'package:uniandessport_flutter/core/services/pending_reviews_service.dart';
import 'package:uniandessport_flutter/features/coach/presentation/viewmodels/coaches_view_model.dart';

class AddReviewDialog extends StatefulWidget {
  final String coachId;
  final String coachSport;

  const AddReviewDialog({
    super.key,
    required this.coachId,
    required this.coachSport,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  int rating = 0;
  final TextEditingController commentController = TextEditingController();
  bool isSubmitting = false;

  // Sensor: imagen
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // Sensor: micrófono → texto
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
    } catch (_) {
      _speechAvailable = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Picks an image and keeps both the file path and the raw bytes.
  ///
  /// The file is used for preview, while the bytes are stored in the offline
  /// queue so the image can be uploaded later if the device loses connection.
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = File(picked.path);
        _selectedImageBytes = bytes;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      try {
        await _speech.listen(
          onResult: (result) {
            setState(() {
              commentController.text = result.recognizedWords;
              commentController.selection = TextSelection.fromPosition(
                TextPosition(offset: commentController.text.length),
              );
            });
          },
          localeId: 'en_US',
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.dictation,
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      }
    }
  }

  Future<String?> _uploadImage(String coachId) async {
    if (_selectedImage == null) return null;
    final ref = FirebaseStorage.instance.ref().child(
      'reviews/$coachId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(_selectedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> submitReview() async {
    if (rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a rating")));
      return;
    }

    setState(() => isSubmitting = true);

    final vm = context.read<CoachesViewModel>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      String userName = 'Anonymous';
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          userName =
              (userDoc.data()?['fullName'] as String?)?.trim().isNotEmpty ==
                  true
              ? userDoc.data()!['fullName'] as String
              : user.email ?? 'Anonymous';
        }
      }

      final isOffline = await vm.checkIsOffline();

      if (isOffline) {
        // Sin internet: guardar en cola local con texto, voz convertida y foto si existe.
        await PendingReviewsService.instance.addPendingReview(
          PendingReview(
            coachId: widget.coachId,
            coachSport: widget.coachSport,
            rating: rating,
            comment: commentController.text.trim(),
            userId: user?.uid,
            userName: userName,
            createdAt: DateTime.now(),
            imageBytesBase64: _selectedImageBytes == null
                ? null
                : base64Encode(_selectedImageBytes!),
            imageFileName: _selectedImage != null
                ? '${DateTime.now().millisecondsSinceEpoch}.jpg'
                : null,
          ),
        );

        vm.incrementPendingReviews();

        if (!mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "You're offline. Review saved and will sync when reconnected.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Con internet: subir imagen si hay una seleccionada.
      final imageUrl = await _uploadImage(widget.coachId);

      final coachRef = FirebaseFirestore.instance
          .collection('profesores')
          .doc(widget.coachId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final coachDoc = await transaction.get(coachRef);
        final currentRating =
            (coachDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
        final currentTotal =
            (coachDoc.data()?['totalReviews'] as num?)?.toInt() ?? 0;
        final newTotal = currentTotal + 1;
        final newRating = ((currentRating * currentTotal) + rating) / newTotal;

        final reviewRef = coachRef.collection('reviews').doc();
        transaction.set(reviewRef, {
          'rating': rating,
          'comment': commentController.text.trim(),
          'userId': user?.uid,
          'userName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        });
        transaction.update(coachRef, {
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'totalReviews': newTotal,
        });
      });

      if (!mounted) return;
      navigator.pop();

      await vm.loadCoaches();

      AnalyticsService.instance.logInitiateRegistration(
        sportCategory: widget.coachSport,
        eventId: widget.coachId,
      );

      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text("Review submitted successfully ⭐"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Error al enviar review: $e")),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ADD REVIEW",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Text(
                "Rating",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // Estrellas
              Row(
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => rating = starIndex),
                      child: Container(
                        margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.star,
                          color: rating >= starIndex
                              ? Colors.amber
                              : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Comment + voice-to-text button.
              Row(
                children: [
                  const Text(
                    "Comment",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (_speechAvailable)
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red.shade100
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isListening ? Colors.red : Colors.teal,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              size: 16,
                              color: _isListening ? Colors.red : Colors.teal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isListening ? "Stop" : "Speak",
                              style: TextStyle(
                                fontSize: 12,
                                color: _isListening ? Colors.red : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _isListening
                      ? "Listening..."
                      : "Share your experience...",
                  filled: true,
                  fillColor: _isListening
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _isListening
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _isListening
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Photo picker + preview.
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: Text(
                      _selectedImage == null ? "Add photo" : "Change photo",
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(width: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedImage = null;
                              _selectedImageBytes = null;
                            }),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Cancel / Submit actions.
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("Submit"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
