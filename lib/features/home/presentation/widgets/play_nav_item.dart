import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PlayNavItem extends StatelessWidget {
  const PlayNavItem({
    super.key,
    required this.sportIcon,
    required this.isSelected,
  });

  final IconData sportIcon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final scale = isSelected ? 1.1 : 1.0;
    final verticalOffset = isSelected ? 0.0 : 3.0;

    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isSelected ? 32 : 30,
              height: isSelected ? 32 : 30,
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x33001845),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                sportIcon,
                color: Colors.white,
                size: isSelected ? 18 : 16,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: (labelStyle ?? const TextStyle()).copyWith(
                color: AppTheme.teal,
                fontSize: isSelected ? 13 : 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                shadows: isSelected
                    ? const [
                        Shadow(
                          color: Color(0x26001845),
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}

