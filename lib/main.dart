import 'package:flutter/material.dart';

import 'app.dart';

/// Entry point de la app.
///
/// WidgetsFlutterBinding.ensureInitialized() es obligatorio antes de inicializar
/// Firebase o cualquier plugin que use canales nativos.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniandesSportsApp());
}
