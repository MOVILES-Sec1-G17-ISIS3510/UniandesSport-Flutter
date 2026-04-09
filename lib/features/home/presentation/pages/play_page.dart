import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../domain/models/sport_event.dart';
import '../controllers/play_view_model.dart';
import '../widgets/action_buttons_section.dart';
import '../widgets/event_card.dart';
import '../widgets/modality_selector.dart';
import '../widgets/sport_selector.dart';
import 'create_casual_event_page.dart';
import 'event_registration_result_page.dart';

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
                      vm.showMyScheduled ? Icons.event_available : Icons.calendar_month,
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
                        color: vm.showMyScheduled ? AppTheme.navy : AppTheme.teal,
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

class _MyScheduledSection extends StatelessWidget {
  final PlayViewModel vm;

  const _MyScheduledSection({required this.vm});

  Future<void> _openEventDetails(BuildContext context, SportEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool isLeaving = false;

        Future<void> handleLeave(StateSetter setSheetState) async {
          final confirm = await showDialog<bool>(
            context: sheetContext,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Leave event?'),
              content: const Text(
                'Are you sure you want to leave this event? You will be removed from the participant list.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );

          if (confirm != true) return;

          setSheetState(() => isLeaving = true);
          final success = await context.read<PlayViewModel>().leaveScheduledEvent(event);
          if (!sheetContext.mounted) return;

          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'You left the event successfully' : 'Could not leave the event',
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.softTeal,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Registered',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppSports.formatSportLabel(event.sport)} • ${event.modality.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(icon: Icons.people, label: 'Participants', value: '${event.currentParticipants}/${event.maxParticipants}'),
                  const SizedBox(height: 8),
                  _DetailRow(icon: Icons.schedule, label: 'Schedule', value: vm.formatSchedule(event.scheduledAt)),
                  const SizedBox(height: 8),
                  _DetailRow(icon: Icons.location_on, label: 'Location', value: event.location),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(event.description, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.navy),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLeaving
                              ? null
                              : () => handleLeave(setSheetState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isLeaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Leave event'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (vm.isLoadingMyScheduled) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.myScheduledError != null) {
      return _ErrorBox(error: vm.myScheduledError!);
    }

    if (vm.myScheduledEvents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'You do not have active scheduled events yet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${vm.myScheduledEvents.length} active event${vm.myScheduledEvents.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        ...vm.myScheduledEvents.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openEventDetails(context, event),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6EBF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.modality.label} • ${event.currentParticipants}/${event.maxParticipants}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vm.formatSchedule(event.scheduledAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.navy),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
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
