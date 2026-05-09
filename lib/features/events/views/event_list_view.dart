import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/event_list_viewmodel.dart';
import '../models/event_model.dart';

class EventListView extends StatelessWidget {
  const EventListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EventListViewModel()..loadFirstPage(),
      child: const _EventListContent(),
    );
  }
}

class _EventListContent extends StatefulWidget {
  const _EventListContent();

  @override
  State<_EventListContent> createState() => _EventListContentState();
}

class _EventListContentState extends State<_EventListContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Calcular el 80% de la distancia máxima de scroll
    final threshold = _scrollController.position.maxScrollExtent * 0.8;
    
    if (_scrollController.position.pixels >= threshold) {
      // Trigger next page load
      context.read<EventListViewModel>().loadNextPage();
    }
  }

  void _onEventTapped(EventModel event) {
    // Al tocar un evento, buscarlo PRIMERO en el LRUCache para validar que L1 funciona.
    final viewModel = context.read<EventListViewModel>();
    final cachedEvent = viewModel.getEventById(event.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cachedEvent != null 
              ? 'L1 Cache Hit: ${cachedEvent.title}'
              : 'Miss: Loaded from list: ${event.title}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos Deportivos'),
      ),
      body: Consumer<EventListViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.events.isEmpty) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${viewModel.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.loadFirstPage(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('No hay eventos próximos.'));
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadFirstPage(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.events.length + (viewModel.hasMoreData ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // Si llegamos al final de la lista y hay más datos, mostrar loader
                if (index == viewModel.events.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final event = viewModel.events[index];
                final dateStr = _formatDate(event.date);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, 
                      vertical: 12,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.event,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _onEventTapped(event),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
