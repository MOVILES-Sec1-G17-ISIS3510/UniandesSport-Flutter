// ...existing code...

import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// DatabaseHelper es un singleton en la capa `core`.
/// Responsable únicamente por acceso y esquema de la base de datos local.
/// No tiene lógica de UI ni de features específicas (cumple regla core).
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String _dbName = 'uniandes_sport.db';
  static const int _dbVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    // Tabla `events` para almacenar eventos simples localmente.
    await db.execute('''
      CREATE TABLE events(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        isSynced INTEGER NOT NULL
      )
    ''');

    // Tabla `play_events` para almacenar casual matches y otros eventos deportivos de Play.
    await db.execute('''
      CREATE TABLE play_events(
        id TEXT PRIMARY KEY,
        created_by TEXT NOT NULL,
        creator_semester INTEGER,
        title TEXT NOT NULL,
        sport TEXT NOT NULL,
        modality TEXT NOT NULL,
        description TEXT NOT NULL,
        location TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        max_participants INTEGER NOT NULL,
        participants_json TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL
      )
    ''');

    // Tabla `sync_queue` para controlar acciones pendientes de sincronización.
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT,
        action TEXT,
        payload TEXT,
        status TEXT,
        retry_count INTEGER,
        timestamp INTEGER
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS play_events(
          id TEXT PRIMARY KEY,
          created_by TEXT NOT NULL,
          creator_semester INTEGER,
          title TEXT NOT NULL,
          sport TEXT NOT NULL,
          modality TEXT NOT NULL,
          description TEXT NOT NULL,
          location TEXT NOT NULL,
          scheduled_at TEXT NOT NULL,
          max_participants INTEGER NOT NULL,
          participants_json TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_synced INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sync_queue ADD COLUMN payload TEXT');
    }
  }

  /// Métodos utilitarios para uso por repositorios y servicios.
  Future<int> insert(String table, Map<String, Object?> values, {ConflictAlgorithm? conflictAlgorithm}) async {
    final db = await database;
    return await db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(String table, Map<String, Object?> values, String where,
      List<Object?> whereArgs) async {
    final db = await database;
    return await db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<Object?> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, Object?>>> query(
      String table, {
        String? where,
        List<Object?>? whereArgs,
        String? orderBy,
      }) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  /// Ejecuta una transacción y reexpone la API de sqflite para operaciones atómicas.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction((txn) async => await action(txn));
  }

  /// Inserta múltiples filas usando Batch y opcionalmente reemplaza en conflicto.
  Future<void> batchInsert(String table, List<Map<String, Object?>> rows, {bool replaceOnConflict = true}) async {
    final db = await database;
    final batch = db.batch();

    for (final row in rows) {
      if (replaceOnConflict) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        batch.insert(table, row);
      }
    }

    await batch.commit(noResult: true);
  }
}
