import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class HiveService {
  static const String settingsBox = 'settings';
  static const String taskBox = 'hive_tasks';
  static const String historyBoxName = 'search_history';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(settingsBox);
    await Hive.openBox(taskBox);
    await Hive.openBox(historyBoxName);
  }

  // --- Search History (List Cache Demo) ---
  List<String> getSearchHistory() {
    final box = Hive.box(historyBoxName);
    return box.get('history', defaultValue: <String>[]).cast<String>();
  }

  Future<void> addSearchTerm(String term) async {
    if (term.isEmpty) return;
    final box = Hive.box(historyBoxName);
    List<String> currentList = getSearchHistory();
    
    currentList.remove(term); // Xóa nếu trùng để đưa lên đầu
    currentList.insert(0, term); // Chèn lên đầu
    if (currentList.length > 5) currentList = currentList.sublist(0, 5); // Giới hạn 5

    await box.put('history', currentList);
  }

  // --- Settings (Theme) ---
  bool get isDarkMode => Hive.box(settingsBox).get('darkMode', defaultValue: false);
  
  Future<void> toggleTheme(bool value) async {
    await Hive.box(settingsBox).put('darkMode', value);
  }

  // --- Tasks CRUD (Key-Value Style) ---
  // Sử dụng Map<dynamic, dynamic> đơn giản, không cần Adapter phức tạp cho demo
  
  Box get _tasks => Hive.box(taskBox);

  // 1. Create
  Future<void> addTask(String title) async {
    final taskRaw = {
      'title': title,
      'created': DateTime.now().toIso8601String(),
      'isCompleted': false,
    };
    await _tasks.add(taskRaw); // Auto-increment key (int index)
  }

  // 2. Read (ValueListenable để UI tự update)
  ValueListenable<Box> getTasksListenable() {
    return _tasks.listenable();
  }
  
  // Helper convert sang List object để dễ hiển thị
  List<Map<String, dynamic>> getTasks() {
    final List<Map<String, dynamic>> list = [];
    for (var i = 0; i < _tasks.length; i++) {
      final key = _tasks.keyAt(i);
      final val = Map<String, dynamic>.from(_tasks.getAt(i));
      val['key'] = key; // Lưu key để delete
      list.add(val);
    }
    // Sort mới nhất lên đầu
    list.sort((a, b) => (b['created'] as String).compareTo(a['created'] as String));
    return list;
  }

  // 3. Update
  Future<void> toggleComplete(int key, Map<String, dynamic> currentData) async {
    currentData['isCompleted'] = !currentData['isCompleted'];
    // Xóa field key trước khi lưu lại (nếu có)
    final dataToSave = Map<String, dynamic>.from(currentData)..remove('key');
    await _tasks.put(key, dataToSave);
  }

  Future<void> updateTaskTitle(int key, Map<String, dynamic> currentData, String newTitle) async {
    currentData['title'] = newTitle;
    final dataToSave = Map<String, dynamic>.from(currentData)..remove('key');
    await _tasks.put(key, dataToSave);
  }

  // 4. Delete
  Future<void> deleteTask(int key) async {
    await _tasks.delete(key);
  }
}
