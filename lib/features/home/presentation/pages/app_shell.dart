import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../presentation/pages/retos_page.dart';
import '../../presentation/pages/play_page.dart';
import '../../presentation/pages/social_page.dart';
import '../../presentation/pages/profes_page.dart';
import '../../presentation/pages/profile_page.dart';
import '../../presentation/pages/weather_page.dart';
import '../../presentation/pages/strava_page.dart';
import '../../presentation/pages/history_page.dart';
import '../../presentation/pages/tournaments_page.dart';

class AppShell extends StatefulWidget {
  final UserProfile profile;

  const AppShell({super.key, required this.profile});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late UserProfile _profile;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _setupProfileListener();
  }

  void _setupProfileListener() {
    final repository = context.read<AuthRepository>();
    repository.userProfileChanges(_profile.uid).listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _profile = profile;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: _buildCustomBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar acción del botón +
        },
        backgroundColor: const Color(0xFF0C8E8B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Home', 0),
          _buildNavItem(Icons.emoji_events, 'Retos', 1),
          _buildCenterNavItem(),
          _buildNavItem(Icons.people, 'Social', 3),
          _buildNavItem(Icons.school, 'Profes', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFF0C8E8B) : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _selectedIndex == 2;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0C8E8B) : const Color(0xFF0C8E8B),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.sports_soccer : Icons.directions_run,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 2),
            const Text(
              'Play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _HomePageWrapper(
          profile: _profile,
          onNavigateToProfile: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfilePage(profile: _profile),
              ),
            );
          },
        );
      case 1:
        return RetosPage(profile: _profile);
      case 2:
        return PlayPage(profile: _profile);
      case 3:
        return SocialPage(profile: _profile);
      case 4:
        return const ProfesPage();
      default:
        return _HomePageWrapper(
          profile: _profile,
          onNavigateToProfile: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfilePage(profile: _profile),
              ),
            );
          },
        );
    }
  }
}

class _HomePageWrapper extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onNavigateToProfile;

  const _HomePageWrapper({
    required this.profile,
    required this.onNavigateToProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                    Expanded(
                      child: Text(
                        '${_getGreeting(DateTime.now().hour)} 👋',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 28),
                      onPressed: onNavigateToProfile,
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            size: 28,
                          ),
                          onPressed: () {
                            // TODO: Navegar a notificaciones
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: const Center(
                              child: Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        icon: Icons.cloud,
                        label: "24° Cloudy",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WeatherPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: Icons.show_chart,
                        label: "Strava",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StravaPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: Icons.access_time,
                        label: "History",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: Icons.emoji_events,
                        label: "Tournaments",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TournamentsPage(),
                            ),
                          );
                        },
                      ),
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

                // Active Challenges section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE CHALLENGES',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'View all >',
                        style: TextStyle(color: Color(0xFF0C8E8B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ChallengeCard(
                  title: '100K Running Challenge',
                  daysRemaining: '15 days remaining',
                  progress: 0.35,
                  participants: '+45 participants',
                ),
                const SizedBox(height: 16),
                _ChallengeCard(
                  title: '30-Day Push-ups',
                  daysRemaining: '22 days remaining',
                  progress: 0.42,
                  participants: '+67 participants',
                ),
                const SizedBox(height: 32),

                // Recommended for you section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECOMMENDED FOR YOU',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'See more >',
                        style: TextStyle(color: Color(0xFF0C8E8B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RecommendedCard(
                        category: 'Tennis',
                        title: 'Doubles Tournament',
                        organizer: 'UniAndes Racquets',
                        date: 'Sat, Mar 1',
                        spots: '6 spots',
                      ),
                      const SizedBox(width: 12),
                      _RecommendedCard(
                        category: 'Running',
                        title: '5K Night Run',
                        organizer: 'Running UniAndes',
                        date: 'Fri, Feb 28',
                        spots: '18 spots',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Upcoming Matches section
                Text(
                  'UPCOMING MATCHES',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _UpcomingMatchCard(
                  title: '5v5 Soccer',
                  time: 'Today 3:00 PM',
                  location: 'UniAndes Courts',
                ),
                const SizedBox(height: 12),
                _UpcomingMatchCard(
                  title: 'Tennis Doubles',
                  time: 'Tomorrow 10:00 AM',
                  location: 'El Nogal Club',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF00838F)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF00838F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String daysRemaining;
  final double progress;
  final String participants;

  const _ChallengeCard({
    required this.title,
    required this.daysRemaining,
    required this.progress,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0C8E8B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            daysRemaining,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0C8E8B),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(-16, 0),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[500],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(-16, 0),
                child: Text(
                  participants,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final String category;
  final String title;
  final String organizer;
  final String date;
  final String spots;

  const _RecommendedCard({
    required this.category,
    required this.title,
    required this.organizer,
    required this.date,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              category,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF0C8E8B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            organizer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                date,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const Spacer(),
              Text(
                spots,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF0C8E8B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingMatchCard extends StatelessWidget {
  final String title;
  final String time;
  final String location;

  const _UpcomingMatchCard({
    required this.title,
    required this.time,
    required this.location,
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Color(0xFF0C8E8B),
              size: 24,
            ),
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
                const SizedBox(height: 4),
                Text(
                  time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  location,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
