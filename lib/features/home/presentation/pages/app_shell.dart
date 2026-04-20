import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../presentation/pages/retos_page.dart';
import '../../presentation/pages/play_page.dart';
import '../../presentation/pages/social_page.dart';
import '../../presentation/pages/profes_page.dart';
import '../../presentation/pages/profile_page.dart';
import '../viewmodels/play_view_model.dart';
import '../widgets/play_nav_item.dart';
import '../widgets/recommended_events_section.dart';
import '../widgets/smart_recommendation_section.dart';

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
  StreamSubscription<UserProfile?>? _profileSubscription;

  static const List<IconData> _playSportIcons = [
    Icons.sports_soccer,
    Icons.fitness_center,
    Icons.directions_run,
    Icons.sports_basketball,
    Icons.sports_tennis,
    Icons.pool,
    Icons.sports,
    Icons.sports_golf,
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _setupProfileListener();
    _startPlayIconRotation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlayViewModel>().updateProfile(_profile);
    });
  }

  @override
  void dispose() {
    _playSportTimer?.cancel();
    _profileSubscription?.cancel();
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
    _profileSubscription?.cancel();
    _profileSubscription = repository.userProfileChanges(_profile.uid).listen((
      profile,
    ) {
      if (profile == null || !mounted) {
        return;
      }

      final didProfileChange =
          profile.uid != _profile.uid ||
          profile.email != _profile.email ||
          profile.fullName != _profile.fullName ||
          profile.photoUrl != _profile.photoUrl ||
          profile.mainSport != _profile.mainSport ||
          profile.university != _profile.university ||
          profile.program != _profile.program ||
          profile.semester != _profile.semester ||
          profile.role != _profile.role ||
          !mapEquals(profile.inferredPreferences, _profile.inferredPreferences);

      if (!didProfileChange) {
        return;
      }

      setState(() {
        _profile = profile;
      });
      context.read<PlayViewModel>().updateProfile(profile);
    });
  }

  void _openProfilePage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilePage(profile: _profile)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          _buildPage(_selectedIndex),
          if (_selectedIndex != 4)
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              right: 14,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openProfilePage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.92,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.account_circle_outlined,
                      size: 28,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            label: 'Challenges',
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Social',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Coaches',
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
                Text(
                  'UNIANDES SPORTS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickFilterChip(
                        icon: '⛅',
                        label: '24° Cloudy',
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: '📊',
                        label: 'Strava',
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: '🕐',
                        label: 'History',
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _QuickFilterChip(
                        icon: '🏆',
                        label: 'Trophies',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SmartRecommendationSection(profile: profile),
                const SizedBox(height: 16),
                Text(
                  'RECOMMENDED EVENTS',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover options based on your preferences',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                RecommendedEventsSection(userId: profile.uid),
                const SizedBox(height: 32),
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
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.alphaBlend(
                Colors.black.withValues(alpha: 0.35),
                backgroundColor,
              )
            : backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return ChipTheme(
      data: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
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
                  color: colorScheme.surfaceContainerHighest,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
