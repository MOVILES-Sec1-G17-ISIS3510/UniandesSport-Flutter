import 'package:hive/hive.dart';
import 'dart:convert';

part 'timeslot_model.g.dart';

// Recordatorio: Debes correr el siguiente comando para generar el adapter:
// flutter packages pub run build_runner build --delete-conflicting-outputs

@HiveType(typeId: 1)
class TimeslotModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String dayOfWeek;

  @HiveField(2)
  final String startTime;

  @HiveField(3)
  final String endTime;

  TimeslotModel({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TimeslotModel.fromMap(Map<String, dynamic> map) {
    return TimeslotModel(
      id: map['id'],
      dayOfWeek: map['dayOfWeek'],
      startTime: map['startTime'],
      endTime: map['endTime'],
    );
  }

  String toJson() => json.encode(toMap());

  factory TimeslotModel.fromJson(String source) =>
      TimeslotModel.fromMap(json.decode(source));
}
