import 'package:flutter/material.dart';

class TournamentsPage extends StatelessWidget {
  const TournamentsPage({super.key});

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
                        'Compete & Win 🏆',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'TOURNAMENTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Register, compete, and track live brackets',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // Sport filter chips
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SportFilterChip(label: 'All Sports', selected: true),
                        const SizedBox(width: 12),
                        _SportFilterChip(label: 'Soccer', selected: false),
                        const SizedBox(width: 12),
                        _SportFilterChip(label: 'Tennis', selected: false),
                        const SizedBox(width: 12),
                        _SportFilterChip(
                          label: 'Calisthenics',
                          selected: false,
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista de torneos
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _TournamentCard(
                          title: 'Copa Turing 2026',
                          sport: 'Soccer',
                          registrationStatus: 'OPEN',
                          startDate: 'Feb 10, 2026',
                          participants: '16 Teams',
                          location: 'UniAndes Courts',
                          progress: 0.75,
                          progressLabel: '12/16 Teams',
                          prize: '\$500,000 Prize Pool',
                        ),
                        const SizedBox(height: 16),
                        _TournamentCard(
                          title: 'Tennis Open Spring',
                          sport: 'Tennis',
                          registrationStatus: 'OPEN',
                          startDate: 'Feb 20, 2026',
                          participants: '32 Players',
                          location: 'Tennis Center',
                          progress: 0.40,
                          progressLabel: '13/32 Players',
                          prize: '\$250,000 Prize Pool',
                        ),
                        const SizedBox(height: 16),
                        _TournamentCard(
                          title: 'Calisthenics Championship',
                          sport: 'Calisthenics',
                          registrationStatus: 'COMING SOON',
                          startDate: 'Mar 5, 2026',
                          participants: '24 Athletes',
                          location: 'Outdoor Gym',
                          progress: 0.0,
                          progressLabel: 'Registration opens Feb 15',
                          prize: '\$150,000 Prize Pool',
                        ),
                        const SizedBox(height: 16),
                        _TournamentCard(
                          title: 'Basketball 3v3 League',
                          sport: 'Basketball',
                          registrationStatus: 'OPEN',
                          startDate: 'Feb 25, 2026',
                          participants: '12 Teams',
                          location: 'Sports Complex',
                          progress: 0.58,
                          progressLabel: '7/12 Teams',
                          prize: '\$300,000 Prize Pool',
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SportFilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _SportFilterChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1E3A8A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? const Color(0xFF1E3A8A) : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final String title;
  final String sport;
  final String registrationStatus;
  final String startDate;
  final String participants;
  final String location;
  final double progress;
  final String progressLabel;
  final String prize;

  const _TournamentCard({
    required this.title,
    required this.sport,
    required this.registrationStatus,
    required this.startDate,
    required this.participants,
    required this.location,
    required this.progress,
    required this.progressLabel,
    required this.prize,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = registrationStatus == 'OPEN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sport,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFF0C8E8B).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  registrationStatus,
                  style: TextStyle(
                    color: isOpen ? const Color(0xFF0C8E8B) : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Detalles del torneo
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Start Date',
            value: startDate,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.people_outline,
            label: 'Participants',
            value: participants,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: location,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.emoji_events_outlined,
            label: 'Prize',
            value: prize,
          ),
          const SizedBox(height: 20),

          // Barra de progreso
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progressLabel,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 8),
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
            ],
          ),
          const SizedBox(height: 20),

          // Botón de registro
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isOpen ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOpen ? const Color(0xFF1E3A8A) : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isOpen ? 'REGISTER NOW' : 'COMING SOON',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0C8E8B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
