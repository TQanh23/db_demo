import 'package:flutter/material.dart';
import '../services/isar_service.dart';
import '../collections/todo.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final IsarService service = IsarService();
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Isar To-Do List'),
        actions: [
          // Nút Demo Filter (Lọc công việc đã xong)
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
                // Phần này bạn có thể làm nâng cao: 
                // Tạo biến state để switch giữa getAllTodos và getCompletedTodos
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo: Chức năng lọc (Sinh viên tự code logic switch)')),
                );
            },
          )
        ],
      ),
      // StreamBuilder lắng nghe thay đổi từ Database
      body: StreamBuilder<List<Todo>>(
        stream: service.getAllTodos(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final todos = snapshot.data!;
            if (todos.isEmpty) return const Center(child: Text("Chưa có công việc nào"));

            return ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                return ListTile(
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isCompleted 
                        ? TextDecoration.lineThrough // Gạch ngang nếu xong
                        : null,
                    ),
                  ),
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (value) {
                      // Gọi hàm Update
                      service.toggleTodo(todo.id);
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Gọi hàm Delete
                      service.deleteTodo(todo.id);
                    },
                  ),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Thêm công việc'),
              content: TextField(
                controller: _textController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nhập tên công việc'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      // Gọi hàm Create
                      service.addTodo(_textController.text);
                      _textController.clear();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Thêm'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}