import 'package:flutter/material.dart';
import '../../../auth/domain/models/user_profile.dart';

class RetosPage extends StatelessWidget {
  final UserProfile profile;

  const RetosPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPITE Y MEJORA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Retos', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                _ChallengeCard(
                  icon: '🏃',
                  title: '100K Running Challenge',
                  progress: 0.35,
                  daysLeft: '15 days remaining',
                  participants: '+45 participants',
                ),
                const SizedBox(height: 12),
                _ChallengeCard(
                  icon: '💪',
                  title: '30-Day Push-ups',
                  progress: 0.42,
                  daysLeft: '22 days remaining',
                  participants: '+67 participants',
                ),
                const SizedBox(height: 12),
                _ChallengeCard(
                  icon: '🎾',
                  title: 'Tennis Marathon',
                  progress: 0.25,
                  daysLeft: '18d left',
                  participants: '23 participants',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String icon;
  final String title;
  final double progress;
  final String daysLeft;
  final String participants;

  const _ChallengeCard({
    required this.icon,
    required this.title,
    required this.progress,
    required this.daysLeft,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
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
                      daysLeft,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(Colors.teal[400]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            participants,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
