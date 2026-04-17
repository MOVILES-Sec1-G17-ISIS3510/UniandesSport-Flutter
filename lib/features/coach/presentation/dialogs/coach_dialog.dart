import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uniandessport_flutter/core/theme/app_theme.dart';
import 'package:uniandessport_flutter/features/coach/domain/models/coach_model.dart';
import 'package:uniandessport_flutter/features/coach/presentation/dialogs/review_dialog.dart';
import 'package:uniandessport_flutter/features/coach/presentation/pages/coach_map_page.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachProfileDialog extends StatelessWidget {
  final Coach coach;

  const CoachProfileDialog({super.key, required this.coach});

  String _valueOrDefault(String? value, String defaultValue) {
    if (value == null || value.trim().isEmpty) return defaultValue;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final rating = coach.rating ?? 5;
    final totalReviews = coach.totalReviews ?? 0;
    final sessions = coach.sessionsDelivered ?? 0;
    final wins = coach.tournamentWins ?? 0;
    final rank = coach.rankInSport ?? 1;
    final totalCoaches = coach.totalCoachesInSport ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 350, maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _valueOrDefault(coach.nombre, "Coach"),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                /// RATING
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => Icon(
                        Icons.star,
                        color: index < rating ? Colors.amber : Colors.grey,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rating.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  "$totalReviews reviews",
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20),

                /// INFO GRID
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard(
                            "SPORT",
                            _valueOrDefault(coach.deporte, "Swimming"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard(
                            "PRICE",
                            _valueOrDefault(coach.precio, "\$40/hour"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard(
                            "EXPERIENCE",
                            _valueOrDefault(coach.experiencia, "12 years"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard(
                            "AVAILABILITY",
                            _valueOrDefault(
                              coach.disponibilidad,
                              "Daily 6-10 AM",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                _infoCard(
                  "SPECIALTY",
                  _valueOrDefault(
                    coach.especialidad,
                    "All strokes & endurance",
                  ),
                  full: true,
                ),

                const SizedBox(height: 20),

                /// PERFORMANCE
                Row(
                  children: const [
                    Icon(Icons.trending_up, color: Colors.teal),
                    SizedBox(width: 6),
                    Text(
                      "PERFORMANCE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _StatCard(sessions.toString(), "SESSIONS")),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(wins.toString(), "WINS")),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard("#$rank", "RANK")),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  "🏆 Ranked #$rank of $totalCoaches ${_valueOrDefault(coach.deporte, "Swimming")} coaches • ${coach.verified == true ? "Verified Athlete" : "Coach"}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () {
                    if (!isCoachMapsSdkSupported()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'El mapa está disponible en la app para Android e iOS.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                      return;
                    }
                    final nav = Navigator.of(context, rootNavigator: true);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute<void>(
                        builder: (_) => CoachMapPage(coach: coach),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, color: AppTheme.teal),
                  label: const Text(
                    'View on map',
                    style: TextStyle(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.teal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// REVIEWS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "REVIEWS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AddReviewDialog(
                            coachId: coach.id ?? '',
                            coachSport: coach.deporte ?? '',
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text("Add Review"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // StreamBuilder para mostrar reviews en tiempo real
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('profesores')
                      .doc(coach.id)
                      .collection('reviews')
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "No reviews yet. Be the first to review!",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final reviews = snapshot.data!.docs;

                    return Column(
                      children: reviews.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final reviewRating =
                            (data['rating'] as num?)?.toInt() ?? 5;
                        final userName =
                            (data['userName'] as String?)?.isNotEmpty == true
                            ? data['userName'] as String
                            : 'Anonymous';
                        final comment = data['comment'] as String? ?? '';
                        final imageUrl = data['imageUrl'] as String?;
                        final createdAt = data['createdAt'];
                        String dateStr = '';
                        if (createdAt is Timestamp) {
                          final date = createdAt.toDate();
                          dateStr =
                              "${_monthName(date.month)} ${date.day}, ${date.year}";
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _reviewCard(
                            userName,
                            dateStr,
                            comment,
                            reviewRating,
                            imageUrl: imageUrl,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),

                /// BOTONES Contact + Book Class
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          openWhatsApp('${coach.whatsapp}');
                        },
                        icon: const Icon(Icons.phone, color: Colors.teal),
                        label: const Text(
                          "Contact",
                          style: TextStyle(color: Colors.teal),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          openWhatsApp('${coach.whatsapp}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Book Class"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

// Widgets auxiliares
Widget _infoCard(String title, String value, {bool full = false}) {
  return Container(
    width: full ? double.infinity : 160,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B365D),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1B365D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _reviewCard(
  String name,
  String date,
  String review,
  int rating, {
  String? imageUrl,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star,
                  size: 14,
                  color: index < rating ? Colors.amber : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
        if (date.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
        if (review.isNotEmpty) ...[const SizedBox(height: 6), Text(review)],
        if (imageUrl != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 60,
                child: Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Future<void> openWhatsApp(String phone) async {
  final cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '');
  final url = Uri.parse("https://wa.me/$cleanPhone");
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
