import 'package:hive/hive.dart';
import '../models/timeslot_model.dart';

class TimeslotHiveService {
  static const String boxName = 'timeslotsBox';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TimeslotModelAdapter());
    }
    await Hive.openBox<TimeslotModel>(boxName);
  }

  Box<TimeslotModel> get _box => Hive.box<TimeslotModel>(boxName);

  List<TimeslotModel> getTimeslots() {
    return _box.values.toList();
  }

  void saveTimeslot(TimeslotModel timeslot) {
    _box.put(timeslot.id, timeslot);
  }

  void deleteTimeslot(String id) {
    _box.delete(id);
  }
}
