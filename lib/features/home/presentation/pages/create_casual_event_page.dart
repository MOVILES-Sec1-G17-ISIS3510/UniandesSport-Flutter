import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_sports.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../data/events_repository.dart';
import '../../domain/entities/event_modality.dart';
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
    return widget.sport.substring(0, 1).toUpperCase() +
        widget.sport.substring(1);
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
        const SnackBar(content: Text('Select date and time for the event')),
      );
      return;
    }

    if (widget.profile.semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must have a semester registered in your profile to create events',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final eventId = await _repository.createEvent(
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

      // Disparamos una notificacion local para confirmar visualmente la creacion.
      // El tap queda trazado en backend mediante NotificationService.
      try {
        await NotificationService.instance.showEventCreatedNotification(
          notificationId: eventId,
          eventId: eventId,
          title: _titleController.text.trim(),
          sport: widget.sport,
          modality: EventModality.casual.code,
          userId: widget.profile.uid,
        );
      } catch (e) {
        debugPrint(
          '[CreateCasualEventPage] Error mostrando notificacion local: $e',
        );
      }

      if (!mounted) return;
      final goHome = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const EventCreationResultPage(
            isSuccess: true,
            message: 'Casual match created successfully',
          ),
        ),
      );

      if (!mounted) return;
      if (goHome == true) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'You do not have permission to create this match'
          : 'Error creating match: ${e.message}';

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              EventCreationResultPage(isSuccess: false, message: message),
        ),
      );
      // En fallo vuelve al formulario automaticamente para reintentar.
    } catch (e) {
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EventCreationResultPage(
            isSuccess: false,
            message: 'Error creating match. Please try again.',
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
      appBar: AppBar(title: const Text('Create casual match')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your match details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Match title'),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'Enter a valid title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _displaySportName,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Sport'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: 'Casual',
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Modality'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Enter a valid location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxParticipantsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum participants',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 2) {
                      return 'It must be a number greater than or equal to 2';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a description';
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
                        ? 'Select date and time'
                        : 'Date: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create casual match'),
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
