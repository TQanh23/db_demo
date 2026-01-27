import 'package:isar/isar.dart';

part 'task.g.dart'; // File do Isar tự sinh ra

@collection
class Task {
  Id id = Isar.autoIncrement; 

  @Index(type: IndexType.value) // Đánh index để search nhanh
  late String title;

  bool isCompleted = false;

  DateTime createdDate = DateTime.now();

  // Giả lập quan hệ với SQLite (lưu ID của category bên SQLite)
  int? categoryId; 
}
