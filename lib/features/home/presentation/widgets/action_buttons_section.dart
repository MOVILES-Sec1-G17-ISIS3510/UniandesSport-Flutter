import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ActionButtonsSection extends StatelessWidget {
  final bool canSearch;
  final bool canCreate;
  final VoidCallback onSearchPressed;
  final VoidCallback onCreatePressed;

  const ActionButtonsSection({
    super.key,
    required this.canSearch,
    required this.canCreate,
    required this.onSearchPressed,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botón buscar (3/4 del espacio)
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: canSearch ? onSearchPressed : null,
            icon: const Icon(Icons.search),
            label: const Text('Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSearch ? AppTheme.teal : Colors.grey[300],
              foregroundColor: canSearch ? Colors.white : Colors.grey[500],
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Botón crear (1/4 del espacio)
        Expanded(
          flex: 1,
          child: ElevatedButton(
            onPressed: canCreate ? onCreatePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canCreate ? AppTheme.teal : Colors.grey[300],
              foregroundColor: canCreate ? Colors.white : Colors.grey[500],
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
