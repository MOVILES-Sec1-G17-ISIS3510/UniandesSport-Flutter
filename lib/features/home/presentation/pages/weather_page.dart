import 'package:flutter/material.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Header con gradiente azul
                    Container(
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
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Plan your activities ☀️',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'WEATHER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Now in Bogotá',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '17°C',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.wb_sunny,
                                color: Colors.yellow,
                                size: 80,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _WeatherInfoCard(
                                icon: Icons.water_drop,
                                label: 'Rain',
                                value: '15%',
                              ),
                              _WeatherInfoCard(
                                icon: Icons.air,
                                label: 'Wind',
                                value: '12 km/h',
                              ),
                              _WeatherInfoCard(
                                icon: Icons.cloud,
                                label: 'Clouds',
                                value: '40%',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Contenido con padding
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Weather alert
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFE0B2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Color(0xFFFF9800),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Weather alert',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Rain probability increasing in the next hours. Consider indoor activities.',
                                        style: TextStyle(
                                          color: Color(0xFFE65100),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Hourly Forecast
                          const Text(
                            'HOURLY FORECAST',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _HourlyForecastCard(
                            icon: Icons.wb_sunny,
                            day: 'Today',
                            time: '3:00 PM',
                            temp: '18°',
                            rainChance: '10%',
                          ),
                          const SizedBox(height: 12),
                          _HourlyForecastCard(
                            icon: Icons.cloud,
                            day: 'Today',
                            time: '6:00 PM',
                            temp: '16°',
                            rainChance: '20%',
                          ),
                          const SizedBox(height: 12),
                          _HourlyForecastCard(
                            icon: Icons.cloud,
                            day: 'Tomorrow',
                            time: '10:00 AM',
                            temp: '17°',
                            rainChance: '45%',
                          ),
                          const SizedBox(height: 12),
                          _HourlyForecastCard(
                            icon: Icons.water_drop,
                            day: 'Tomorrow',
                            time: '3:00 PM',
                            temp: '19°',
                            rainChance: '65%',
                          ),
                          const SizedBox(height: 12),
                          _HourlyForecastCard(
                            icon: Icons.water_drop,
                            day: 'Day after',
                            time: '10:00 AM',
                            temp: '15°',
                            rainChance: '80%',
                          ),
                          const SizedBox(height: 12),
                          _HourlyForecastCard(
                            icon: Icons.water_drop,
                            day: 'Day after',
                            time: '3:00 PM',
                            temp: '16°',
                            rainChance: '55%',
                          ),
                          const SizedBox(height: 24),

                          // Best Times to Play
                          Row(
                            children: const [
                              Icon(Icons.event, color: Color(0xFF0C8E8B)),
                              SizedBox(width: 8),
                              Text(
                                'BEST TIMES TO PLAY',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _BestTimeCard(
                            time: 'Today 3:00 PM - 5:00 PM',
                            description: 'Low chance of rain',
                            icon: Icons.wb_sunny,
                          ),
                          const SizedBox(height: 12),
                          _BestTimeCard(
                            time: 'Tomorrow 9:00 AM - 11:00 AM',
                            description: 'Clear weather',
                            icon: Icons.wb_sunny,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Updated 15 minutes ago',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WeatherInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyForecastCard extends StatelessWidget {
  final IconData icon;
  final String day;
  final String time;
  final String temp;
  final String rainChance;

  const _HourlyForecastCard({
    required this.icon,
    required this.day,
    required this.time,
    required this.temp,
    required this.rainChance,
  });

  @override
  Widget build(BuildContext context) {
    final rainValue = int.parse(rainChance.replaceAll('%', '')) / 100;

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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0C8E8B), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                temp,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: rainValue,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C8E8B),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rainChance,
                    style: const TextStyle(
                      color: Color(0xFF0C8E8B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

class _BestTimeCard extends StatelessWidget {
  final String time;
  final String description;
  final IconData icon;

  const _BestTimeCard({
    required this.time,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(icon, color: const Color(0xFFFCD34D), size: 40),
        ],
      ),
    );
  }
}
