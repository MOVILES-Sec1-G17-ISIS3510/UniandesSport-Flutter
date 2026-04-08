import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/events_repository.dart';
import '../../domain/models/sport_event.dart';

class RecommendedEventsSection extends StatefulWidget {
  final String userId;

  const RecommendedEventsSection({super.key, required this.userId});

  @override
  State<RecommendedEventsSection> createState() =>
      _RecommendedEventsSectionState();
}

class _RecommendedEventsSectionState extends State<RecommendedEventsSection> {
  final EventsRepository _repository = EventsRepository.instance;
  late Future<List<SportEvent>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getRecommendedEvents(widget.userId, limit: 10);
  }

  @override
  void didUpdateWidget(covariant RecommendedEventsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _future = _repository.getRecommendedEvents(widget.userId, limit: 10);
    }
  }

  Future<void> _refreshRecommendations() async {
    setState(() {
      _future = _repository.getRecommendedEvents(widget.userId, limit: 10);
    });
  }

  Future<void> _openEventDetails(SportEvent event) async {
    bool isJoining = false;
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppSports.formatSportLabel(event.sport)} • ${event.modality.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.location,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha: ${_formatDate(event.scheduledAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cupos disponibles: ${event.availableSpots}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isJoining
                          ? null
                          : () async {
                              setSheetState(() => isJoining = true);
                              final result = await _repository
                                  .registerUserInEventWithMessage(
                                    eventId: event.id,
                                    userId: widget.userId,
                                  );
                              if (!mounted) return;

                              Navigator.of(sheetContext).pop();

                              final success = result['success'] as bool;
                              final message = result['message'] as String;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));

                              if (success) {
                                await _refreshRecommendations();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                      ),
                      child: isJoining
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Unirme'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    const weekdays = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SportEvent>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            'No se pudieron cargar las recomendaciones',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Text(
            'Aun no hay recomendaciones para ti',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        // Restaura el ancho previo (2 tarjetas visibles).
        final cardWidth = (screenWidth - 16 * 2 - 12) / 2;

        return SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              final sportLabel = AppSports.formatSportLabel(event.sport);
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openEventDetails(event),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            sportLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.teal,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      _formatDate(event.scheduledAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${event.availableSpots} cupos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
