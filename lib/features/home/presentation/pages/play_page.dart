import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../data/events_repository.dart';
import '../../domain/models/event_modality.dart';
import '../../domain/models/sport_event.dart';
import '../widgets/action_buttons_section.dart';
import '../widgets/event_card.dart';
import '../widgets/modality_selector.dart';
import '../widgets/sport_selector.dart';
import 'create_casual_event_page.dart';
import 'event_registration_result_page.dart';

class PlayPage extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onGoHome;

  const PlayPage({super.key, required this.profile, this.onGoHome});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  String? _selectedSport;
  EventModality? _selectedModality;
  bool _hasSearched = false;
  final EventsRepository _eventsRepository = EventsRepository();
  Future<List<SportEvent>>? _searchFuture;
  String? _joiningEventId;

  bool get _canSearch => _selectedSport != null && _selectedModality != null;
  bool get _canCreate =>
      _canSearch && _selectedModality == EventModality.casual;

  /// Formats the date/time as "Today HH:MM PM", "Tomorrow HH:MM PM", etc.
  String _formatSchedule(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dayLabel;
    if (eventDate == today) {
      dayLabel = 'Today';
    } else if (eventDate == tomorrow) {
      dayLabel = 'Tomorrow';
    } else {
      dayLabel = '${eventDate.day}/${eventDate.month}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dayLabel ${displayHour}:$minute $period';
  }

  Future<void> _handleJoinEvent(SportEvent event) async {
    if (_joiningEventId != null) return;

    setState(() {
      _joiningEventId = event.id;
    });

    final result = await _eventsRepository.registerUserInEventWithMessage(
      eventId: event.id,
      userId: widget.profile.uid,
    );

    final success = result['success'] as bool;
    final message = result['message'] as String;

    if (!mounted) return;

    setState(() {
      _joiningEventId = null;
      if (success) {
        // Refresh list to show updated participant count.
        _searchFuture = _eventsRepository.searchEvents(
          sport: _selectedSport!,
          modality: _selectedModality!,
        );
      }
    });

    final goToStart = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EventRegistrationResultPage(isSuccess: success, message: message),
      ),
    );

    if (!mounted) return;

    if (goToStart == true) {
      setState(() {
        _hasSearched = false;
        _searchFuture = null;
      });
      return;
    }

    if (goToStart == false &&
        _selectedSport != null &&
        _selectedModality != null) {
      setState(() {
        // On failure, return to results and reload search.
        _searchFuture = _eventsRepository.searchEvents(
          sport: _selectedSport!,
          modality: _selectedModality!,
        );
      });
    }
  }

  Future<void> _openCreateCasualEventForm() async {
    if (!_canCreate || _selectedSport == null) return;

    final goHome = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateCasualEventPage(
          profile: widget.profile,
          sport: _selectedSport!,
        ),
      ),
    );

    if (!mounted || goHome != true) return;

    setState(() {
      _hasSearched = false;
      _searchFuture = null;
    });

    widget.onGoHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_hasSearched) ...[
                Text(
                  'Find your sport',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SportSelector(
                  selectedSport: _selectedSport,
                  onSportSelected: (sport) {
                    setState(() => _selectedSport = sport);
                  },
                ),
                const SizedBox(height: 24),
                ModalitySelector(
                  selectedModality: _selectedModality,
                  onModalitySelected: (modality) {
                    setState(() => _selectedModality = modality);
                  },
                ),
                const SizedBox(height: 24),
                ActionButtonsSection(
                  canSearch: _canSearch,
                  canCreate: _canCreate,
                  onSearchPressed: () {
                    if (!_canSearch) return;
                    setState(() {
                      _hasSearched = true;
                      _searchFuture = _eventsRepository.searchEvents(
                        sport: _selectedSport!,
                        modality: _selectedModality!,
                      );
                    });
                  },
                  onCreatePressed: _openCreateCasualEventForm,
                ),
                const SizedBox(height: 32),
              ],
              if (_hasSearched &&
                  _selectedSport != null &&
                  _selectedModality != null &&
                  _searchFuture != null) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasSearched = false;
                      _searchFuture = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                const SizedBox(height: 12),
                Text(
                  'SEARCH RESULTS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.teal,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<SportEvent>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Error searching events',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    final events = snapshot.data ?? [];
                    if (events.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.softTeal,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              color: AppTheme.teal,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No events available',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppTheme.teal),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try changing your search or create an event',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Text(
                          '${events.length} event${events.length != 1 ? 's' : ''} found',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(events.length, (index) {
                          final event = events[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: EventCard(
                              title: event.title,
                              sport: event.sport,
                              modality: event.modality.label,
                              participants:
                                  '${event.currentParticipants}/${event.maxParticipants}',
                              schedule: _formatSchedule(event.scheduledAt),
                              location: event.location,
                              description: event.description,
                              isJoining: _joiningEventId == event.id,
                              onJoinPressed: () => _handleJoinEvent(event),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
