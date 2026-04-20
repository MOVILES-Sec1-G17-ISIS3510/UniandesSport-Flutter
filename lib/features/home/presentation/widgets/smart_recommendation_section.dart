import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../auth/domain/models/user_profile.dart';
import '../../data/services/gemini_smart_recommendation_service.dart';
import '../../domain/models/smart_recommendation.dart';
import '../pages/create_casual_event_page.dart';
import '../pages/event_details_page.dart';
import 'smart_recommendation_card.dart';

class SmartRecommendationSection extends StatefulWidget {
  final UserProfile profile;

  const SmartRecommendationSection({
    super.key,
    required this.profile,
  });

  @override
  State<SmartRecommendationSection> createState() =>
      _SmartRecommendationSectionState();
}

class _SmartRecommendationSectionState extends State<SmartRecommendationSection> {
  final GeminiSmartRecommendationService _service =
      GeminiSmartRecommendationService();

  bool _isGenerating = false;
  String? _generationError;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userMap = userSnapshot.data?.data();
        final embedded = _asStringDynamicMap(userMap?['smart_recommendation']);

        if (embedded != null) {
          final recommendation = _parseRecommendation(embedded);
          if (recommendation != null) {
            return SmartRecommendationCard(
              recommendation: recommendation,
              onPressed: () => _handleAction(context, recommendation),
            );
          }
        }

        return _LegacyRecommendationStream(
          uid: widget.profile.uid,
          onAction: (recommendation) => _handleAction(context, recommendation),
          emptyBuilder: () => _SmartRecommendationEmptyState(
            isGenerating: _isGenerating,
            generationError: _generationError,
            onGenerate: _generateFromClient,
          ),
        );
      },
    );
  }

  Future<void> _generateFromClient() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _generationError = null;
    });

    try {
      final recommendation =
          await _service.generateAndStoreForUser(widget.profile.uid);

      if (!mounted) return;
      if (recommendation == null) {
        setState(() {
          _generationError =
              'No recommendation could be generated. Add time slots first.';
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Smart recommendation generated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generationError = _buildReadableError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  String _buildReadableError(Object error) {
    if (error is SmartRecommendationGenerationException) {
      return error.message;
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'Failed to generate recommendation. Try again.';
    }
    if (text.startsWith('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }
    return text;
  }

  SmartRecommendation? _parseRecommendation(Map<String, dynamic> data) {
    try {
      final recommendation = SmartRecommendation.fromJson(data);
      if (recommendation.uiTitle.isEmpty ||
          recommendation.uiBody.isEmpty ||
          recommendation.ctaText.isEmpty) {
        return null;
      }
      return recommendation;
    } catch (_) {
      return null;
    }
  }

  void _handleAction(BuildContext context, SmartRecommendation recommendation) {
    if (recommendation.type == RecommendationType.join) {
      final eventId = recommendation.eventId;
      if (eventId == null || eventId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This recommendation has no event id.')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailsPage(eventId: eventId),
        ),
      );
      return;
    }

    final draft = recommendation.eventDraft;
    if (draft == null || draft.deporte.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This recommendation has no draft event.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(arguments: draft.toJson()),
        builder: (_) => CreateCasualEventPage(
          profile: widget.profile,
          sport: draft.deporte.trim(),
        ),
      ),
    );
  }
}

class _LegacyRecommendationStream extends StatelessWidget {
  final String uid;
  final ValueChanged<SmartRecommendation> onAction;
  final Widget Function() emptyBuilder;

  const _LegacyRecommendationStream({
    required this.uid,
    required this.onAction,
    required this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('smart_recommendations')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return emptyBuilder();
        }

        SmartRecommendation recommendation;
        try {
          recommendation = SmartRecommendation.fromJson(data);
        } catch (_) {
          return emptyBuilder();
        }

        if (recommendation.uiTitle.isEmpty ||
            recommendation.uiBody.isEmpty ||
            recommendation.ctaText.isEmpty) {
          return emptyBuilder();
        }

        return SmartRecommendationCard(
          recommendation: recommendation,
          onPressed: () => onAction(recommendation),
        );
      },
    );
  }
}

class _SmartRecommendationEmptyState extends StatelessWidget {
  final bool isGenerating;
  final String? generationError;
  final VoidCallback onGenerate;

  const _SmartRecommendationEmptyState({
    required this.isGenerating,
    required this.generationError,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Generate your smart recommendation with AI.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (generationError != null) ...[
            const SizedBox(height: 8),
            Text(
              generationError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt),
              label: Text(isGenerating ? 'Generating...' : 'Generate now'),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(key.toString(), val),
    );
  }
  return null;
}
