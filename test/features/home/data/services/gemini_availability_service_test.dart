import 'package:flutter_test/flutter_test.dart';
import 'package:uniandessport_flutter/features/home/services/gemini_availability_service.dart';
import 'package:uniandessport_flutter/features/home/models/time_slot.dart';

void main() {
  group('GeminiAvailabilityService.parseTimeSlotsJson', () {
    test('parses a valid JSON array response', () {
      const response =
          '[{"dia":"Lunes","hora_inicio":"14:00","hora_fin":"16:00"}]';

      final slots = GeminiAvailabilityService.parseTimeSlotsJson(response);

      expect(slots, hasLength(1));
      expect(slots.first.dia, 'Lunes');
      expect(slots.first.horaInicio, '14:00');
      expect(slots.first.horaFin, '16:00');
    });

    test('parses markdown fenced JSON', () {
      const response =
          '```json\n[{"dia":"Martes","hora_inicio":"09:00","hora_fin":"11:00"}]\n```';

      final slots = GeminiAvailabilityService.parseTimeSlotsJson(response);

      expect(slots, hasLength(1));
      expect(slots.first.dia, 'Martes');
    });
  });

  group('TimeSlot', () {
    test('fromJson/toJson map keys match expected schema', () {
      final slot = TimeSlot.fromJson({
        'dia': 'Viernes',
        'hora_inicio': '10:00',
        'hora_fin': '12:00',
      });

      expect(slot.toJson(), {
        'dia': 'Viernes',
        'hora_inicio': '10:00',
        'hora_fin': '12:00',
      });
    });
  });
}

