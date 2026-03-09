import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';

class EventCard extends StatefulWidget {
  final String title;
  final String sport;
  final String modality;
  final String participants; // Ej: "7/10"
  final String schedule; // Ej: "Hoy 3:00 PM"
  final String location; // Ej: "UniAndes Courts"
  final String? description;
  final Future<void> Function()? onJoinPressed;
  final bool isJoining;

  const EventCard({
    super.key,
    required this.title,
    required this.sport,
    required this.modality,
    required this.participants,
    required this.schedule,
    required this.location,
    this.description,
    this.onJoinPressed,
    this.isJoining = false,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final sportStyle = AppSports.getSport(widget.sport);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isExpanded ? sportStyle.color : const Color(0xFFE6EBF2),
            width: _isExpanded ? 2 : 1,
          ),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: sportStyle.color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con logo, título y flecha
            Row(
              children: [
                // Logo del deporte
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sportStyle.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    sportStyle.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Título y etiqueta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sportStyle.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.modality,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: sportStyle.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicador de expansión
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.navy,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadatos (participantes, hora, ubicación)
            _EventMetadata(
              icon: Icons.people,
              text: widget.participants,
            ),
            const SizedBox(height: 8),
            _EventMetadata(
              icon: Icons.schedule,
              text: widget.schedule,
            ),
            const SizedBox(height: 8),
            _EventMetadata(
              icon: Icons.location_on,
              text: widget.location,
            ),

            // Descripción (solo cuando está expandido)
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Descripción',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description?.isNotEmpty == true
                    ? widget.description!
                    : 'Sin descripción disponible',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.description?.isNotEmpty == true
                      ? null
                      : Colors.grey[600],
                  fontStyle: widget.description?.isNotEmpty == true
                      ? null
                      : FontStyle.italic,
                ),
              ),
            ],

            // Botón de acción (solo cuando está expandido)
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.isJoining ? null : widget.onJoinPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: widget.isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Unirse'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventMetadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EventMetadata({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
        ),
      ],
    );
  }
}
