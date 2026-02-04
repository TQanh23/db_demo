import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/benchmark_task.dart';
import 'hive_service.dart';
import 'isar_service.dart';
import 'sqlite_service.dart';

class BenchmarkService {
  final HiveService _hiveService;
  final IsarService _isarService;
  final SqliteService _sqliteService;

  BenchmarkService(this._hiveService, this._isarService, this._sqliteService);

  final Uuid _uuid = const Uuid();
  static const String hiveBenchmarkBox = 'benchmark_box';

  Future<void> init() async {
    if (!Hive.isBoxOpen(hiveBenchmarkBox)) {
      await Hive.openBox(hiveBenchmarkBox);
    }
  }

  // --- 1. Batch Insert ---
  Future<Map<String, int>> benchmarkInsert(int count) async {
    final results = <String, int>{};
    
    // Generate data
    final tasksData = List.generate(count, (index) => {
      'title': 'Task $index',
      'content': _uuid.v4() + _uuid.v4(), // Longer text
      'isCompleted': Random().nextBool() ? 1 : 0, 
      'created': DateTime.now().toIso8601String(),
    });

    // --- Hive ---
    final hiveBox = Hive.box(hiveBenchmarkBox);
    await hiveBox.clear(); 
    
    var stopWatch = Stopwatch()..start();
    await hiveBox.addAll(tasksData);
    stopWatch.stop();
    results['Hive'] = stopWatch.elapsedMilliseconds;

    // --- SQLite ---
    final db = _sqliteService.db;
    await db.delete('benchmark_tasks'); // Clear first
    
    stopWatch.reset();
    stopWatch.start();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final task in tasksData) {
        batch.insert('benchmark_tasks', task);
      }
      await batch.commit(noResult: true);
    });
    stopWatch.stop();
    results['SQLite'] = stopWatch.elapsedMilliseconds;

    // --- Isar ---
    final isar = _isarService.isar;
    await isar.writeTxn(() async {
      await isar.benchmarkTasks.clear();
    });

    final isarTasks = tasksData.map((e) => BenchmarkTask()
      ..title = e['title'] as String
      ..content = e['content'] as String
      ..isCompleted = (e['isCompleted'] as int) == 1
      ..createdDate = DateTime.parse(e['created'] as String)
    ).toList();

    stopWatch.reset();
    stopWatch.start();
    await isar.writeTxn(() async {
      await isar.benchmarkTasks.putAll(isarTasks);
    });
    stopWatch.stop();
    results['Isar'] = stopWatch.elapsedMilliseconds;

    return results;
  }

  // --- 2. Batch Read ---
  Future<Map<String, int>> benchmarkRead() async {
    final results = <String, int>{};
    final stopWatch = Stopwatch();

    // --- Hive ---
    final hiveBox = Hive.box(hiveBenchmarkBox);
    stopWatch.start();
    final hiveList = hiveBox.values.toList();
    stopWatch.stop();
    results['Hive'] = stopWatch.elapsedMilliseconds;
    debugPrint('Hive read ${hiveList.length} items');

    // --- SQLite ---
    final db = _sqliteService.db;
    stopWatch.reset();
    stopWatch.start();
    final sqliteList = await db.query('benchmark_tasks');
    stopWatch.stop();
    results['SQLite'] = stopWatch.elapsedMilliseconds;
    debugPrint('SQLite read ${sqliteList.length} items');

    // --- Isar ---
    final isar = _isarService.isar;
    stopWatch.reset();
    stopWatch.start();
    final isarList = await isar.benchmarkTasks.where().findAll();
    stopWatch.stop();
    results['Isar'] = stopWatch.elapsedMilliseconds;
    debugPrint('Isar read ${isarList.length} items');

    return results;
  }

  // --- 3. Batch Delete ---
  Future<Map<String, int>> benchmarkDelete() async {
    final results = <String, int>{};
    final stopWatch = Stopwatch();

    // --- Hive ---
    final hiveBox = Hive.box(hiveBenchmarkBox);
    stopWatch.start();
    await hiveBox.clear();
    stopWatch.stop();
    results['Hive'] = stopWatch.elapsedMilliseconds;

    // --- SQLite ---
    final db = _sqliteService.db;
    stopWatch.reset();
    stopWatch.start();
    await db.delete('benchmark_tasks');
    stopWatch.stop();
    results['SQLite'] = stopWatch.elapsedMilliseconds;

    // --- Isar ---
    final isar = _isarService.isar;
    stopWatch.reset();
    stopWatch.start();
    await isar.writeTxn(() async {
      await isar.benchmarkTasks.clear();
    });
    stopWatch.stop();
    results['Isar'] = stopWatch.elapsedMilliseconds;

    return results;
  }
}
