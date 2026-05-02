import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/local_storage/database_helper.dart';
import '../models/time_slot.dart';
import '../services/voice_slots_extractor.dart';

class AvailableTimeSlotsPage extends StatefulWidget {
  final String userId;

  const AvailableTimeSlotsPage({super.key, required this.userId});

  @override
  State<AvailableTimeSlotsPage> createState() => _AvailableTimeSlotsPageState();
}

class _AvailableTimeSlotsPageState extends State<AvailableTimeSlotsPage> {
  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final VoiceSlotsExtractor _voiceExtractor = VoiceSlotsExtractor();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProcessingVoice = false;
  bool _isRecording = false;

  List<TimeSlot> _slots = const [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _voiceExtractor.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final rawSlots = data['free_time_slots'];

      if (rawSlots is List) {
        final loaded = rawSlots
            .whereType<Map<String, dynamic>>()
            .map(TimeSlot.fromJson)
            .map(_normalizeSlot)
            .toList();

        setState(() => _slots = loaded);
      } else {
        setState(() => _slots = const []);
      }
    } catch (e) {
      _showMessage('Could not load your time slots: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSlots() async {
    setState(() => _isSaving = true);

    try {
      // 1. Guardado Optimista: Disparamos a la caché de Firestore (fuego y olvido, SIN await)
      FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'free_time_slots': _slots.map((slot) => slot.toJson()).toList(),
      }, SetOptions(merge: true));

      // 2. Encolar en la base de datos local para el Sync Engine
      final dbHelper = DatabaseHelper();
      await dbHelper.insert('sync_queue', {
        'event_id': widget.userId,
        'action': 'SAVE_ALL_TIMESLOTS',
        'status': 'pending',
        'retry_count': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _showMessage('Time slots saved.');
    } catch (e) {
      _showMessage('Could not save time slots: $e');
    } finally {
      // 3. OBLIGATORIO: Liberar la UI de inmediato en el finally
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleVoiceAction() async {
    if (_isProcessingVoice) return;

    if (!_voiceExtractor.isSupported) {
      _showMessage('Voice input is not supported on this platform.');
      return;
    }

    try {
      if (_isRecording) {
        setState(() {
          _isProcessingVoice = true;
        });

        final extracted = await _voiceExtractor.stopAndExtract();
        final normalized = extracted.map(_normalizeSlot).toList();

        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessingVoice = false;
            _slots = _mergeSlots(_slots, normalized);
          });
        }

        _showMessage(
          normalized.isEmpty
              ? 'No time slots were extracted.'
              : '${normalized.length} slot(s) extracted. Review and save.',
        );
        return;
      }

      final hasPermission = await _voiceExtractor.ensurePermission();
      if (!hasPermission) {
        _showMessage('Microphone permission denied.');
        return;
      }

      await _voiceExtractor.startRecording();

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingVoice = false;
          _isRecording = false;
        });
      }
      _showMessage('Voice processing failed: $e');
    }
  }

  Future<void> _openManualAddDialog() async {
    String day = _weekDays.first;
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    final created = await showDialog<TimeSlot>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add time slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: day,
              decoration: const InputDecoration(labelText: 'Day'),
              items: _weekDays
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => day = value ?? _weekDays.first,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: startCtrl,
              decoration: const InputDecoration(
                labelText: 'Start (HH:MM)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: endCtrl,
              decoration: const InputDecoration(
                labelText: 'End (HH:MM)',
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
              final start = startCtrl.text.trim();
              final end = endCtrl.text.trim();

              if (!_isValidTime(start) || !_isValidTime(end)) {
                _showMessage('Please use HH:MM format.');
                return;
              }

              if (!_isStartBeforeEnd(start, end)) {
                _showMessage('Start time must be earlier than end time.');
                return;
              }

              Navigator.of(context).pop(
                TimeSlot(dia: day, horaInicio: start, horaFin: end),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == null || !mounted) return;

    setState(() {
      _slots = _mergeSlots(_slots, [_normalizeSlot(created)]);
    });
  }

  List<TimeSlot> _mergeSlots(List<TimeSlot> current, List<TimeSlot> incoming) {
    final map = <String, TimeSlot>{};

    for (final slot in [...current, ...incoming]) {
      final normalized = _normalizeSlot(slot);
      final key =
          '${normalized.dia}|${normalized.horaInicio}|${normalized.horaFin}';
      map[key] = normalized;
    }

    final merged = map.values.toList();
    merged.sort(_sortSlots);
    return merged;
  }

  int _sortSlots(TimeSlot a, TimeSlot b) {
    final dayCompare = _weekDays.indexOf(a.dia).compareTo(_weekDays.indexOf(b.dia));
    if (dayCompare != 0) return dayCompare;
    return a.horaInicio.compareTo(b.horaInicio);
  }

  TimeSlot _normalizeSlot(TimeSlot slot) {
    return TimeSlot(
      dia: _normalizeDay(slot.dia),
      horaInicio: slot.horaInicio,
      horaFin: slot.horaFin,
    );
  }

  String _normalizeDay(String rawDay) {
    final value = rawDay.trim().toLowerCase();

    const map = {
      'lunes': 'Monday',
      'martes': 'Tuesday',
      'miercoles': 'Wednesday',
      'miércoles': 'Wednesday',
      'jueves': 'Thursday',
      'viernes': 'Friday',
      'sabado': 'Saturday',
      'sábado': 'Saturday',
      'domingo': 'Sunday',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
    };

    return map[value] ?? rawDay;
  }

  bool _isValidTime(String value) {
    final regex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    return regex.hasMatch(value);
  }

  bool _isStartBeforeEnd(String start, String end) {
    final s = start.split(':');
    final e = end.split(':');
    final sMin = int.parse(s[0]) * 60 + int.parse(s[1]);
    final eMin = int.parse(e[0]) * 60 + int.parse(e[1]);
    return sMin < eMin;
  }

  void _deleteSlot(TimeSlot slot) {
    setState(() {
      _slots = _slots
          .where(
            (item) =>
                !(item.dia == slot.dia &&
                    item.horaInicio == slot.horaInicio &&
                    item.horaFin == slot.horaFin),
          )
          .toList();
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available time slots'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available time slots',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add slots manually or use the microphone so AI can generate them for you.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: _slots.isEmpty
                          ? const Text('No time slots yet.')
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _slots
                                  .map(
                                    (slot) => InputChip(
                                      label: Text(
                                        '${slot.dia} ${slot.horaInicio}-${slot.horaFin}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onDeleted: () => _deleteSlot(slot),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openManualAddDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add manually'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isProcessingVoice ? null : _handleVoiceAction,
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(
                            _isRecording ? 'Stop and process' : 'Use microphone',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isProcessingVoice)
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Processing voice with AI...'),
                        ],
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSlots,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save time slots'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

