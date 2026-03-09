import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';
import 'sport_chip.dart';

class SportSelector extends StatefulWidget {
  final String? selectedSport;
  final ValueChanged<String?> onSportSelected;

  const SportSelector({
    super.key,
    required this.selectedSport,
    required this.onSportSelected,
  });

  @override
  State<SportSelector> createState() => _SportSelectorState();
}

class _SportSelectorState extends State<SportSelector> {
  bool _isExpanded = false;

  List<String> get _visibleSports {
    final keys = AppSports.sportKeys;
    return _isExpanded ? keys : keys.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escoge tu deporte',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._visibleSports.map((key) {
              final sport = AppSports.getSport(key);
              return SportChip(
                sportKey: key,
                sport: sport,
                isSelected: widget.selectedSport == key,
                onTap: () {
                  widget.onSportSelected(key);
                  setState(() => _isExpanded = false);
                },
              );
            }),
            // Botón expandir
            if (!_isExpanded)
              _ExpandButton(
                onTap: () => setState(() => _isExpanded = true),
              ),
            // Opción agregar deporte
            if (_isExpanded)
              _AddSportButton(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidad en desarrollo'),
                    ),
                  );
                },
              ),
          ],
        ),
        // Check de confirmación
        if (widget.selectedSport != null && !_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.navy,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Deporte seleccionado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isExpanded = true),
                  child: Text(
                    'Cambiar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Colors.grey[400]!,
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.expand_more,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Ver más',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSportButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Colors.grey[400]!,
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Agregar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

