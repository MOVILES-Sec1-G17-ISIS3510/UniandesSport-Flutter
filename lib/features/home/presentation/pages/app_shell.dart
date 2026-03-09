import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../presentation/pages/retos_page.dart';
import '../../presentation/pages/play_page.dart';
import '../../presentation/pages/social_page.dart';
import '../../presentation/pages/profes_page.dart';
import '../../presentation/pages/profile_page.dart';
import '../widgets/play_nav_item.dart';

class AppShell extends StatefulWidget {
  final UserProfile profile;

  const AppShell({super.key, required this.profile});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late UserProfile _profile;
  int _selectedIndex = 0;
  int _playSportIndex = 0;
  Timer? _playSportTimer;

  static const List<IconData> _playSportIcons = [
    Icons.sports_soccer,
    Icons.fitness_center,
    Icons.directions_run,
    Icons.sports_basketball,
    Icons.sports_tennis,
    Icons.pool,
    Icons.sports,
    Icons.pool,
    Icons.sports_golf,
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _setupProfileListener();
    _startPlayIconRotation();
  }

  @override
  void dispose() {
    _playSportTimer?.cancel();
    super.dispose();
  }

  void _startPlayIconRotation() {
    _playSportTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() {
        _playSportIndex = (_playSportIndex + 1) % _playSportIcons.length;
      });
    });
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Retos',
          ),
          BottomNavigationBarItem(
            icon: PlayNavItem(
              sportIcon: _playSportIcons[_playSportIndex],
              isSelected: false,
            ),
            activeIcon: PlayNavItem(
              sportIcon: _playSportIcons[_playSportIndex],
              isSelected: true,
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profes',
          ),
        ],
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
        return PlayPage(
          profile: _profile,
          onGoHome: () {
            if (!mounted) return;
            setState(() {
              _selectedIndex = 0;
            });
          },
        );
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting(DateTime.now().hour)} 👋',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.fullName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                      _QuickFilterChip(
                        icon: '📊',
                        label: "Strava",
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: '🕐',
                        label: "History",
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: '🏆',
                        label: "Trophies",
                        onTap: () {},
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
