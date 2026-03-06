import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _showHistory = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your records 📊',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'HISTORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Matches and statistics',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
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
                          label: 'History',
                          isSelected: _showHistory,
                          onTap: () => setState(() => _showHistory = true),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          label: 'Statistics',
                          isSelected: !_showHistory,
                          onTap: () => setState(() => _showHistory = false),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: _showHistory
                      ? _buildHistoryView()
                      : _buildStatisticsView(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _MatchCard(
            result: 'VICTORY',
            resultColor: const Color(0xFF0C8E8B),
            title: '5v5 Soccer',
            date: 'Jan 28, 2026',
            team: 'Los Andes FC',
            opponent: 'Rosario United',
            location: 'UniAndes Courts',
          ),
          const SizedBox(height: 16),
          _MatchCard(
            result: 'DEFEAT',
            resultColor: Colors.red,
            title: 'Tennis Singles',
            date: 'Jan 25, 2026',
            team: 'Individual',
            opponent: 'Carlos M.',
            location: 'Tennis Center',
          ),
          const SizedBox(height: 16),
          _MatchCard(
            result: 'VICTORY',
            resultColor: const Color(0xFF0C8E8B),
            title: 'Basketball 3v3',
            date: 'Jan 22, 2026',
            team: 'Team Alpha',
            opponent: 'Team Beta',
            location: 'Sports Complex',
          ),
          const SizedBox(height: 16),
          _MatchCard(
            result: 'VICTORY',
            resultColor: const Color(0xFF0C8E8B),
            title: '5v5 Soccer',
            date: 'Jan 20, 2026',
            team: 'Los Andes FC',
            opponent: 'Javeriana FC',
            location: 'UniAndes Courts',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatisticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events,
                  value: '41',
                  label: 'TOTAL MATCHES',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.military_tech,
                  value: '63%',
                  label: 'WIN RATE',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // By Sport
          const Text(
            'BY SPORT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _SportStatsCard(
            sport: 'Soccer',
            matches: '12 matches',
            winRate: 0.58,
            wins: 7,
            losses: 3,
            draws: 2,
          ),
          const SizedBox(height: 16),
          _SportStatsCard(
            sport: 'Basketball',
            matches: '8 matches',
            winRate: 0.63,
            wins: 5,
            losses: 3,
            draws: 0,
          ),
          const SizedBox(height: 16),
          _SportStatsCard(
            sport: 'Tennis',
            matches: '15 matches',
            winRate: 0.67,
            wins: 10,
            losses: 5,
            draws: 0,
          ),
          const SizedBox(height: 32),

          // Monthly Trend
          Row(
            children: const [
              Icon(Icons.trending_up, color: Color(0xFF0C8E8B)),
              SizedBox(width: 8),
              Text(
                'MONTHLY TREND',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _WeekBar('Wk 1', 0.4),
                _WeekBar('Wk 2', 0.7),
                _WeekBar('Wk 3', 0.5),
                _WeekBar('Wk 4', 0.9),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Weekly activity for the last month',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),

          // Personal Records
          Row(
            children: const [
              Icon(Icons.stars, color: Color(0xFF0C8E8B)),
              SizedBox(width: 8),
              Text(
                'PERSONAL RECORDS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PersonalRecordItem(label: 'Win streak', value: '5 MATCHES'),
          const SizedBox(height: 12),
          _PersonalRecordItem(label: 'Matches in a month', value: '12 MATCHES'),
          const SizedBox(height: 12),
          _PersonalRecordItem(label: 'Most played sport', value: 'TENNIS'),
          const SizedBox(height: 20),
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

class _MatchCard extends StatelessWidget {
  final String result;
  final Color resultColor;
  final String title;
  final String date;
  final String team;
  final String opponent;
  final String location;

  const _MatchCard({
    required this.result,
    required this.resultColor,
    required this.title,
    required this.date,
    required this.team,
    required this.opponent,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result,
                  style: TextStyle(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Opponent',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opponent,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Location',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                location,
                style: const TextStyle(color: Color(0xFF0C8E8B), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0C8E8B), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SportStatsCard extends StatelessWidget {
  final String sport;
  final String matches;
  final double winRate;
  final int wins;
  final int losses;
  final int draws;

  const _SportStatsCard({
    required this.sport,
    required this.matches,
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.draws,
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
              Text(
                sport,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                matches,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Win Rate', style: TextStyle(fontSize: 14)),
              Text(
                '${(winRate * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: winRate,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0C8E8B),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultBox(
                  value: wins,
                  label: 'Wins',
                  color: const Color(0xFFE8F6F5),
                  textColor: const Color(0xFF0C8E8B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultBox(
                  value: losses,
                  label: 'Losses',
                  color: const Color(0xFFFFE8E8),
                  textColor: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultBox(
                  value: draws,
                  label: 'Draws',
                  color: const Color(0xFFF0F0F0),
                  textColor: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color textColor;

  const _ResultBox({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final String label;
  final double height;

  const _WeekBar(this.label, this.height);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 60 * height,
          decoration: BoxDecoration(
            color: const Color(0xFF0C8E8B),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _PersonalRecordItem extends StatelessWidget {
  final String label;
  final String value;

  const _PersonalRecordItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
