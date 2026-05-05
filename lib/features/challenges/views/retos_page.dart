import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/step_sensor_service.dart';
import '../../../core/constants/app_field_limits.dart';
import '../../auth/models/user_profile.dart';
import '../services/challenge_recommendation_engine.dart';
import '../widgets/challenge_review_dialog.dart';

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
  final StepSensorService _stepSensorService = StepSensorService();
  bool _isCreatingChallenge = false;
  String _selectedSportFilter = 'all';
  String _selectedTrackingFilter = 'all';
  double _selectedMinRatingFilter = 0.0;

  static const Set<String> _stepSupportedSports = {'running'};
  static const int _defaultStepGoal = 8000;
  static const List<double> _ratingFilterOptions = [0.0, 3.0, 4.0];

  /// Keeps tab state alive to avoid refetching and losing scroll position.
  @override
  bool get wantKeepAlive => true;

  /// Subscribes to active challenges stream from Firestore.
  @override
  void initState() {
    super.initState();
    _stepSensorService.initialize();
    _challengesStream = FirebaseFirestore.instance
        .collection('challenges')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  @override
  void dispose() {
    _stepSensorService.dispose();
    super.dispose();
  }

  bool _isStepKeywordPresent(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('paso') ||
        normalized.contains('steps') ||
        normalized.contains('step');
  }

  bool _shouldTrackStepsByDefault({
    required String? sport,
    required String goalText,
    required String descriptionText,
  }) {
    final sportKey = (sport ?? '').trim().toLowerCase();
    if (_stepSupportedSports.contains(sportKey)) {
      return true;
    }

    return _isStepKeywordPresent(goalText) ||
        _isStepKeywordPresent(descriptionText);
  }

  bool _matchesChallengeFilters(Map<String, dynamic> data) {
    final sport = ((data['sport'] as String?) ?? '').trim().toLowerCase();
    final trackingMode = ((data['trackingMode'] as String?) ?? '')
        .trim()
        .toLowerCase();
    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;

    if (_selectedSportFilter != 'all' && _selectedSportFilter != sport) {
      return false;
    }

    if (_selectedTrackingFilter != 'all' &&
        _selectedTrackingFilter != trackingMode) {
      return false;
    }

    if (ratingAverage < _selectedMinRatingFilter) {
      return false;
    }

    return true;
  }

  void _resetChallengeFilters() {
    setState(() {
      _selectedSportFilter = 'all';
      _selectedTrackingFilter = 'all';
      _selectedMinRatingFilter = 0.0;
    });
  }

  Widget _buildChallengeFilters() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _resetChallengeFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Sport', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _selectedSportFilter == 'all',
                onSelected: (_) => setState(() => _selectedSportFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Running'),
                selected: _selectedSportFilter == 'running',
                onSelected: (_) =>
                    setState(() => _selectedSportFilter = 'running'),
              ),
              ChoiceChip(
                label: const Text('Soccer'),
                selected: _selectedSportFilter == 'soccer',
                onSelected: (_) =>
                    setState(() => _selectedSportFilter = 'soccer'),
              ),
              ChoiceChip(
                label: const Text('Calisthenics'),
                selected: _selectedSportFilter == 'calisthenics',
                onSelected: (_) =>
                    setState(() => _selectedSportFilter = 'calisthenics'),
              ),
              ChoiceChip(
                label: const Text('Tennis'),
                selected: _selectedSportFilter == 'tennis',
                onSelected: (_) =>
                    setState(() => _selectedSportFilter = 'tennis'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tracking mode', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _selectedTrackingFilter == 'all',
                onSelected: (_) =>
                    setState(() => _selectedTrackingFilter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Manual'),
                selected: _selectedTrackingFilter == 'manual',
                onSelected: (_) =>
                    setState(() => _selectedTrackingFilter = 'manual'),
              ),
              ChoiceChip(
                label: const Text('Steps'),
                selected: _selectedTrackingFilter == 'steps',
                onSelected: (_) =>
                    setState(() => _selectedTrackingFilter = 'steps'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Minimum rating', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ratingFilterOptions.map((value) {
              final label = value == 0.0
                  ? 'All'
                  : '${value.toStringAsFixed(0)}★+';
              return ChoiceChip(
                label: Text(label),
                selected: _selectedMinRatingFilter == value,
                onSelected: (_) =>
                    setState(() => _selectedMinRatingFilter = value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesHero(BuildContext context) {
    return Container(
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
    );
  }

  /// Builds the complete retos experience: header, recommendation, and cards.
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isCompactWidth = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      floatingActionButton: isCompactWidth
          ? FloatingActionButton(
              onPressed: _isCreatingChallenge
                  ? null
                  : _showCreateChallengeDialog,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: _isCreatingChallenge
                  ? null
                  : _showCreateChallengeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create challenge'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _challengesStream,
          builder: (context, snapshot) {
            final baseSlivers = <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildChallengesHero(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildChallengeFilters()),
              ),
            ];

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ...baseSlivers,
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ...baseSlivers,
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InfoBox(
                        text: 'Could not load challenges. Please try again.',
                      ),
                    ),
                  ),
                ],
              );
            }

            final docs =
                snapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final filteredDocs = docs
                .where((doc) => _matchesChallengeFilters(doc.data()))
                .toList();

            if (filteredDocs.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ...baseSlivers,
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InfoBox(
                        text: 'No challenges match your filters. Try Reset.',
                      ),
                    ),
                  ),
                ],
              );
            }

            final sortedDocs = _recommendationEngine.rankChallenges(
              challenges: filteredDocs,
              profile: widget.profile,
            );
            final topRatedDocs = _recommendationEngine.topRatedChallenges(
              challenges: filteredDocs,
              maxResults: 5,
            );

            if (sortedDocs.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ...baseSlivers,
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InfoBox(text: 'No active challenges yet.'),
                    ),
                  ),
                ],
              );
            }

            final recommendation = _recommendationEngine.buildRecommendation(
              challenges: sortedDocs,
              profile: widget.profile,
            );

            final headerWidgets = <Widget>[
              if (topRatedDocs.isNotEmpty)
                _TopRatedChallengesSection(challengeDocs: topRatedDocs),
              if (recommendation != null)
                _ChallengeRecommendationBox(recommendation: recommendation),
            ];

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ...baseSlivers,
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final totalCount =
                          headerWidgets.length + sortedDocs.length;
                      final isLast = index == totalCount - 1;

                      final child = index < headerWidgets.length
                          ? headerWidgets[index]
                          : _ChallengeCard(
                              challengeDoc:
                                  sortedDocs[index - headerWidgets.length],
                              userId: widget.profile.uid,
                              stepSensorService: _stepSensorService,
                              isRecommended:
                                  recommendation?.challengeId ==
                                  sortedDocs[index - headerWidgets.length].id,
                            );

                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: child,
                      );
                    }, childCount: headerWidgets.length + sortedDocs.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateChallengeDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final goalController = TextEditingController();
    final rewardController = TextEditingController();
    final stepGoalController = TextEditingController(
      text: _defaultStepGoal.toString(),
    );

    final sports = <String>['running', 'soccer', 'calisthenics', 'tennis'];
    final difficulties = <String>['Beginner', 'Intermediate', 'Advanced'];

    String? selectedSport = sports.first;
    String? selectedDifficulty = difficulties.first;
    DateTime? selectedEndDate;
    bool? stepTrackingOverride;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final shouldTrackSteps =
                stepTrackingOverride ??
                _shouldTrackStepsByDefault(
                  sport: selectedSport,
                  goalText: goalController.text,
                  descriptionText: descriptionController.text,
                );
            final maxDialogWidth = MediaQuery.sizeOf(context).width < 600
                ? MediaQuery.sizeOf(context).width - 32
                : 560.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: const Text('Create challenge'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxDialogWidth,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
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
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setDialogState(() {
                            selectedSport = v;
                            stepTrackingOverride = null;
                          }),
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
                          onChanged: (_) => setDialogState(() {}),
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
                          onChanged: (_) => setDialogState(() {}),
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
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Track progress with step sensor'),
                          subtitle: Text(
                            shouldTrackSteps
                                ? 'This challenge will use the device step sensor for progress sync.'
                                : 'Manual progress buttons will remain enabled.',
                          ),
                          value: shouldTrackSteps,
                          onChanged: (value) => setDialogState(
                            () => stepTrackingOverride = value,
                          ),
                        ),
                        if (shouldTrackSteps) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: stepGoalController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Step goal',
                              hintText: '8000',
                            ),
                            validator: (v) {
                              final raw = (v ?? '').trim();
                              final parsed = int.tryParse(raw);
                              if (parsed == null || parsed <= 0) {
                                return 'Provide a valid step goal';
                              }
                              if (parsed > 200000) {
                                return 'Step goal is too high';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDifficulty,
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                          ),
                          items: difficulties
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
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
                                    AppValidationRules
                                        .challengeRewardMinLength) {
                              return 'Reward is too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
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
              ),
              actionsOverflowAlignment: OverflowBarAlignment.end,
              actionsOverflowDirection: VerticalDirection.down,
              actionsOverflowButtonSpacing: 8,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isCreatingChallenge
                      ? null
                      : () async {
                          final dialogNavigator = Navigator.of(dialogContext);
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

                          final stepTracking =
                              stepTrackingOverride ??
                              _shouldTrackStepsByDefault(
                                sport: selectedSport,
                                goalText: goalController.text,
                                descriptionText: descriptionController.text,
                              );

                          await _createChallenge(
                            title: titleController.text.trim(),
                            sport: selectedSport!,
                            description: descriptionController.text.trim(),
                            goal: goalController.text.trim(),
                            difficulty: selectedDifficulty,
                            reward: rewardController.text.trim(),
                            endDate: selectedEndDate!,
                            useStepTracking: stepTracking,
                            stepGoal: stepTracking
                                ? int.tryParse(stepGoalController.text.trim())
                                : null,
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

    titleController.dispose();
    descriptionController.dispose();
    goalController.dispose();
    rewardController.dispose();
    stepGoalController.dispose();
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
    required bool useStepTracking,
    int? stepGoal,
  }) async {
    if (_isCreatingChallenge) return;

    setState(() => _isCreatingChallenge = true);

    try {
      final sportKey = sport.toLowerCase();

      await FirebaseFirestore.instance.collection('challenges').add({
        'title': title,
        'sport': sportKey,
        'description': description.isNotEmpty ? description : null,
        'goalLabel': goal.isNotEmpty ? goal : null,
        'trackingMode': useStepTracking ? 'steps' : 'manual',
        'stepGoal': useStepTracking ? (stepGoal ?? _defaultStepGoal) : null,
        'difficulty': difficulty?.isNotEmpty ?? false ? difficulty : null,
        'reward': reward.isNotEmpty ? reward : null,
        'endDate': Timestamp.fromDate(endDate),
        'status': 'active',
        'createdBy': widget.profile.uid,
        'participantsCount': 0,
        'progressByUser': {},
        'stepProgressByUser': {},
        'stepSensorBaselineByUser': {},
        'ratingAverage': 0.0,
        'ratingCount': 0,
        'reviewsCount': 0,
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

class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({
    required this.challengeDoc,
    required this.userId,
    required this.stepSensorService,
    this.isRecommended = false,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userId;
  final StepSensorService stepSensorService;
  final bool isRecommended;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _loading = false;
  bool _progressUpdating = false;

  bool _isStepTrackingMode(Map<String, dynamic> data) {
    final trackingMode = (data['trackingMode'] as String?)?.toLowerCase();
    return trackingMode == 'steps';
  }

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

  bool _isChallengeFinishedForUser({
    required bool isJoined,
    required double progress,
    required DateTime? endDate,
  }) {
    if (!isJoined) return false;
    if (progress >= 1.0) return true;
    if (endDate == null) return false;
    return endDate.isBefore(DateTime.now());
  }

  Future<void> _openReviewDialog(String title) async {
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ChallengeReviewDialog(
          challengeId: widget.challengeDoc.id,
          challengeTitle: title,
        );
      },
    );
  }

  Widget _buildRatingSummary({
    required BuildContext context,
    required double ratingAverage,
    required int ratingCount,
    Color? color,
  }) {
    final themedColor = color ?? Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(Icons.star, size: 18, color: Colors.amber[700]),
        const SizedBox(width: 4),
        Text(
          ratingCount > 0
              ? '${ratingAverage.toStringAsFixed(1)} ($ratingCount)'
              : 'No ratings yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: themedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Opens a bottom sheet with extended challenge details and metadata.
  Future<void> _openChallengeDetails(
    Map<String, dynamic> data, {
    required bool canReview,
    required String challengeTitle,
  }) async {
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Challenge');

    final description = (data['description'] as String?)?.trim();
    final goalLabel = (data['goalLabel'] as String?)?.trim();
    final reward = (data['reward'] as String?)?.trim();
    final difficulty = (data['difficulty'] as String?)?.trim();
    final trackingMode = (data['trackingMode'] as String?)?.toLowerCase();
    final stepGoal = (data['stepGoal'] as num?)?.toInt();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final sport = (data['sport'] as String?) ?? '';
    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final reviewsFuture = FirebaseFirestore.instance
        .collection('challenges')
        .doc(widget.challengeDoc.id)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .limit(8)
        .get();

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
                  const SizedBox(height: 8),
                  _buildRatingSummary(
                    context: context,
                    ratingAverage: ratingAverage,
                    ratingCount: ratingCount,
                  ),
                  if (difficulty != null && difficulty.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Difficulty: $difficulty',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (trackingMode == 'steps') ...[
                    const SizedBox(height: 6),
                    Text(
                      stepGoal == null
                          ? 'Tracking: Step sensor'
                          : 'Tracking: Step sensor ($stepGoal steps goal)',
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
                  if (canReview) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openReviewDialog(challengeTitle);
                        },
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Rate and review this challenge'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Reviews',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: reviewsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final docs =
                          snapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      if (docs.isEmpty) {
                        return Text(
                          'No reviews yet. Be the first to rate this challenge.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final review = doc.data();
                          final userName =
                              (review['userName'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? review['userName'] as String
                              : 'Anonymous';
                          final comment =
                              (review['comment'] as String?)?.trim() ?? '';
                          final imageUrl = (review['imageUrl'] as String?)
                              ?.trim();
                          final rating =
                              ((review['rating'] as num?)?.toInt() ?? 0).clamp(
                                0,
                                5,
                              );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        userName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.star,
                                          size: 16,
                                          color: rating > index
                                              ? Colors.amber[700]
                                              : Colors.grey[400],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    comment,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (imageUrl != null &&
                                    imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      imageUrl,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const SizedBox.shrink();
                                          },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
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

  /// Syncs challenge progress using live device steps.
  ///
  /// Flow:
  /// 1) Read current cumulative device steps.
  /// 2) Compute the delta since the user's last sync for this challenge.
  /// 3) Convert cumulative steps into completion percentage based on `stepGoal`.
  Future<void> _syncProgressFromSensor() async {
    if (_progressUpdating || !mounted) return;

    setState(() => _progressUpdating = true);

    try {
      final currentSteps = await widget.stepSensorService
          .getCurrentTotalSteps();
      if (currentSteps == null) {
        final lastError = widget.stepSensorService.lastError;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lastError == null
                  ? 'Could not read step sensor. Walk a few steps and sync again.'
                  : 'Could not read step sensor. Check permission settings and try again.',
            ),
          ),
        );
        return;
      }

      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeDoc.id);
      var firstCalibration = false;
      var syncedSteps = 0;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(challengeRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final stepGoal = (data['stepGoal'] as num?)?.toInt() ?? 8000;
        final stepProgressByUser = Map<String, dynamic>.from(
          data['stepProgressByUser'] ?? const {},
        );
        final stepSensorBaselineByUser = Map<String, dynamic>.from(
          data['stepSensorBaselineByUser'] ?? const {},
        );

        final previousSensorSteps =
            (stepSensorBaselineByUser[widget.userId] as num?)?.toInt() ?? 0;
        final currentTrackedSteps =
            (stepProgressByUser[widget.userId] as num?)?.toInt() ?? 0;

        final hasNoBaselineYet =
            previousSensorSteps == 0 && currentTrackedSteps == 0;
        firstCalibration = hasNoBaselineYet;
        final sensorDelta = hasNoBaselineYet
            ? 0
            : (currentSteps - previousSensorSteps).clamp(0, 1000000);
        syncedSteps = sensorDelta;
        final updatedTrackedSteps = currentTrackedSteps + sensorDelta;
        final updatedProgress = (updatedTrackedSteps / stepGoal).clamp(
          0.0,
          1.0,
        );

        transaction.update(challengeRef, {
          'stepProgressByUser.${widget.userId}': updatedTrackedSteps,
          'stepSensorBaselineByUser.${widget.userId}': currentSteps,
          'progressByUser.${widget.userId}': updatedProgress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      if (firstCalibration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Step sensor calibrated. Walk a bit and sync again to see progress.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedSteps > 0
                  ? 'Progress synced (+$syncedSteps steps).'
                  : 'No new steps detected since your last sync.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sync progress from steps.')),
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
      final snapshotData = widget.challengeDoc.data();
      final isStepTracking = _isStepTrackingMode(snapshotData);
      final baselineSteps = isStepTracking
          ? await widget.stepSensorService.getCurrentTotalSteps()
          : null;

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
            'stepProgressByUser.${widget.userId}': FieldValue.delete(),
            'stepSensorBaselineByUser.${widget.userId}': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(challengeRef, {
            'participants': FieldValue.arrayUnion([widget.userId]),
            'participantsCount': FieldValue.increment(1),
            'progressByUser.${widget.userId}': 0,
            'stepProgressByUser.${widget.userId}': 0,
            if (baselineSteps != null)
              'stepSensorBaselineByUser.${widget.userId}': baselineSteps,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final isStepTracking = _isStepTrackingMode(data);
    final stepGoal = (data['stepGoal'] as num?)?.toInt() ?? 0;
    final stepProgressByUser = Map<String, dynamic>.from(
      data['stepProgressByUser'] ?? const {},
    );
    final trackedSteps =
        (stepProgressByUser[widget.userId] as num?)?.toInt() ?? 0;

    final rawUserProgress = progressByUser[widget.userId];
    final userProgress = (rawUserProgress is num)
        ? rawUserProgress.toDouble()
        : 0.0;
    final clampedProgress = userProgress.clamp(0.0, 1.0);
    final ratingAverage = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final canReview = _isChallengeFinishedForUser(
      isJoined: isJoined,
      progress: clampedProgress,
      endDate: endDate,
    );
    final sport = (data['sport'] as String?) ?? '';
    final accent = _accentForSport(sport);
    final participantsCount =
        (data['participantsCount'] as num?)?.toInt() ?? participants.length;

    // Colores dinámicos para modo oscuro
    final gradientStartColor = accent.withValues(alpha: isDark ? 0.08 : 0.10);
    final gradientEndColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final borderColor = accent.withValues(alpha: isDark ? 0.25 : 0.30);
    final shadowColor = accent.withValues(alpha: isDark ? 0.15 : 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChallengeDetails(
          data,
          canReview: canReview,
          challengeTitle: title,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStartColor, gradientEndColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
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
                        const SizedBox(height: 4),
                        _buildRatingSummary(
                          context: context,
                          ratingAverage: ratingAverage,
                          ratingCount: ratingCount,
                          color: Colors.grey[700],
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
                        if (isStepTracking) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _progressUpdating
                                ? null
                                : _syncProgressFromSensor,
                            icon: const Icon(Icons.sensors),
                            label: const Text('Sync steps'),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                          ),
                        ] else ...[
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _progressUpdating
                            ? 'Updating progress...'
                            : isStepTracking
                            ? 'Use Sync steps to update from your device sensor (${stepGoal > 0 ? '$trackedSteps/$stepGoal' : '$trackedSteps'}).'
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
              if (canReview) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openReviewDialog(title),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Rate challenge'),
                  ),
                ),
              ],
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

class _TopRatedChallengesSection extends StatelessWidget {
  const _TopRatedChallengesSection({required this.challengeDocs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> challengeDocs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8D9A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFF8A6B00)),
              const SizedBox(width: 8),
              Text(
                'Top rated challenges',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B5100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: challengeDocs.map((doc) {
                final data = doc.data();
                final title =
                    (data['title'] as String?)?.trim().isNotEmpty == true
                    ? data['title'] as String
                    : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
                          ? data['goalLabel'] as String
                          : 'Challenge');
                final sport = ((data['sport'] as String?) ?? '').trim();
                final ratingAverage =
                    (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
                final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

                return Container(
                  width: 190,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE7DFC8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sport.isEmpty ? 'General' : sport,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            ratingCount > 0
                                ? '${ratingAverage.toStringAsFixed(1)} ($ratingCount)'
                                : 'No ratings',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
