import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/validation/app_field_limits.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/recommendation/challenge_recommendation_engine.dart';

/// Challenges page that renders active retos, recommendation, and participation UI.
class RetosPage extends StatefulWidget {
  final UserProfile profile;

  const RetosPage({super.key, required this.profile});

  @override
  State<RetosPage> createState() => _RetosPageState();
}

class _RetosPageState extends State<RetosPage>
    with AutomaticKeepAliveClientMixin {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _challengesStream;
  final ChallengeRecommendationEngine _recommendationEngine =
      const ChallengeRecommendationEngine();
  bool _isCreatingChallenge = false;

  /// Keeps tab state alive to avoid refetching and losing scroll position.
  @override
  bool get wantKeepAlive => true;

  /// Subscribes to active challenges stream from Firestore.
  @override
  void initState() {
    super.initState();
    _challengesStream = FirebaseFirestore.instance
        .collection('challenges')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  /// Builds the complete retos experience: header, recommendation, and cards.
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C8E8B), Color(0xFF3AB2AE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPETE AND IMPROVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Challenges',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Join, improve, and track your real-time progress.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _challengesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const _InfoBox(
                        text: 'Could not load challenges. Please try again.',
                      );
                    }

                    final docs =
                        snapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return const _InfoBox(text: 'No active challenges yet.');
                    }

                    final sortedDocs = _recommendationEngine.rankChallenges(
                      challenges: docs,
                      profile: widget.profile,
                    );

                    final recommendation = _recommendationEngine
                        .buildRecommendation(
                          challenges: sortedDocs,
                          profile: widget.profile,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sortedDocs.isEmpty
                          ? const []
                          : [
                                  if (recommendation != null) ...[
                                    _ChallengeRecommendationBox(
                                      recommendation: recommendation,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ]
                                .followedBy(
                                  sortedDocs
                                      .map(
                                        (doc) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _ChallengeCard(
                                            challengeDoc: doc,
                                            userId: widget.profile.uid,
                                            isRecommended:
                                                recommendation?.challengeId ==
                                                doc.id,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                                .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateChallengeDialog,
        tooltip: 'Create Challenge',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Shows dialog to create a new challenge.
  ///
  /// Displays form with fields: title, sport, description, goal, difficulty,
  /// reward, and end date. Saves to Firestore when submitted.
  Future<void> _showCreateChallengeDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final goalController = TextEditingController();
    final rewardController = TextEditingController();
    String? selectedSport;
    DateTime? selectedEndDate;
    String? selectedDifficulty;
    final formKey = GlobalKey<FormState>();

    final sports = ['Running', 'Soccer', 'Calisthenics', 'Tennis'];
    final difficulties = ['Easy', 'Medium', 'Hard'];

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Challenge'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        textInputAction: TextInputAction.next,
                        maxLength: AppFieldLimits.challengeTitle,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeTitle,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Challenge Title',
                          hintText: '30-Day Challenge',
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return 'Title required';
                          if (text.length <
                              AppValidationRules.challengeTitleMinLength) {
                            return 'At least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSport,
                        decoration: const InputDecoration(labelText: 'Sport'),
                        items: sports
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedSport = v),
                        validator: (v) => v == null ? 'Sport required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        textInputAction: TextInputAction.next,
                        maxLength: AppFieldLimits.challengeDescription,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeDescription,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Run 100K total...',
                        ),
                        maxLines: 2,
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isNotEmpty &&
                              text.length <
                                  AppValidationRules
                                      .challengeDescriptionMinLength) {
                            return 'Use at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: goalController,
                        textInputAction: TextInputAction.next,
                        maxLength: AppFieldLimits.challengeGoal,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeGoal,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Goal',
                          hintText: 'Complete 100 km',
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isNotEmpty &&
                              text.length <
                                  AppValidationRules.challengeGoalMinLength) {
                            return 'Goal is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDifficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                        ),
                        items: difficulties
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedDifficulty = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rewardController,
                        textInputAction: TextInputAction.done,
                        maxLength: AppFieldLimits.challengeReward,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            AppFieldLimits.challengeReward,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Reward',
                          hintText: 'Free sports gear',
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isNotEmpty &&
                              text.length <
                                  AppValidationRules.challengeRewardMinLength) {
                            return 'Reward is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                selectedEndDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedEndDate = picked);
                          }
                        },
                        child: Text(
                          selectedEndDate != null
                              ? 'End: ${selectedEndDate!.toLocal()}'.split(
                                  ' ',
                                )[0]
                              : 'Pick End Date',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isCreatingChallenge
                      ? null
                      : () async {
                          final dialogNavigator = Navigator.of(context);
                          final rootMessenger = ScaffoldMessenger.of(
                            this.context,
                          );
                          if (!formKey.currentState!.validate()) return;
                          if (selectedEndDate == null) {
                            rootMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Please pick an end date'),
                              ),
                            );
                            return;
                          }
                          await _createChallenge(
                            title: titleController.text.trim(),
                            sport: selectedSport!,
                            description: descriptionController.text.trim(),
                            goal: goalController.text.trim(),
                            difficulty: selectedDifficulty,
                            reward: rewardController.text.trim(),
                            endDate: selectedEndDate!,
                          );
                          if (mounted) dialogNavigator.pop();
                        },
                  child: _isCreatingChallenge
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Creates a new challenge in Firestore.
  ///
  /// Initializes challenge with status='active', empty progressByUser map,
  /// createdBy=current user, and participantsCount=0.
  /// Shows success/error feedback via SnackBar.
  Future<void> _createChallenge({
    required String title,
    required String sport,
    required String description,
    required String goal,
    required String? difficulty,
    required String reward,
    required DateTime endDate,
  }) async {
    if (_isCreatingChallenge) return;

    setState(() => _isCreatingChallenge = true);

    try {
      // Normalize sport name to match expected format
      final sportKey = sport.toLowerCase();

      await FirebaseFirestore.instance.collection('challenges').add({
        'title': title,
        'sport': sportKey,
        'description': description.isNotEmpty ? description : null,
        'goalLabel': goal.isNotEmpty ? goal : null,
        'difficulty': difficulty?.isNotEmpty ?? false ? difficulty : null,
        'reward': reward.isNotEmpty ? reward : null,
        'endDate': Timestamp.fromDate(endDate),
        'status': 'active',
        'createdBy': widget.profile.uid,
        'participantsCount': 0,
        'progressByUser': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge created successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating challenge: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCreatingChallenge = false);
      }
    }
  }
}

/// Card with challenge information, details modal, and join/leave action.
class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({
    required this.challengeDoc,
    required this.userId,
    this.isRecommended = false,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userId;
  final bool isRecommended;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _loading = false;
  bool _progressUpdating = false;

  /// Returns sport accent color used in chip, icon, and progress highlights.
  Color _accentForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return const Color(0xFF2E7DFA);
      case 'futbol':
      case 'soccer':
      case 'football':
        return const Color(0xFF2EAD67);
      case 'calistenia':
        return const Color(0xFFE88A1A);
      case 'tennis':
      case 'tenis':
        return const Color(0xFFD2B125);
      default:
        return const Color(0xFF0C8E8B);
    }
  }

  /// Maps raw sport key to a user-facing English label.
  String _sportLabel(String sport) {
    switch (sport.toLowerCase()) {
      case 'futbol':
      case 'soccer':
      case 'football':
        return 'Soccer';
      case 'running':
        return 'Running';
      case 'calistenia':
        return 'Calisthenics';
      case 'tennis':
      case 'tenis':
        return 'Tennis';
      default:
        return sport.trim().isEmpty ? 'General' : sport;
    }
  }

  /// Selects icon by sport to make each challenge visually distinguishable.
  IconData _iconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'futbol':
      case 'soccer':
      case 'football':
        return Icons.sports_soccer;
      case 'calistenia':
        return Icons.fitness_center;
      case 'tennis':
      case 'tenis':
        return Icons.sports_tennis;
      default:
        return Icons.emoji_events;
    }
  }

  /// Computes remaining time label from challenge end date.
  String _daysLeft(DateTime? endDate) {
    if (endDate == null) return 'No end date';

    final now = DateTime.now();
    final left = endDate.difference(now).inDays;
    if (left < 0) return 'Completed';
    if (left == 0) return 'Ends today';
    if (left == 1) return '1 day left';
    return '$left days left';
  }

  /// Opens a bottom sheet with extended challenge details and metadata.
  Future<void> _openChallengeDetails(Map<String, dynamic> data) async {
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    final description = (data['description'] as String?)?.trim();
    final goalLabel = (data['goalLabel'] as String?)?.trim();
    final reward = (data['reward'] as String?)?.trim();
    final difficulty = (data['difficulty'] as String?)?.trim();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final sport = (data['sport'] as String?) ?? '';

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconForSport(sport), color: _accentForSport(sport)),
                      const SizedBox(width: 8),
                      Text(
                        _sportLabel(sport),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _daysLeft(endDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (difficulty != null && difficulty.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Difficulty: $difficulty',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (description != null && description.isNotEmpty)
                        ? description
                        : 'This challenge does not have a detailed description yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (goalLabel != null && goalLabel.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Goal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      goalLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (reward != null && reward.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Reward',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(reward, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Updates user progress in the challenge with transactional guarantee.
  ///
  /// [delta] is the amount to add to current progress (e.g., 0.05 for +5%).
  /// Progress is automatically clamped to [0, 1].
  Future<void> _updateProgress(double delta) async {
    if (_progressUpdating || !mounted) return;

    setState(() => _progressUpdating = true);

    try {
      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final progressByUser = Map<String, dynamic>.from(
          data['progressByUser'] ?? const {},
        );

        // Calcula nuevo progreso basado en el delta proporcionado.
        final currentProgress =
            (progressByUser[widget.userId] as num?)?.toDouble() ?? 0.0;
        final newProgress = (currentProgress + delta).clamp(0.0, 1.0);

        // Actualiza solo el progreso del usuario en esta transaccion.
        transaction.update(challengeRef, {
          'progressByUser.${widget.userId}': newProgress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update progress.')),
      );
    } finally {
      if (mounted) {
        setState(() => _progressUpdating = false);
      }
    }
  }

  /// Joins or leaves the challenge in a Firestore transaction.
  ///
  /// Transaction guarantees participant counters and per-user progress stay in sync.
  Future<void> _toggleParticipation() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final participants = List<String>.from(
          data['participants'] ?? const [],
        );
        final joined = participants.contains(widget.userId);

        if (joined) {
          transaction.update(challengeRef, {
            'participants': FieldValue.arrayRemove([widget.userId]),
            'participantsCount': FieldValue.increment(-1),
            'progressByUser.${widget.userId}': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(challengeRef, {
            'participants': FieldValue.arrayUnion([widget.userId]),
            'participantsCount': FieldValue.increment(1),
            'progressByUser.${widget.userId}': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your participation.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Renders challenge card with progress, participants, and CTA state.
  @override
  Widget build(BuildContext context) {
    final data = widget.challengeDoc.data();

    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    final participants = List<String>.from(data['participants'] ?? const []);
    final progressByUser = Map<String, dynamic>.from(
      data['progressByUser'] ?? const {},
    );
    final isJoined = participants.contains(widget.userId);

    final rawUserProgress = progressByUser[widget.userId];
    final userProgress = (rawUserProgress is num)
        ? rawUserProgress.toDouble()
        : 0.0;
    final clampedProgress = userProgress.clamp(0.0, 1.0);

    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final sport = (data['sport'] as String?) ?? '';
    final accent = _accentForSport(sport);
    final participantsCount =
        (data['participantsCount'] as num?)?.toInt() ?? participants.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChallengeDetails(data),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.10), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _sportLabel(sport),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'RECOMMENDED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8A6B00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBF4E6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'JOINED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1F8F52),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Icon(_iconForSport(sport), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _daysLeft(endDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(clampedProgress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isJoined)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: clampedProgress,
                              minHeight: 12,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _progressUpdating
                              ? null
                              : () => _updateProgress(-0.05),
                          icon: const Icon(Icons.remove),
                          label: const Text('-5%'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: _progressUpdating
                              ? null
                              : () => _updateProgress(0.05),
                          icon: const Icon(Icons.add),
                          label: const Text('+5%'),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _progressUpdating
                            ? 'Updating progress...'
                            : 'Use - and + buttons to update progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: clampedProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$participantsCount participants',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _daysLeft(endDate),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _toggleParticipation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isJoined ? Colors.red[400] : accent,
                    minimumSize: const Size(0, 44),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isJoined ? 'Leave challenge' : 'Join challenge'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neutral informational box shown on loading-error-empty states.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  /// Renders one message container with subtle background emphasis.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

/// Banner widget that displays the smart recommendation result.
class _ChallengeRecommendationBox extends StatelessWidget {
  final ChallengeRecommendation recommendation;

  const _ChallengeRecommendationBox({required this.recommendation});

  /// Renders recommendation title and explanation.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                'Smart recommendation',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start with "${recommendation.title}" (${recommendation.sportLabel}).',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We suggest it because ${recommendation.reason}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
