import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../auth/domain/models/user_profile.dart';

class RetosPage extends StatefulWidget {
  final UserProfile profile;

  const RetosPage({super.key, required this.profile});

  @override
  State<RetosPage> createState() => _RetosPageState();
}

class _RetosPageState extends State<RetosPage> {
  _ChallengeScope _scope = _ChallengeScope.all;
  String _sportFilter = 'all';

  Stream<List<_ChallengeItem>> _challengeStream() {
    return FirebaseFirestore.instance
        .collection('challenges')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    _ChallengeItem.fromDoc(doc, userId: widget.profile.uid),
              )
              .toList(),
        );
  }

  List<_ChallengeItem> _applyFilters(List<_ChallengeItem> source) {
    return source.where((item) {
      final matchesScope = switch (_scope) {
        _ChallengeScope.all => true,
        _ChallengeScope.individual => item.type == 'individual',
        _ChallengeScope.team => item.type == 'team',
      };

      final matchesSport =
          _sportFilter == 'all' || item.sportKey == _sportFilter;
      return matchesScope && matchesSport;
    }).toList();
  }

  void _openCreateChallengeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CreateChallengeDialog(profile: widget.profile),
    );
  }

  void _openChallengeDetail(_ChallengeItem challenge) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) =>
          _ChallengeDetailDialog(challenge: challenge, profile: widget.profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sportFilters = <_SportFilterItem>[
      const _SportFilterItem(key: 'all', label: 'All Sports', icon: Icons.bolt),
      const _SportFilterItem(
        key: 'futbol',
        label: 'Soccer',
        icon: Icons.sports_soccer,
      ),
      const _SportFilterItem(
        key: 'running',
        label: 'Running',
        icon: Icons.directions_run,
      ),
      const _SportFilterItem(
        key: 'calistenia',
        label: 'Calisthenics',
        icon: Icons.fitness_center,
      ),
      const _SportFilterItem(
        key: 'tennis',
        label: 'Tennis',
        icon: Icons.sports_tennis,
      ),
      const _SportFilterItem(
        key: 'basketball',
        label: 'Basketball',
        icon: Icons.sports_basketball,
      ),
    ];

    return Scaffold(
      floatingActionButton: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openCreateChallengeDialog,
          backgroundColor: const Color(0xFF2E9C9B),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 44),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMPETE AND IMPROVE',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF028C89),
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Challenges',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF08133A),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const _HeaderCircleButton(icon: Icons.search),
                  const SizedBox(width: 10),
                  const _HeaderCircleButton(
                    icon: Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TypeChip(
                      label: 'All',
                      selected: _scope == _ChallengeScope.all,
                      onTap: () => setState(() => _scope = _ChallengeScope.all),
                    ),
                    const SizedBox(width: 10),
                    _TypeChip(
                      label: 'Individual',
                      selected: _scope == _ChallengeScope.individual,
                      onTap: () =>
                          setState(() => _scope = _ChallengeScope.individual),
                    ),
                    const SizedBox(width: 10),
                    _TypeChip(
                      label: 'Team',
                      selected: _scope == _ChallengeScope.team,
                      onTap: () =>
                          setState(() => _scope = _ChallengeScope.team),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sportFilters
                      .map(
                        (sport) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _SportChip(
                            item: sport,
                            selected: _sportFilter == sport.key,
                            onTap: () =>
                                setState(() => _sportFilter = sport.key),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<_ChallengeItem>>(
                stream: _challengeStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Unable to load challenges. Verify Firestore permissions and try again.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  final allItems = snapshot.data ?? const <_ChallengeItem>[];
                  final filteredItems = _applyFilters(allItems);

                  if (filteredItems.isEmpty) {
                    return _EmptyChallengesView(
                      onCreatePressed: _openCreateChallengeDialog,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _ChallengeCard(
                        item: item,
                        onTap: () => _openChallengeDetail(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChallengeScope { all, individual, team }

class _ChallengeItem {
  const _ChallengeItem({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.sportKey,
    required this.goalLabel,
    required this.daysLeft,
    required this.participants,
    required this.progress,
  });

  final String id;
  final String title;
  final String type;
  final String difficulty;
  final String sportKey;
  final String goalLabel;
  final int daysLeft;
  final int participants;
  final double progress;

  static _ChallengeItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String userId,
  }) {
    final data = doc.data();
    final rawSport = (data['sport'] ?? 'running').toString();
    final sportKey = AppSports.normalizeSportKey(rawSport);

    final challengeType =
        (data['type'] ?? data['challengeType'] ?? 'individual')
            .toString()
            .toLowerCase();
    final difficulty = (data['difficulty'] ?? 'beginner')
        .toString()
        .toLowerCase();

    final endTimestamp = data['endDate'];
    int daysLeft = 0;
    if (endTimestamp is Timestamp) {
      final endDate = endTimestamp.toDate();
      daysLeft = endDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        daysLeft = 0;
      }
    } else {
      final fallback = data['daysLeft'];
      if (fallback is num) {
        daysLeft = fallback.toInt();
      }
    }

    int participants = 0;
    final participantList = data['participants'];
    if (participantList is List) {
      participants = participantList.length;
    } else if (data['participantsCount'] is num) {
      participants = (data['participantsCount'] as num).toInt();
    }

    double progress = 0;
    final progressByUser = data['progressByUser'];
    if (progressByUser is Map && progressByUser[userId] is num) {
      progress = (progressByUser[userId] as num).toDouble();
    } else if (data['progress'] is num) {
      progress = (data['progress'] as num).toDouble();
    }
    progress = progress.clamp(0.0, 1.0);

    return _ChallengeItem(
      id: doc.id,
      title: (data['title'] ?? 'Challenge').toString(),
      type: challengeType,
      difficulty: difficulty,
      sportKey: sportKey,
      goalLabel: (data['goalLabel'] ?? data['goal'] ?? 'Custom goal')
          .toString(),
      daysLeft: daysLeft,
      participants: participants,
      progress: progress,
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.item, required this.onTap});

  final _ChallengeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppSports.getSport(item.sportKey);
    final difficultyColor = _difficultyColor(item.difficulty);
    final typeLabel = item.type == 'team' ? 'Team' : 'Individual';
    final difficultyLabel =
        item.difficulty[0].toUpperCase() + item.difficulty.substring(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7EAF0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF0F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      style.icon,
                      color: const Color(0xFF082E7A),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF020E34),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _TagPill(
                              text: typeLabel,
                              textColor: const Color(0xFF002466),
                              bgColor: const Color(0xFFCBEEF2),
                            ),
                            const SizedBox(width: 8),
                            _TagPill(
                              text: difficultyLabel,
                              textColor: difficultyColor,
                              bgColor: difficultyColor.withValues(alpha: 0.14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(item.progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF052A7E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetaItem(icon: Icons.track_changes, text: item.goalLabel),
                  const SizedBox(width: 10),
                  _MetaItem(
                    icon: Icons.watch_later_outlined,
                    text: '${item.daysLeft}d left',
                  ),
                  const SizedBox(width: 10),
                  _MetaItem(
                    icon: Icons.people_outline,
                    text: '${item.participants}',
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 11,
                  backgroundColor: const Color(0xFFE9EBEF),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2E9C9B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'advanced':
        return const Color(0xFFC70000);
      case 'intermediate':
        return const Color(0xFFB45F00);
      default:
        return const Color(0xFF0A7C3F);
    }
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0A8B8A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Color(0xFF31496E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.text,
    required this.textColor,
    required this.bgColor,
  });

  final String text;
  final Color textColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Icon(icon, color: const Color(0xFF08133A), size: 28),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF062C81) : const Color(0xFFDDF0F0),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF052A7E),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SportFilterItem {
  const _SportFilterItem({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SportFilterItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E9A98) : const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1E9A98)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 19,
                color: selected ? Colors.white : const Color(0xFF334B70),
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Colors.white : const Color(0xFF334B70),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChallengesView extends StatelessWidget {
  const _EmptyChallengesView({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              'No challenges match these filters.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new one to get started.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onCreatePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E9C9B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Create challenge'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeDetailDialog extends StatelessWidget {
  const _ChallengeDetailDialog({
    required this.challenge,
    required this.profile,
  });

  final _ChallengeItem challenge;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final difficultyLabel =
        challenge.difficulty[0].toUpperCase() +
        challenge.difficulty.substring(1);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      challenge.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF06133A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 30),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F4F7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TagPill(
                    text: challenge.type == 'team' ? 'Team' : 'Individual',
                    textColor: const Color(0xFF002466),
                    bgColor: const Color(0xFFCBEEF2),
                  ),
                  const SizedBox(width: 8),
                  _TagPill(
                    text: difficultyLabel,
                    textColor: challenge.difficulty == 'advanced'
                        ? const Color(0xFFC70000)
                        : challenge.difficulty == 'intermediate'
                        ? const Color(0xFFB45F00)
                        : const Color(0xFF0A7C3F),
                    bgColor: challenge.difficulty == 'advanced'
                        ? const Color(0xFFFDE9E9)
                        : challenge.difficulty == 'intermediate'
                        ? const Color(0xFFFEF4E6)
                        : const Color(0xFFEAF8EF),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DetailStatBox(
                              label: 'GOAL',
                              value: challenge.goalLabel.toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DetailStatBox(
                              label: 'DAYS LEFT',
                              value: '${challenge.daysLeft}D',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF263A59),
                            ),
                          ),
                          Text(
                            '${(challenge.progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF052A7E),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: challenge.progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFE9EBEF),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF2E9C9B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '🔥 LEADERBOARD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF06133A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LeaderboardList(
                        challengeId: challenge.id,
                        currentUserId: profile.uid,
                        currentUserName: profile.fullName,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF2E9C9B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Join Challenge',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStatBox extends StatelessWidget {
  const _DetailStatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF31496E),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF052A7E),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.challengeId,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String challengeId;
  final String currentUserId;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final leaderboardStream = FirebaseFirestore.instance
        .collection('challenges')
        .doc(challengeId)
        .collection('leaderboard')
        .orderBy('progressValue', descending: true)
        .limit(8)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leaderboardStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _LeaderboardRow(
            rank: 1,
            name: currentUserName,
            value: '0 pts',
            highlighted: true,
          );
        }

        return Column(
          children: List.generate(docs.length, (index) {
            final row = docs[index].data();
            final userId = (row['userId'] ?? '').toString();
            final name = (row['userName'] ?? 'Participant').toString();
            final progressValue = (row['progressValue'] ?? 0).toString();
            final unit = (row['unit'] ?? '').toString();
            final valueText = unit.isEmpty
                ? progressValue
                : '$progressValue $unit';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaderboardRow(
                rank: index + 1,
                name: name,
                value: valueText,
                highlighted: userId == currentUserId,
              ),
            );
          }),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.highlighted,
  });

  final int rank;
  final String name;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE4F1F0) : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(16),
        border: highlighted ? Border.all(color: const Color(0xFF9CD0CF)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFF5E7B8)
                  : rank == 2
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFFD5EBEC),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF082E7A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlighted ? '$name ⭐' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                color: highlighted
                    ? const Color(0xFF087F7F)
                    : const Color(0xFF06133A),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF052A7E),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateChallengeDialog extends StatefulWidget {
  const _CreateChallengeDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  final _titleController = TextEditingController();
  final _goalController = TextEditingController();

  String _type = 'individual';
  String _difficulty = 'beginner';
  String _sport = 'futbol';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate?.add(const Duration(days: 7)) ?? now),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = selected.add(const Duration(days: 1));
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _createChallenge() async {
    final title = _titleController.text.trim();
    final goal = _goalController.text.trim();

    if (title.isEmpty ||
        goal.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all required fields.')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final firestore = FirebaseFirestore.instance;

    try {
      final challengeRef = firestore.collection('challenges').doc();
      final batch = firestore.batch();

      batch.set(challengeRef, {
        'title': title,
        'type': _type,
        'difficulty': _difficulty,
        'sport': _sport,
        'goalLabel': goal,
        'progress': 0.0,
        'progressByUser': {widget.profile.uid: 0.0},
        'participantsCount': 1,
        'participants': [widget.profile.uid],
        'createdBy': widget.profile.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': 'active',
      });

      batch
          .set(challengeRef.collection('leaderboard').doc(widget.profile.uid), {
            'userId': widget.profile.uid,
            'userName': widget.profile.fullName,
            'progressValue': 0,
            'unit': '',
            'createdAt': FieldValue.serverTimestamp(),
          });

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge created successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create challenge in Firestore.'),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NEW CHALLENGE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF06133A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F4F7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _DialogLabel(text: 'Name'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Challenge name'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DropdownField(
                    label: 'Type',
                    value: _type,
                    options: const {'individual': 'Individual', 'team': 'Team'},
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownField(
                    label: 'Difficulty',
                    value: _difficulty,
                    options: const {
                      'beginner': 'Beginner',
                      'intermediate': 'Intermediate',
                      'advanced': 'Advanced',
                    },
                    onChanged: (v) => setState(() => _difficulty = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Sport',
              value: _sport,
              options: const {
                'futbol': 'Soccer',
                'running': 'Running',
                'calistenia': 'Calisthenics',
                'tennis': 'Tennis',
                'basketball': 'Basketball',
              },
              onChanged: (v) => setState(() => _sport = v),
            ),
            const SizedBox(height: 14),
            const _DialogLabel(text: 'Goal'),
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(hintText: 'e.g. 100 km'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateInput(
                    label: 'Start',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateInput(
                    label: 'End',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _createChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E9C9B),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4D6385),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel(text: label),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: options.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'dd/mm/yyyy'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel(text: label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Color(0xFF06133A)),
            ),
          ),
        ),
      ],
    );
  }
}
