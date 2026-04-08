/// PlayPage — View en el patrón MVVM.
///
/// Esta clase SOLO se encarga de dibujar la UI. Toda la lógica de negocio,
/// el estado y las llamadas al repositorio viven en [PlayViewModel].
///
/// Regla de oro: si un widget necesita "pensar", ese pensamiento va al ViewModel.
/// La View solo pregunta "¿qué muestro?" y llama métodos del ViewModel.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  // ─── Navegación (único rol de la View además de dibujar) ─────────────────

  Future<void> _handleSearch(BuildContext context, PlayViewModel vm) async {
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
    final message = result['message'] as String? ?? 'No se pudo completar la inscripción';

    final goToStart = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EventRegistrationResultPage(isSuccess: success, message: message),
      ),
    );

    if (!context.mounted) return;

    // Si el usuario pide volver al inicio, resetea búsqueda y navega a Home.
    if (goToStart == true) {
      vm.resetSearch();
      onGoHome?.call();
    }
  }

  Future<void> _openCreateForm(BuildContext context, PlayViewModel vm) async {
    if (!vm.canCreate || vm.selectedSport == null) return;

    final goHome = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateCasualEventPage(
          profile: profile,
          sport: vm.selectedSport!,
        ),
      ),
    );

    if (!context.mounted || goHome != true) return;

    vm.resetSearch();
    onGoHome?.call();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // context.watch: reconstruye el widget cada vez que el ViewModel notifica.
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
                  'Encuentra tu deporte',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                // La View pasa callbacks que llaman métodos del ViewModel.
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
                  onSearchPressed: () => _handleSearch(context, vm),
                  onCreatePressed: () => _openCreateForm(context, vm),
                ),
                const SizedBox(height: 16),
                Text(
                  'Eventos recomendados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aún no hay recomendaciones disponibles',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),
              ],
              if (vm.hasSearched) ...[
                _SearchResults(
                  vm: vm,
                  onBack: vm.resetSearch,
                  onJoin: (event) => _handleJoinEvent(context, vm, event),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Estados de carga, error y resultados.
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
            'Error al buscar eventos',
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
            'No hay eventos disponibles',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.teal),
          ),
          const SizedBox(height: 6),
          Text(
            'Intenta cambiar tu búsqueda o crea un evento',
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
          '${events.length} evento${events.length != 1 ? 's' : ''} '
          'encontrado${events.length != 1 ? 's' : ''}',
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

// ─── Widget privado: resultados de búsqueda ───────────────────────────────────
//
// Extraído para mantener el método build de PlayPage legible.
// Sigue siendo parte de la View — solo dibuja lo que el ViewModel expone.

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
          label: const Text('Volver'),
        ),
        const SizedBox(height: 12),
        Text(
          'RESULTADOS DE BÚSQUEDA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.teal,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Estados de carga, error y resultados.
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
            'Error al buscar eventos',
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
            'No hay eventos disponibles',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.teal),
          ),
          const SizedBox(height: 6),
          Text(
            'Intenta cambiar tu búsqueda o crea un evento',
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
          '${events.length} evento${events.length != 1 ? 's' : ''} encontrado${events.length != 1 ? 's' : ''}',
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
              participants: '${event.currentParticipants}/${event.maxParticipants}',
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
