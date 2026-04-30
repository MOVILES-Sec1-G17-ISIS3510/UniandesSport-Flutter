import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../models/event_modality.dart';

class ModalitySelector extends StatelessWidget {
  final EventModality? selectedModality;
  final ValueChanged<EventModality?> onModalitySelected;

  const ModalitySelector({
    super.key,
    required this.selectedModality,
    required this.onModalitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your modality',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModalityButton(
                icon: Icons.sports_soccer,
                label: 'Casual',
                isSelected: selectedModality == EventModality.casual,
                onTap: () {
                  onModalitySelected(
                    selectedModality == EventModality.casual
                        ? null
                        : EventModality.casual,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModalityButton(
                icon: Icons.emoji_events,
                label: 'Tournament',
                isSelected: selectedModality == EventModality.tournament,
                onTap: () {
                  onModalitySelected(
                    selectedModality == EventModality.tournament
                        ? null
                        : EventModality.tournament,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModalityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModalityButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal : Colors.white,
          border: Border.all(color: AppTheme.teal, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.teal,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isSelected ? Colors.white : AppTheme.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
