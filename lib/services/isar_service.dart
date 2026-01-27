import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class IsarService {
  static Isar? _isar;
  
  // Getter an toàn để truy cập DB
  Isar get isar => _isar!;

  Future<void> init() async {
    // Nếu Isar đã mở instance rồi thì dùng lại instance đầu tiên tìm thấy
    if (Isar.instanceNames.isNotEmpty) {
      _isar = Isar.getInstance();
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TaskSchema],
      directory: dir.path,
    );
  }

  // 1. Create
  Future<void> addTask(String title, int catId) async {
    final newTask = Task()
      ..title = title
      ..categoryId = catId;
      
    await isar.writeTxn(() async {
      await isar.tasks.put(newTask);
    });
  }

  // 2. Read (Future - Load data một lần)
  Future<List<Task>> getAllTasks() async {
    return await isar.tasks.where().sortByCreatedDateDesc().findAll();
  }

  // 3. Update
  Future<void> toggleComplete(int id) async {
    await isar.writeTxn(() async {
      final task = await isar.tasks.get(id);
      if (task != null) {
        task.isCompleted = !task.isCompleted;
        await isar.tasks.put(task);
      }
    });
  }

  // 4. Delete
  Future<void> deleteTask(int id) async {
    await isar.writeTxn(() async {
      await isar.tasks.delete(id);
    });
  }
  
  // 5. Search (Future)
  Future<List<Task>> searchTasks(String query) async {
    if (query.isEmpty) {
      return getAllTasks();
    } else {
      return await isar.tasks
          .filter()
          .titleContains(query, caseSensitive: false)
          .sortByCreatedDateDesc()
          .findAll();
    }
  }

  // Demo Query: Filter Completed
  Future<List<Task>> filterCompleted() async {
    return await isar.tasks
        .filter()
        .isCompletedEqualTo(true)
        .sortByCreatedDateDesc()
        .findAll();
  }
}