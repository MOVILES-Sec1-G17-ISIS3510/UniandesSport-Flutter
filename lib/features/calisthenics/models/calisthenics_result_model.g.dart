// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calisthenics_result_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalisthenicsResultModelAdapter extends TypeAdapter<CalisthenicsResultModel> {
  @override
  final int typeId = 0;

  @override
  CalisthenicsResultModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalisthenicsResultModel(
      postureScore: fields[0] as int,
      postureAnalysis: fields[1] as String,
      feedback: fields[2] as String,
      recommendations: (fields[3] as List).cast<String>(),
      similarExercises: (fields[4] as List).cast<String>(),
      detectedExercise: fields[5] as String,
      riskAreas: (fields[6] as List).cast<String>(),
      tips: (fields[7] as List).cast<String>(),
      analyzedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CalisthenicsResultModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.postureScore)
      ..writeByte(1)
      ..write(obj.postureAnalysis)
      ..writeByte(2)
      ..write(obj.feedback)
      ..writeByte(3)
      ..write(obj.recommendations)
      ..writeByte(4)
      ..write(obj.similarExercises)
      ..writeByte(5)
      ..write(obj.detectedExercise)
      ..writeByte(6)
      ..write(obj.riskAreas)
      ..writeByte(7)
      ..write(obj.tips)
      ..writeByte(8)
      ..write(obj.analyzedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalisthenicsResultModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

