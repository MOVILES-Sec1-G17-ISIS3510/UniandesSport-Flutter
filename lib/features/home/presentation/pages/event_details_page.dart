import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../data/events_repository.dart';
import '../../domain/models/sport_event.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;

  const EventDetailsPage({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final EventsRepository _repo = EventsRepository.instance;

  late Future<SportEvent?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getEventById(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: FutureBuilder<SportEvent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Could not load event: ${snapshot.error}'));
          }

          final event = snapshot.data;
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppSports.formatSportLabel(event.sport)} • ${event.modality.label}',
                ),
                const SizedBox(height: 8),
                Text('Location: ${event.location}'),
                const SizedBox(height: 8),
                Text('Date: ${event.scheduledAt}'),
                const SizedBox(height: 8),
                Text('Participants: ${event.currentParticipants}/${event.maxParticipants}'),
                const SizedBox(height: 14),
                Text(event.description),
              ],
            ),
          );
        },
      ),
    );
  }
}

