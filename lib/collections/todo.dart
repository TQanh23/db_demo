import 'package:isar/isar.dart';

// Dòng này cực kỳ quan trọng, tên file là todo.dart thì part phải là todo.g.dart
part 'todo.g.dart'; 

@collection
class Todo {
  Id id = Isar.autoIncrement; // ID tự động tăng (1, 2, 3...)

  late String title; // Tên công việc

  bool isCompleted = false; // Trạng thái: false là chưa làm xong
}