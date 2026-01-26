import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../collections/todo.dart'; // Import model vừa tạo

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  // 1. Mở Database
  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      // Mở DB với Schema (cấu trúc) của Todo
      return await Isar.open(
        [TodoSchema], 
        directory: dir.path, 
        inspector: true, // Cho phép debug
      );
    }
    return Future.value(Isar.getInstance());
  }

  // 2. CREATE: Thêm công việc
  Future<void> addTodo(String title) async {
    final isar = await db;
    final newTodo = Todo()..title = title;
    
    // Mọi thao tác ghi/xóa phải nằm trong writeTxn
    await isar.writeTxn(() async {
      await isar.todos.put(newTodo);
    });
  }

  // 3. READ: Lấy toàn bộ danh sách (Dạng Stream để tự update UI)
  Stream<List<Todo>> getAllTodos() async* {
    final isar = await db;
    // watch(fireImmediately: true) giúp UI render ngay lập tức khi mở app
    yield* isar.todos.where().watch(fireImmediately: true);
  }
  
  // 3.1 READ FILTER: Chỉ lấy công việc đã xong (Yêu cầu Demo)
  Stream<List<Todo>> getCompletedTodos() async* {
    final isar = await db;
    yield* isar.todos.filter().isCompletedEqualTo(true).watch(fireImmediately: true);
  }

  // 4. UPDATE: Đổi trạng thái (Checkbox)
  Future<void> toggleTodo(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final todo = await isar.todos.get(id);
      if (todo != null) {
        todo.isCompleted = !todo.isCompleted;
        await isar.todos.put(todo); // put đè lên ID cũ = Update
      }
    });
  }

  // 5. DELETE: Xóa công việc
  Future<void> deleteTodo(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.todos.delete(id);
    });
  }
}