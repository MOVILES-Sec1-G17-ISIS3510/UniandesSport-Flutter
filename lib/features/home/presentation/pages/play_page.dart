import 'package:flutter/material.dart';
import '../../../auth/domain/models/user_profile.dart';

class PlayPage extends StatelessWidget {
  final UserProfile profile;

  const PlayPage({super.key, required this.profile});

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
                  'ENCUENTRA PARTIDO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Play', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),

                // Sport selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Calistenia', 'Running']
                        .map(
                          (sport) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(sport),
                              onSelected: (selected) {},
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'OPEN MATCHES',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '5 available',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.teal),
                ),
                const SizedBox(height: 16),
                _MatchCard(
                  icon: '⚽',
                  title: 'Fútbol 5v5',
                  time: 'Hoy 3:00 PM',
                  spots: '7/10',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _MatchCard(
                  icon: '🏀',
                  title: 'Basketball 3v3',
                  time: 'Hoy 5:30 PM',
                  spots: '4/6',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _MatchCard(
                  icon: '🎾',
                  title: 'Tennis Doubles',
                  time: 'Mañana 10:00 AM',
                  spots: '3/4',
                  color: Colors.yellow[700]!,
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

class _MatchCard extends StatelessWidget {
  final String icon;
  final String title;
  final String time;
  final String spots;
  final Color color;

  const _MatchCard({
    required this.icon,
    required this.title,
    required this.time,
    required this.spots,
    required this.color,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(time, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            spots,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
