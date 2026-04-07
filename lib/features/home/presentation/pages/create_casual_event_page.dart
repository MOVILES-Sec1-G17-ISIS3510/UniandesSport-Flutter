import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../data/events_repository.dart';
import '../../domain/models/event_modality.dart';
import 'event_creation_result_page.dart';

class CreateCasualEventPage extends StatefulWidget {
  const CreateCasualEventPage({
    super.key,
    required this.profile,
    required this.sport,
  });

  final UserProfile profile;
  final String sport;

  @override
  State<CreateCasualEventPage> createState() => _CreateCasualEventPageState();
}

class _CreateCasualEventPageState extends State<CreateCasualEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '10');
  final _repository = EventsRepository.instance;

  DateTime? _scheduledAt;
  bool _isSubmitting = false;

  String get _displaySportName {
    if (AppSports.sportKeys.contains(widget.sport)) {
      return AppSports.getSport(widget.sport).name;
    }
    // Capitalizar la primera letra para deportes personalizados
    return widget.sport.substring(0, 1).toUpperCase() + widget.sport.substring(1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora del evento')),
      );
      return;
    }

    if (widget.profile.semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tener semestre registrado en tu perfil para crear eventos'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.createEvent(
        createdBy: widget.profile.uid,
        creatorSemester: widget.profile.semester!,
        title: _titleController.text.trim(),
        sport: widget.sport,
        modality: EventModality.casual,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        scheduledAt: _scheduledAt!,
        maxParticipants: int.parse(_maxParticipantsController.text.trim()),
      );

      if (!mounted) return;
      final goHome = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const EventCreationResultPage(
            isSuccess: true,
            message: 'Partida casual creada con exito',
          ),
        ),
      );

      if (!mounted) return;
      if (goHome == true) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message =
          e.code == 'permission-denied' ? 'No tienes permiso para crear esta partida' : 'Error al crear partida: ${e.message}';

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EventCreationResultPage(
            isSuccess: false,
            message: message,
          ),
        ),
      );
      // En fallo vuelve al formulario automaticamente para reintentar.
    } catch (e) {
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EventCreationResultPage(
            isSuccess: false,
            message: 'Error al crear partida. Intenta nuevamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear partida casual'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa los datos de tu partida',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titulo de la partida'),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'Ingresa un titulo valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _displaySportName,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Deporte'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: 'Casual',
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Ubicacion'),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Ingresa una ubicacion valida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxParticipantsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximo de participantes'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 2) {
                      return 'Debe ser un numero mayor o igual a 2';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa una descripcion';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickDateTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _scheduledAt == null
                        ? 'Seleccionar fecha y hora'
                        : 'Fecha: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Crear partida casual'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

