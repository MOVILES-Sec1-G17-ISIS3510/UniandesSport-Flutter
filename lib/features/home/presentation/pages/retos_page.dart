import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../auth/domain/models/user_profile.dart';

class RetosPage extends StatelessWidget {
  final UserProfile profile;

  const RetosPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final challengesRef = FirebaseFirestore.instance
        .collection('challenges')
        .where('status', isEqualTo: 'active');

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
                        'COMPITE Y MEJORA',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Retos',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unete, avanza y sigue tu progreso en tiempo real.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: challengesRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const _InfoBox(
                        text:
                            'No se pudieron cargar los retos. Intenta nuevamente.',
                      );
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const _InfoBox(text: 'Aun no hay retos activos.');
                    }

                    final sortedDocs = [...docs]
                      ..sort((a, b) {
                        final aDate = (a.data()['endDate'] as Timestamp?)
                            ?.toDate();
                        final bDate = (b.data()['endDate'] as Timestamp?)
                            ?.toDate();
                        if (aDate == null && bDate == null) return 0;
                        if (aDate == null) return 1;
                        if (bDate == null) return -1;
                        return aDate.compareTo(bDate);
                      });

                    return Column(
                      children: sortedDocs
                          .map(
                            (doc) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChallengeCard(
                                challengeDoc: doc,
                                userId: profile.uid,
                              ),
                            ),
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
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({required this.challengeDoc, required this.userId});

  final QueryDocumentSnapshot<Map<String, dynamic>> challengeDoc;
  final String userId;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _loading = false;

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

  String _sportLabel(String sport) {
    switch (sport.toLowerCase()) {
      case 'futbol':
      case 'soccer':
      case 'football':
        return 'Futbol';
      case 'running':
        return 'Running';
      case 'calistenia':
        return 'Calistenia';
      case 'tennis':
      case 'tenis':
        return 'Tennis';
      default:
        return sport.trim().isEmpty ? 'General' : sport;
    }
  }

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

  String _daysLeft(DateTime? endDate) {
    if (endDate == null) return 'Sin fecha de cierre';

    final now = DateTime.now();
    final left = endDate.difference(now).inDays;
    if (left < 0) return 'Finalizado';
    if (left == 0) return 'Termina hoy';
    if (left == 1) return '1 dia restante';
    return '$left dias restantes';
  }

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
        const SnackBar(
          content: Text('No fue posible actualizar tu participacion.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.challengeDoc.data();

    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : ((data['goalLabel'] as String?)?.trim().isNotEmpty == true
              ? data['goalLabel'] as String
              : 'Reto');

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

    return Container(
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
                    'INSCRITO',
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
              Icon(Icons.groups_2_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                '$participantsCount participantes',
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
                  : Text(isJoined ? 'Salir del reto' : 'Participar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

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
