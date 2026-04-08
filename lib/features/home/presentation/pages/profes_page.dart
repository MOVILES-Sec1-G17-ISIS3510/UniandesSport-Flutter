import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniandessport_flutter/features/coach/presentation/dialogs/request_coach_dialog.dart';
import 'package:uniandessport_flutter/features/coach/presentation/viewmodels/coaches_view_model.dart';
import 'package:uniandessport_flutter/features/coach/presentation/widgets/coach_card.dart';
import 'package:uniandessport_flutter/features/coach/presentation/widgets/search_delegate.dart';

class ProfesPage extends StatefulWidget {
  const ProfesPage({super.key});

  @override
  State<ProfesPage> createState() => _ProfesPageState();
}

class _ProfesPageState extends State<ProfesPage> {
  final List<String> sports = ["All Coaches", "Soccer", "Tennis", "Basketball"];

  @override
  void initState() {
    super.initState();
    context.read<CoachesViewModel>().loadCoaches();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 30),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const RequestCoachDialog(),
            );
          },
        ),
      ),
      body: SafeArea(
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

              /// TITULO + ICONOS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profesores',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.search,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: CoachSearchDelegate(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.tune,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text("Filtros próximamente"),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Consumer<CoachesViewModel>(
                  builder: (context, vm, _) {
                    return Row(
                      children: sports.map((sport) {
                        final bool isSelected = vm.selectedSport == sport;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(sport),
                            selected: isSelected,
                            showCheckmark: true,
                            selectedColor: colorScheme.secondaryContainer,
                            checkmarkColor: colorScheme.onSecondaryContainer,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (value) {
                              vm.filterBySport(value ? sport : "All Coaches");
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Consumer<CoachesViewModel>(
                  builder: (context, vm, _) {
                    if (vm.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (vm.error != null) {
                      return Center(child: Text(vm.error!));
                    }

                    if (vm.coaches.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sports_handball_outlined,
                              size: 80,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Oops! No hay profes para este deporte.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Intenta con otro deporte o restablece el filtro.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: vm.coaches.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CoachCard(coach: vm.coaches[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
