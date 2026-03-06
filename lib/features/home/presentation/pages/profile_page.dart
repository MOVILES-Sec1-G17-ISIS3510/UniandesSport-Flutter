import 'package:flutter/material.dart';

import '../../../auth/domain/models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  final UserProfile profile;

  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTab = 2; // 0=Rankings, 1=History, 2=Badges

  String get _initials {
    final parts = widget.profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'US';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header con gradiente azul
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Back button y dark mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.dark_mode_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          // TODO: Implementar modo oscuro
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nombre
                  Text(
                    widget.profile.fullName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Universidad
                  Text(
                    widget.profile.university ?? 'Universidad no especificada',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 4),

                  // Programa y semestre
                  Text(
                    '${widget.profile.semester ?? 0}th Semester — '
                    '${widget.profile.program ?? 'Programa no especificado'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Stats cards
                  Row(
                    children: const [
                      Expanded(
                        child: _MiniStatCard(label: 'MATCHES', value: '34'),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(label: 'WIN RATE', value: '66%'),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          label: 'AVG PACE',
                          value: '6:23\nMIN/KM',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(label: 'STREAK', value: '70'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Rankings',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'History',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'Badges',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildRankingsTab();
      case 1:
        return _buildHistoryTab();
      case 2:
        return _buildBadgesTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildRankingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMMUNITY RANKINGS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _CommunityRankCard(
            communityName: 'Running UniAndes',
            sport: 'Running',
            rank: 12,
            total: 67,
            progress: 0.82,
            topPercent: '18%',
          ),
          const SizedBox(height: 16),
          _CommunityRankCard(
            communityName: 'UniAndes Football Club',
            sport: 'Soccer',
            rank: 5,
            total: 48,
            progress: 0.90,
            topPercent: '10%',
          ),
          const SizedBox(height: 16),
          _CommunityRankCard(
            communityName: 'Calisthenics Crew',
            sport: 'Calisthenics',
            rank: 3,
            total: 29,
            progress: 0.90,
            topPercent: '10%',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH HISTORY',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _MatchHistoryCard(
            icon: Icons.sports_soccer,
            title: '5v5 Soccer',
            status: 'Won',
            statusColor: const Color(0xFF0C8E8B),
            detail: '4-2',
            date: 'Feb 24, 2026',
            opponent: 'vs Team Alpha',
          ),
          const SizedBox(height: 16),
          _MatchHistoryCard(
            icon: Icons.directions_run,
            title: '5K Campus Run',
            status: 'Completed',
            statusColor: const Color(0xFF3B82F6),
            detail: '24:15',
            date: 'Feb 22, 2026',
            opponent: '',
          ),
          const SizedBox(height: 16),
          _MatchHistoryCard(
            icon: Icons.sports_soccer,
            title: '5v5 Casual',
            status: 'Lost',
            statusColor: Colors.red,
            detail: '1-3',
            date: 'Feb 20, 2026',
            opponent: 'vs Team Beta',
          ),
          const SizedBox(height: 16),
          _MatchHistoryCard(
            icon: Icons.fitness_center,
            title: 'Push-up Challenge',
            status: 'Completed',
            statusColor: const Color(0xFF3B82F6),
            detail: '150 reps',
            date: 'Feb 18, 2026',
            opponent: '',
          ),
          const SizedBox(height: 16),
          _MatchHistoryCard(
            icon: Icons.sports_soccer,
            title: 'Copa Turing R1',
            status: 'Won',
            statusColor: const Color(0xFF0C8E8B),
            detail: '3-1',
            date: 'Feb 15, 2026',
            opponent: 'vs Team Gamma',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EARNED BADGES',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '6/9',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0C8E8B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.75,
            children: [
              _BadgeCard(
                icon: Icons.sports_esports,
                title: 'First Match',
                description: 'Complete your first match',
                earned: true,
              ),
              _BadgeCard(
                icon: Icons.local_fire_department,
                title: '7-Day Streak',
                description: 'Stay active for 7 days straight',
                earned: true,
              ),
              _BadgeCard(
                icon: Icons.bolt,
                title: 'Speed Demon',
                description: 'Run 5K under 25 minutes',
                earned: true,
              ),
              _BadgeCard(
                icon: Icons.groups,
                title: 'Team Player',
                description: 'Join 3 communities',
                earned: true,
              ),
              _BadgeCard(
                icon: Icons.directions_run,
                title: '100K Runner',
                description: 'Run 100 km total',
                earned: false,
              ),
              _BadgeCard(
                icon: Icons.emoji_events,
                title: 'Tournament Champ',
                description: 'Win a tournament',
                earned: false,
              ),
              _BadgeCard(
                icon: Icons.star,
                title: 'Coach Rated',
                description: 'Rate a coaching session',
                earned: true,
              ),
              _BadgeCard(
                icon: Icons.verified,
                title: 'Challenge Creator',
                description: 'Create a community challenge',
                earned: false,
              ),
              _BadgeCard(
                icon: Icons.workspace_premium,
                title: 'Top 10',
                description: 'Reach Top 10 in any community',
                earned: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityRankCard extends StatelessWidget {
  final String communityName;
  final String sport;
  final int rank;
  final int total;
  final double progress;
  final String topPercent;

  const _CommunityRankCard({
    required this.communityName,
    required this.sport,
    required this.rank,
    required this.total,
    required this.progress,
    required this.topPercent,
  });

  @override
  Widget build(BuildContext context) {
    IconData sportIcon;
    switch (sport.toLowerCase()) {
      case 'running':
        sportIcon = Icons.directions_run;
        break;
      case 'soccer':
        sportIcon = Icons.sports_soccer;
        break;
      case 'calisthenics':
        sportIcon = Icons.fitness_center;
        break;
      default:
        sportIcon = Icons.sports;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F6F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(sportIcon, color: const Color(0xFF0C8E8B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      communityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sport,
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Text(
                    'of $total',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0C8E8B),
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Top $topPercent',
              style: const TextStyle(
                color: Color(0xFF0C8E8B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color statusColor;
  final String detail;
  final String date;
  final String opponent;

  const _MatchHistoryCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.detail,
    required this.date,
    required this.opponent,
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
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0C8E8B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      detail,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (opponent.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  opponent,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool earned;

  const _BadgeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: earned ? Colors.grey[200]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: earned ? const Color(0xFFE8F6F5) : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: earned ? const Color(0xFF0C8E8B) : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: earned ? Colors.black : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: earned ? Colors.grey[600] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
