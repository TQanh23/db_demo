import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class SqliteService {
  static Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final path = join(await getDatabasesPath(), 'hybrid_todos_v2.db');
    _db = await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
        );
        await db.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, isCompleted INTEGER, created TEXT)',
        );
        // Table cho tính năng Audit Log
        await db.execute(
          'CREATE TABLE logs(id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, time TEXT)',
        );
      },
      version: 1,
    );
    
    if ((await getCategories()).isEmpty) {
      await addCategory('Học tập');
      await addCategory('Cá nhân');
    }
  }

  // --- Category ---
  Future<void> addCategory(String name) async {
    await _db?.insert('categories', {'name': name}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    return await _db?.query('categories') ?? [];
  }

  // --- Audit Logs (SQL Feature Demo) ---
  Future<void> logAction(String action) async {
    await _db?.insert('logs', {
      'action': action,
      'time': DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getRecentLogs() async {
    if (_db == null) return [];
    return await _db!.rawQuery('SELECT * FROM logs ORDER BY id DESC LIMIT 20');
  }

  // --- Tasks CRUD ---
  Future<void> addTask(String title) async {
    await _db?.insert('tasks', {
      'title': title,
      'isCompleted': 0, 
      'created': DateTime.now().toIso8601String(),
    });
  }

  // 2. Read (Future)
  Future<List<Map<String, dynamic>>> getTasks() async {
    return await _db?.query('tasks', orderBy: 'created DESC') ?? [];
  }

  // 3. Update
  Future<void> toggleComplete(int id, int currentStatus) async {
    await _db?.update(
      'tasks', 
      {'isCompleted': currentStatus == 0 ? 1 : 0},
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  // 4. Delete
  Future<void> deleteTask(int id) async {
    await _db?.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
