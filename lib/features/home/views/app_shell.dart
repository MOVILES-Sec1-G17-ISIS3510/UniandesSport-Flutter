import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/services/auth_repository.dart';
import '../../auth/models/user_profile.dart';
import '../../challenges/views/retos_page.dart';
import '../../play/views/play_page.dart';
import 'social_page.dart';
import '../../coach/views/profes_page.dart';
import '../../auth/views/profile_page.dart';
import '../../play/viewmodels/play_view_model.dart';
import '../../play/widgets/play_nav_item.dart';
import '../widgets/recommended_events_section.dart';
import '../widgets/smart_recommendation_section.dart';
import '../../calisthenics/presentation/pages/calisthenics_landing.dart';

class AppShell extends StatefulWidget {
  final UserProfile profile;
  final bool listenToProfileUpdates;

  const AppShell({
    super.key,
    required this.profile,
    this.listenToProfileUpdates = true,
  });

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
    if (widget.listenToProfileUpdates) {
      _setupProfileListener();
    }
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
    if (!widget.listenToProfileUpdates) return;

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
                _CalisthenicsAssistantCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CalisthenicsLandingScreen(),
                      ),
                    );
                  },
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
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.location,
    required this.duration,
    required this.match,
    required this.matchColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
        ),
      ),
    );
  }
}

class _CalisthenicsAssistantCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CalisthenicsAssistantCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFC62828)], // Red gradient, attractive but less luminous
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33C62828),
                blurRadius: 16,
                spreadRadius: 1,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0x66FFFFFF), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calisthenics AI Coach',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Analyze your posture with AI! (Only 1 per day)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PillChip(label: 'Instant feedback'),
                  _PillChip(label: 'Camera analysis'),
                  _PillChip(label: 'English results'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open assistant',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;

  const _PillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
