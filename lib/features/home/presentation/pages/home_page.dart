import 'package:flutter/material.dart';
import '../../../auth/domain/models/user_profile.dart';

class HomePage extends StatelessWidget {
  final UserProfile profile;

  const HomePage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge
            Text(
              'UNIANDES SPORTS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.teal,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),

            // Greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting 👋',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '3',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: '🔥',
                    label: 'STREAK',
                    value: '7 DAYS',
                    backgroundColor: const Color(0xFFFFE8E8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: '📈',
                    label: 'THIS WEEK',
                    value: '3 ACTS',
                    backgroundColor: const Color(0xFFE8F6F5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickFilterChip(
                    icon: '⛅',
                    label: "24° Cloudy",
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _QuickFilterChip(icon: '📊', label: "Strava", onTap: () {}),
                  const SizedBox(width: 8),
                  _QuickFilterChip(icon: '🕐', label: "History", onTap: () {}),
                  const SizedBox(width: 8),
                  _QuickFilterChip(icon: '🏆', label: "Trophies", onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Quick Activity section
            Text(
              'QUICK ACTIVITY',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Based on your profile and schedule',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Activity cards
            _ActivityCard(
              icon: '🏃',
              title: '30-min Interval Run',
              location: 'Campus Track • 400m away',
              duration: '30 min',
              match: 'Matches your running goal',
              matchColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _ActivityCard(
              icon: '🏋️',
              title: 'Calisthenics Challenge',
              location: 'Trending in your community',
              duration: '20 min',
              match: '12 participants today',
              matchColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            _ActivityCard(
              icon: '⚽',
              title: '5v5 Soccer – 1 spot left!',
              location: 'La Caneca • Starts in 10 min',
              duration: '45 min',
              match: 'Join now',
              matchColor: const Color(0xFF0C8E8B),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color backgroundColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChipTheme(
      data: ChipThemeData(
        backgroundColor: const Color(0xFFE8F6F5),
        labelStyle: Theme.of(context).textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Chip(avatar: Text(icon), label: Text(label), onDeleted: null),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String icon;
  final String title;
  final String location;
  final String duration;
  final String match;
  final Color matchColor;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.location,
    required this.duration,
    required this.match,
    required this.matchColor,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
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
                      location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    duration,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    match,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: matchColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
