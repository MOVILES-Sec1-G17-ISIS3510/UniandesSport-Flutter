import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniandessport_flutter/features/coach/presentation/viewmodels/coaches_view_model.dart';
import 'package:uniandessport_flutter/features/coach/presentation/widgets/coach_card.dart';

class CoachSearchDelegate extends SearchDelegate {

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = "";
            context.read<CoachesViewModel>().search("");
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    context.read<CoachesViewModel>().search(query);

    return Consumer<CoachesViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.coaches.isEmpty) {
          return const Center(child: Text("No se encontraron profesores"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.coaches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CoachCard(coach: vm.coaches[index]),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    context.read<CoachesViewModel>().search(query);

    return Consumer<CoachesViewModel>(
      builder: (context, vm, _) {
        if (vm.coaches.isEmpty) {
          return const Center(child: Text("Busca por nombre o deporte"));
        }

        return ListView.builder(
          itemCount: vm.coaches.length,
          itemBuilder: (context, index) {
            final coach = vm.coaches[index];
            return ListTile(
              leading: const Icon(Icons.sports),
              title: Text(coach.nombre ?? ""),
              subtitle: Text(coach.deporte ?? ""),
              onTap: () {
                query = coach.nombre ?? "";
                showResults(context);
              },
            );
          },
        );
      },
    );
  }
}
