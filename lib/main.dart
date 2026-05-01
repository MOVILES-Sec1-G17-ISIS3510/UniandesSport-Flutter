import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/profile/services/timeslot_hive_service.dart';

import 'app.dart';

/// Entry point de la app.
///
/// WidgetsFlutterBinding.ensureInitialized() es obligatorio antes de inicializar
/// Firebase o cualquier plugin que use canales nativos.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await TimeslotHiveService().init();

  runApp(const UniandesSportsApp());
}
