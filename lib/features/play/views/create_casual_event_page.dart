import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_sports.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/network/notification_service.dart';
import '../../auth/models/user_profile.dart';
import '../services/events_repository.dart';
import '../viewmodels/play_view_model.dart';
import '../models/event_modality.dart';
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
  final _sportController = TextEditingController();
  final _hourController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '10');
  final _repository = EventsRepository.instance;

  static final RegExp _hourFormatRegex = RegExp(r'^(?:[0-9]|[0-1]\d|2[0-3]):[0-5]\d$');

  DateTime? _scheduledAt;
  bool _isSubmitting = false;
  bool _draftApplied = false;

  String get _displaySportName {
    if (AppSports.sportKeys.contains(widget.sport)) {
      return AppSports.getSport(widget.sport).name;
    }
    // Capitalizar la primera letra para deportes personalizados
    return widget.sport.substring(0, 1).toUpperCase() +
        widget.sport.substring(1);
  }

  @override
  void initState() {
    super.initState();

    _sportController.text = _displaySportName;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_draftApplied) return;
    _draftApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final draft = Map<String, dynamic>.from(args);
    final draftLocation = (draft['lugar'] ?? '').toString().trim();
    final draftHour = (draft['hora_inicio'] ?? '').toString().trim();

    if (draftLocation.isNotEmpty) {
      _locationController.text = draftLocation;
    }

    if (draftHour.isNotEmpty) {
      final normalizedDraftHour = _normalizeHourText(draftHour) ?? draftHour;
      _hourController.text = normalizedDraftHour;
      _scheduledAt = _scheduledAtFromHour(normalizedDraftHour);
    }
  }

  String? _normalizeHourText(String hourText) {
    final raw = hourText.trim();
    if (!_hourFormatRegex.hasMatch(raw)) return null;

    final parts = raw.split(':');
    if (parts.length != 2) return null;

    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1];
    return '$hour:$minute';
  }

  DateTime? _scheduledAtFromHour(String hourText) {
    final normalized = _normalizeHourText(hourText);
    if (normalized == null) return null;

    final parts = normalized.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();

    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sportController.dispose();
    _hourController.dispose();
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

    final rawHour = _hourController.text.trim();
    final normalizedHour = rawHour.isEmpty ? '' : (_normalizeHourText(rawHour) ?? rawHour);
    if (normalizedHour.isNotEmpty && normalizedHour != rawHour) {
      _hourController.text = normalizedHour;
      _hourController.selection = TextSelection.collapsed(offset: normalizedHour.length);
    }

    if (_scheduledAt == null && normalizedHour.isNotEmpty) {
      _scheduledAt = _scheduledAtFromHour(normalizedHour);
    }

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

      if (mounted) {
        // Refresca el schedule usando la cache local recién escrita.
        unawaited(
          context.read<PlayViewModel>().loadMyScheduled(forceRefresh: true),
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
                  controller: _sportController,
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
                  controller: _hourController,
                  decoration: const InputDecoration(labelText: 'Start hour (H:MM or HH:MM)'),
                  validator: (value) {
                    final raw = (value ?? '').trim();
                    if (raw.isEmpty) return null;
                    if (!_hourFormatRegex.hasMatch(raw)) {
                      return 'Use H:MM or HH:MM';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final normalized = _normalizeHourText(value);
                    if (normalized != null && normalized != value.trim()) {
                      _hourController.value = TextEditingValue(
                        text: normalized,
                        selection: TextSelection.collapsed(offset: normalized.length),
                      );
                    }
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
