import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_theme.dart';
import '../../auth/models/user_profile.dart';
import '../models/sport_event.dart';
import '../viewmodels/play_view_model.dart';
import '../widgets/action_buttons_section.dart';
import '../widgets/event_card.dart';
import '../widgets/modality_selector.dart';
import '../widgets/sport_selector.dart';
import 'create_casual_event_page.dart';
import 'event_registration_result_page.dart';
import 'my_scheduled_events_page.dart';

class PlayPage extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onGoHome;

  const PlayPage({super.key, required this.profile, this.onGoHome});

  Future<void> _handleSearch(PlayViewModel vm) async {
    await vm.search();
  }

  Future<void> _handleJoinEvent(
    BuildContext context,
    PlayViewModel vm,
    SportEvent event,
  ) async {
    final result = await vm.joinEvent(event);
    if (!context.mounted) return;

    final success = result['success'] as bool? ?? false;
    final message =
        result['message'] as String? ?? 'Could not complete registration';

    final goToStart = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EventRegistrationResultPage(isSuccess: success, message: message),
      ),
    );

    if (!context.mounted) return;

    if (goToStart == true) {
      vm.resetSearch();
      onGoHome?.call();
    }
  }

  Future<void> _openCreateForm(BuildContext context, PlayViewModel vm) async {
    if (!vm.canCreate || vm.selectedSport == null) return;

    final goHome = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreateCasualEventPage(profile: profile, sport: vm.selectedSport!),
      ),
    );

    if (!context.mounted || goHome != true) return;

    vm.resetSearch();
    onGoHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlayViewModel>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const MyScheduledEventsPage(),
                      ),
                    );
                  },
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.navy,
                          AppTheme.teal,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Schedule',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'See your active events and leave any of them from one place.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!vm.hasSearched) ...[
                Text(
                  'Find your sport',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SportSelector(
                  selectedSport: vm.selectedSport,
                  onSportSelected: vm.selectSport,
                ),
                const SizedBox(height: 24),
                ModalitySelector(
                  selectedModality: vm.selectedModality,
                  onModalitySelected: vm.selectModality,
                ),
                const SizedBox(height: 24),
                ActionButtonsSection(
                  canSearch: vm.canSearch,
                  canCreate: vm.canCreate,
                  onSearchPressed: () => _handleSearch(vm),
                  onCreatePressed: () => _openCreateForm(context, vm),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: vm.toggleMyScheduled,
                    icon: Icon(
                      vm.showMyScheduled
                          ? Icons.event_available
                          : Icons.calendar_month,
                      color: AppTheme.navy,
                    ),
                    label: Text(
                      'My Schedule',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: vm.showMyScheduled
                            ? AppTheme.navy
                            : AppTheme.teal,
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (vm.showMyScheduled) ...[
                  const SizedBox(height: 12),
                  _MyScheduledSection(vm: vm),
                ],
                const SizedBox(height: 32),
              ],
              if (vm.hasSearched)
                _SearchResults(
                  vm: vm,
                  onBack: vm.resetSearch,
                  onJoin: (event) => _handleJoinEvent(context, vm, event),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final PlayViewModel vm;
  final VoidCallback onBack;
  final Future<void> Function(SportEvent) onJoin;

  const _SearchResults({
    required this.vm,
    required this.onBack,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
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
        if (vm.isSearching)
          const Center(child: CircularProgressIndicator())
        else if (vm.searchError != null)
          _ErrorBox(error: vm.searchError!)
        else if (vm.searchResults.isEmpty)
          const _EmptyResults()
        else
          _EventList(
            events: vm.searchResults,
            joiningEventId: vm.joiningEventId,
            formatSchedule: vm.formatSchedule,
            onJoin: onJoin,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;

  const _ErrorBox({required this.error});

  @override
  Widget build(BuildContext context) {
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(error, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.softTeal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, color: AppTheme.teal, size: 40),
          const SizedBox(height: 12),
          Text(
            'No events available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.teal),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing your search or create a new event',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<SportEvent> events;
  final String? joiningEventId;
  final String Function(DateTime) formatSchedule;
  final Future<void> Function(SportEvent) onJoin;

  const _EventList({
    required this.events,
    required this.joiningEventId,
    required this.formatSchedule,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${events.length} event${events.length != 1 ? 's' : ''} found',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventCard(
              title: event.title,
              sport: event.sport,
              modality: event.modality.label,
              participants:
                  '${event.currentParticipants}/${event.maxParticipants}',
              schedule: formatSchedule(event.scheduledAt),
              location: event.location,
              description: event.description,
              isJoining: joiningEventId == event.id,
              onJoinPressed: () => onJoin(event),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyScheduledSection extends StatelessWidget {
  const _MyScheduledSection({required this.vm});

  final PlayViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: AppTheme.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My scheduled events',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: vm.toggleMyScheduled,
                child: const Text('Hide'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              if (vm.isLoadingMyScheduled) {
                return const Center(child: CircularProgressIndicator());
              }

              if (vm.myScheduledError != null) {
                return Text(vm.myScheduledError!);
              }

              if (vm.myScheduledEvents.isEmpty) {
                return Text(
                  'You do not have active scheduled events yet.',
                  style: theme.textTheme.bodyMedium,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active events: ${vm.myScheduledEvents.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...vm.myScheduledEvents.take(3).map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.title),
                        subtitle: Text(vm.formatSchedule(event.scheduledAt)),
                        trailing: TextButton(
                          onPressed: () async {
                            await vm.leaveScheduledEvent(event);
                          },
                          child: const Text('Leave'),
                        ),
                      ),
                    ),
                  ),
                  if (vm.myScheduledEvents.length > 3)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MyScheduledEventsPage(),
                          ),
                        );
                      },
                      child: const Text('See all'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
