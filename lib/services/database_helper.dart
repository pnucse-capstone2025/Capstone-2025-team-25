// lib/services/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';

class DatabaseHelper {
  static const _databaseName = "TaskDatabase.db";
  static const _databaseVersion = 1;

  static const table = 'tasks';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        sender_display_name TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        valid_until TEXT,
        start_date TEXT,
        is_medication INTEGER NOT NULL,
        rule_json TEXT,
        completed_occurrences INTEGER NOT NULL DEFAULT 0,
        total_days_completed INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
      ''');
  }

  Future<void> insertOrUpdateTask(Map<String, dynamic> task) async {
    try {
      final db = await instance.database;
      await db.insert(
        table,
        task,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error inserting/updating task: $e');
      }
    }
  }

  Future<void> deleteTask(String uuid) async {
    final db = await instance.database;
    await db.delete(table, where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<List<AppTask>> getAllTasks() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(table);

    if (maps.isEmpty) {
      return [];
    }

    return List.generate(maps.length, (i) {
      return AppTask.fromDbMap(maps[i]);
    });
  }

  Future<void> clearTasks() async {
    final db = await instance.database;
    await db.delete(table);
  }


  Future<void> localCreateTask(Map<String, dynamic> task) async {
    await insertOrUpdateTask(task);
  }

  Future<void> localUpdateTask(Map<String, dynamic> task) async {
    await insertOrUpdateTask(task);
  }

  Future<List<AppTask>> getUnsyncedTasks() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (maps.isEmpty) {
      return [];
    }

    return List.generate(maps.length, (i) {
      return AppTask.fromDbMap(maps[i]);
    });
  }
}
