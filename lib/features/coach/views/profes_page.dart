import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniandessport_flutter/features/coach/widgets/request_coach_dialog.dart';
import 'package:uniandessport_flutter/features/coach/viewmodels/coaches_view_model.dart';
import 'package:uniandessport_flutter/features/coach/widgets/coach_card.dart';
import 'package:uniandessport_flutter/features/coach/widgets/search_delegate.dart';

class ProfesPage extends StatefulWidget {
  const ProfesPage({super.key});

  @override
  State<ProfesPage> createState() => _ProfesPageState();
}

class _ProfesPageState extends State<ProfesPage> {
  final List<String> sports = ["All Coaches", "Soccer", "Tennis", "Basketball"];

  void _showFiltersSheet(BuildContext context, CoachesViewModel vm) {
    double tempMinRating = vm.minRating;
    double tempMaxPrice = vm.maxPrice;
    bool tempOnlyVerified = vm.onlyVerified;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Minimum Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Minimum Rating',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              size: 18,
                              color: i < tempMinRating.round()
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempMinRating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Colors.teal,
                      label: tempMinRating.toStringAsFixed(0),
                      onChanged: (val) =>
                          setSheetState(() => tempMinRating = val),
                    ),

                    const SizedBox(height: 8),

                    // Max Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Max Price',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '\$${tempMaxPrice.toInt()}/hr',
                          style: const TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempMaxPrice,
                      min: 0,
                      max: 50,
                      divisions: 10,
                      activeColor: Colors.teal,
                      label: '\$${tempMaxPrice.toInt()}',
                      onChanged: (val) =>
                          setSheetState(() => tempMaxPrice = val),
                    ),

                    const SizedBox(height: 8),

                    // Only Verified
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Text('Only verified coaches',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Switch(
                          value: tempOnlyVerified,
                          activeColor: Colors.teal,
                          onChanged: (val) =>
                              setSheetState(() => tempOnlyVerified = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              vm.resetAdvancedFilters();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              vm.applyAdvancedFilters(
                                minRating: tempMinRating,
                                maxPrice: tempMaxPrice,
                                onlyVerified: tempOnlyVerified,
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          boxShadow: const [
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
        child: Column(
          children: [
            // Banner offline
            Consumer<CoachesViewModel>(
              builder: (context, vm, _) {
                if (!vm.isOffline) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Colors.red.shade700,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.pendingReviewsCount > 0
                              ? "You're offline · ${vm.pendingReviewsCount} review(s) pending sync"
                              : "You're offline · Showing cached data",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Contenido principal
            Expanded(
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

                    // Titulo + iconos
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
                            Consumer<CoachesViewModel>(
                              builder: (context, vm, _) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: vm.hasActiveFilters
                                            ? Colors.teal.shade100
                                            : colorScheme
                                                .surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.tune,
                                          color: vm.hasActiveFilters
                                              ? Colors.teal
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        onPressed: () =>
                                            _showFiltersSheet(context, vm),
                                      ),
                                    ),
                                    if (vm.hasActiveFilters)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Chips de deporte
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
                                  checkmarkColor:
                                      colorScheme.onSecondaryContainer,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? colorScheme.onSecondaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (value) {
                                    vm.filterBySport(
                                        value ? sport : "All Coaches");
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Lista de coaches
                    Expanded(
                      child: Consumer<CoachesViewModel>(
                        builder: (context, vm, _) {
                          if (vm.isLoading) {
                            return const Center(
                                child: CircularProgressIndicator());
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

                          final coachOfTheMonth = vm.coachOfTheMonth;

                          return ListView.builder(
                            itemCount: vm.coaches.length +
                                (coachOfTheMonth != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == 0 && coachOfTheMonth != null) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD700),
                                              Color(0xFFFFA500)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.emoji_events,
                                                color: Colors.white,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              "Coach of the Month",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      CoachCard(coach: coachOfTheMonth),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                );
                              }

                              final coachIndex =
                                  coachOfTheMonth != null ? index - 1 : index;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: CoachCard(coach: vm.coaches[coachIndex]),
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
          ],
        ),
      ),
    );
  }
}
