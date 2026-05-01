import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/profile/services/timeslot_hive_service.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/network/sync_engine_service.dart';

/// Entry point de la app.
///
/// WidgetsFlutterBinding.ensureInitialized() es obligatorio antes de inicializar
/// Firebase o cualquier plugin que use canales nativos.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await TimeslotHiveService().init();


  // Inicializar Firebase antes de usar Firestore en SyncEngineService
  await Firebase.initializeApp();

  // Inicializamos el SyncEngine para que empiece a escuchar cambios de conectividad
  // y pueda procesar la cola de sincronización.
  SyncEngineService().initialize();

  runApp(const UniandesSportsApp());
}
