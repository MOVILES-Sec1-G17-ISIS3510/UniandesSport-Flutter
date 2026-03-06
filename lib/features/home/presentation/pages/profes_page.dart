import 'package:flutter/material.dart';

class ProfesPage extends StatelessWidget {
  const ProfesPage({super.key});

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
                  'APRENDE CON EXPERTOS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Profesores',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // Filter tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Coaches'),
                        selected: true,
                        onSelected: (selected) {
                          // TODO: Implementar filtro de entrenadores
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Soccer'),
                        selected: false,
                        onSelected: (selected) {
                          // TODO: Implementar filtro por deporte
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Tennis'),
                        selected: false,
                        onSelected: (selected) {
                          // TODO: Implementar filtro por deporte
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Basketball'),
                        selected: false,
                        onSelected: (selected) {
                          // TODO: Implementar filtro por deporte
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Coach cards
                _CoachCard(
                  initials: 'CM',
                  name: 'Carlos Mendez',
                  sport: 'Soccer',
                  price: '\$30/hour',
                  rating: 4.8,
                  reviews: 24,
                  experience: '8 years exp.',
                  ranking: '#1 in Soccer',
                  specialty: 'Technical skills & tactics',
                  verified: true,
                ),
                const SizedBox(height: 16),
                _CoachCard(
                  initials: 'AR',
                  name: 'Ana Rodriguez',
                  sport: 'Tennis',
                  price: '\$35/hour',
                  rating: 4.9,
                  reviews: 18,
                  experience: '10 years exp.',
                  ranking: '#1 in Tennis',
                  specialty: 'Professional coaching',
                  verified: true,
                ),
                const SizedBox(height: 16),
                _CoachCard(
                  initials: 'JG',
                  name: 'Juan García',
                  sport: 'Running',
                  price: '\$25/hour',
                  rating: 4.6,
                  reviews: 15,
                  experience: '6 years exp.',
                  ranking: '#3 in Running',
                  specialty: 'Marathon preparation',
                  verified: false,
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

class _CoachCard extends StatelessWidget {
  final String initials;
  final String name;
  final String sport;
  final String price;
  final double rating;
  final int reviews;
  final String experience;
  final String ranking;
  final String specialty;
  final bool verified;

  const _CoachCard({
    required this.initials,
    required this.name,
    required this.sport,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.experience,
    required this.ranking,
    required this.specialty,
    required this.verified,
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
              CircleAvatar(
                backgroundColor: Colors.teal[100],
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sport • $price',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        rating.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reviews reviews',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(experience, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 16),
              const Icon(Icons.emoji_events, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(ranking, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Specialty: $specialty',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Navegar al perfil del entrenador
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                  ),
                  child: const Text('View Profile'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () {
                    // TODO: Implementar llamada al entrenador
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
