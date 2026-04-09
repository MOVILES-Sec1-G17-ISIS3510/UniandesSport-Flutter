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
  String? _customSport; // Solo un deporte personalizado a la vez

  List<String> get _visibleSports {
    final keys = [...AppSports.sportKeys];
    if (_customSport != null) {
      keys.add(_customSport!);
    }
    return _isExpanded ? keys : keys.take(3).toList();
  }

  Future<void> _showAddSportDialog() async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add sport'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the sport name:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ex: Volleyball',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Solo permitir letras y espacios
                  final filtered = value.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'), '');
                  if (filtered != value) {
                    controller.text = filtered;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: filtered.length),
                    );
                  }
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                maxLength: 30,
              ),
              const SizedBox(height: 8),
              Text(
                'Only letters and spaces are allowed. Numbers and special characters are not allowed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setDialogState(() => errorText = 'Enter a sport');
                  return;
                }
                if (text.length < 3) {
                  setDialogState(() => errorText = 'It must contain at least 3 letters');
                  return;
                }
                Navigator.of(context).pop(text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Normalizar: quitar espacios y pasar a minúsculas
      final normalized = result.toLowerCase().replaceAll(' ', '');

      setState(() {
        // Sobreescribe el deporte personalizado anterior
        _customSport = normalized;
        widget.onSportSelected(normalized);
        _isExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your sport',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._visibleSports.map((key) {
              // Si es un deporte predefinido, usa AppSports
              // Si es personalizado, usa color gris e ícono de add
              final bool isCustom = !AppSports.sportKeys.contains(key);
              final sport = isCustom
                  ? SportStyle(
                      name: key.substring(0, 1).toUpperCase() + key.substring(1),
                      color: Colors.grey[600]!,
                      icon: Icons.add_circle_outline,
                    )
                  : AppSports.getSport(key);
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
                onTap: _showAddSportDialog,
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
                  'Sport selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isExpanded = true),
                  child: Text(
                    'Change',
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
              'See more',
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
              'Add',
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

