import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';

class SportChip extends StatelessWidget {
  final String sportKey;
  final SportStyle sport;
  final bool isSelected;
  final VoidCallback onTap;

  const SportChip({
    super.key,
    required this.sportKey,
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.teal : sport.color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sport.icon,
              color: isSelected ? Colors.white : sport.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              sport.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? Colors.white : sport.color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
