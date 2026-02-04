import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/hive_service.dart';
import 'services/sqlite_service.dart';
import 'services/isar_service.dart';
import 'services/benchmark_service.dart';
import 'models/task.dart';
import 'screens/benchmark_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final hiveService = HiveService();
  await hiveService.init();
  
  final sqliteService = SqliteService();
  await sqliteService.init();
  
  final isarService = IsarService();
  await isarService.init();

  final benchmarkService = BenchmarkService(hiveService, isarService, sqliteService);
  await benchmarkService.init();

  runApp(MyApp(
    hive: hiveService, 
    sqlite: sqliteService, 
    isar: isarService,
    benchmarkService: benchmarkService,
  ));
}

class MyApp extends StatefulWidget {
  final HiveService hive;
  final SqliteService sqlite;
  final IsarService isar;
  final BenchmarkService benchmarkService;
  
  const MyApp({
    super.key, 
    required this.hive, 
    required this.sqlite, 
    required this.isar,
    required this.benchmarkService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool isDark;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    isDark = widget.hive.isDarkMode;
  }

  void _toggleTheme() async {
    await widget.hive.toggleTheme(!isDark);
    setState(() => isDark = !isDark);
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Theme state saved!'),
        duration: Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Hybrid Todo',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        isDark: isDark,
        toggleTheme: _toggleTheme,
        sqlite: widget.sqlite,
        isar: widget.isar,
        hive: widget.hive,
        benchmarkService: widget.benchmarkService,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final SqliteService sqlite;
  final IsarService isar;
  final HiveService hive;
  final BenchmarkService benchmarkService;

  const HomePage({
    super.key,
    required this.isDark,
    required this.toggleTheme,
    required this.sqlite,
    required this.isar,
    required this.hive,
    required this.benchmarkService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _taskController = TextEditingController();
  final _searchController = TextEditingController();
  
  // Database Selector
  String selectedDb = 'Isar'; // Default
  final List<String> dbOptions = ['Hive', 'SQLite', 'Isar'];

  // Isar Filter State
  bool showCompletedOnly = false;
  
  // Data State
  String searchQuery = '';
  List<Task> _isarTasks = []; 
  List<Map<String, dynamic>> _sqliteTasks = []; 

  @override
  void initState() {
    super.initState();
    _refreshIsar();
    _refreshSqlite(); 
  }

  void _refreshIsar() async {
    List<Task> tasks;
    if (showCompletedOnly) {
       tasks = await widget.isar.filterCompleted();
    } else {
       tasks = isarSearchQuery.isNotEmpty 
        ? await widget.isar.searchTasks(isarSearchQuery)
        : await widget.isar.getAllTasks();
    }
    
    setState(() {
      _isarTasks = tasks;
    });
  }

  void _refreshSqlite() async {
    final tasks = await widget.sqlite.getTasks();
    final filtered = searchQuery.isEmpty 
        ? tasks 
        : tasks.where((t) => (t['title'] as String).toLowerCase().contains(searchQuery.toLowerCase())).toList();
    
    setState(() {
      _sqliteTasks = filtered;
    });
  }
  
  String get isarSearchQuery => (selectedDb == 'Isar') ? searchQuery : '';

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    if (selectedDb == 'Isar') {
      _refreshIsar();
    } else if (selectedDb == 'SQLite') {
      _refreshSqlite();
    }
  }

  void _addTask() async { 
    if (_taskController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên công việc')),
      );
      return;
    }

    final title = _taskController.text;
    
    switch (selectedDb) {
      case 'Isar':
        await widget.isar.addTask(title, 0); 
        await widget.sqlite.logAction("Created Isar Task: $title");
        _refreshIsar(); 
        break;
      case 'SQLite':
        await widget.sqlite.addTask(title);
        await widget.sqlite.logAction("Created SQLite Task: $title");
        _refreshSqlite(); 
        break;
      case 'Hive':
        await widget.hive.addTask(title);
        await widget.sqlite.logAction("Created Hive Task: $title");
        break;
    }
    
    _taskController.clear();
    FocusScope.of(context).unfocus();
  }

  void _showLogsDialog() async {
    final logs = await widget.sqlite.getRecentLogs();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('System Audit Logs (SQLite)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: logs.isEmpty 
              ? const Center(child: Text('No logs yet')) 
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle, size: 8, color: Colors.blue),
                      title: Text(log['action']),
                      subtitle: Text(log['time'].toString().substring(0, 19)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      )
    );
  }

  void _showEditDialog(String currentTitle, Function(String) onSave) {
    final editController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Task'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (editController.text.isNotEmpty) {
                onSave(editController.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Update'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildInputArea()),
              _buildList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Databases',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Buổi 06 - Group 5 Demo',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // --- DYNAMIC FEATURE & THEME BUTTONS ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => BenchmarkScreen(benchmarkService: widget.benchmarkService))
                      );
                    },
                    icon: const Icon(Icons.speed, color: Colors.red),
                    tooltip: 'Benchmark Arena',
                  ),
                  const SizedBox(width: 8),
                  _buildFeatureButton(),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: widget.toggleTheme,
                    icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
                    tooltip: 'Toggle Theme',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              if (val.isNotEmpty && selectedDb == 'Hive') { 
                 widget.hive.addSearchTerm(val); 
                 setState(() {}); 
              }
            },
            decoration: InputDecoration(
              hintText: selectedDb == 'Isar' ? 'Isar Index Search...' : 'Filter list...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          // Hive Search History Chips (Removed as requested)
          // if (selectedDb == 'Hive' && widget.hive.getSearchHistory().isNotEmpty)
          //    Container(
          //     height: 40,
          //     margin: const EdgeInsets.only(top: 8),
          //     child: ListView(
          //       scrollDirection: Axis.horizontal,
          //       children: widget.hive.getSearchHistory().map((term) {
          //         return Padding(
          //           padding: const EdgeInsets.only(right: 8.0),
          //           child: ActionChip(
          //             label: Text(term),
          //             onPressed: () {
          //               _searchController.text = term;
          //               _onSearchChanged(term);
          //             },
          //             avatar: const Icon(Icons.history, size: 16),
          //             visualDensity: VisualDensity.compact,
          //           ),
          //         );
          //       }).toList(),
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton() {
    if (selectedDb == 'Hive') {
      return IconButton.filledTonal(
        onPressed: () {
          // Show Hive Cache Dialog
          final history = widget.hive.getSearchHistory();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Hive Search Cache'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Hive stores unstructured lists (List<String>) efficiently utilizing Key-Value pairs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                   ),
                   const SizedBox(height: 12),
                   if (history.isEmpty)
                     const Text('Cache is empty. Try searching something!'),
                   ...history.map((e) => ListTile(
                     dense: true,
                     leading: const Icon(Icons.history, size: 16),
                     title: Text(e),
                     contentPadding: EdgeInsets.zero,
                   )),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
              ],
            ),
          );
        },
        style: IconButton.styleFrom(backgroundColor: Colors.orange.shade100),
        icon: const Icon(Icons.history, color: Colors.orange),
        tooltip: 'Hive Cache Feature',
      );
    } else if (selectedDb == 'SQLite') {
      return IconButton.filledTonal(
        onPressed: () => _showLogsDialog(),
        style: IconButton.styleFrom(backgroundColor: Colors.blue.shade100),
        icon: const Icon(Icons.article, color: Colors.blue),
        tooltip: 'SQLite Audit Log',
      );
    } else if (selectedDb == 'Isar') {
      return IconButton.filledTonal(
        onPressed: () {
          setState(() {
            showCompletedOnly = !showCompletedOnly;
          });
          _refreshIsar();
        },
        style: IconButton.styleFrom(
          backgroundColor: showCompletedOnly ? Colors.purple : Colors.purple.shade100
        ),
        icon: Icon(
          Icons.filter_list_alt, 
          color: showCompletedOnly ? Colors.white : Colors.purple
        ),
        tooltip: 'Isar Filter Query',
      );
    }
    return const SizedBox();
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    hintText: 'New task...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Database Selector Dropdown with Custom Icons
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDb,
                    onChanged: (val) {
                      if (val != null) setState(() => selectedDb = val);
                    },
                    items: dbOptions.map((db) {
                      IconData icon;
                      Color color;
                      if (db == 'Hive') {
                        icon = Icons.inventory_2; // Hộp
                        color = Colors.orange;
                      } else if (db == 'SQLite') {
                        icon = Icons.table_chart; // Bảng
                        color = Colors.blue;
                      } else {
                        icon = Icons.rocket_launch; // Tên lửa (Isar)
                        color = Colors.purple;
                      }
                      
                      return DropdownMenuItem(
                        value: db,
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: 8),
                            Text(db, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Save Button with Dynamic Icon & Color
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addTask,
              icon: Icon(
                selectedDb == 'Hive' ? Icons.inventory_2 
                : selectedDb == 'SQLite' ? Icons.table_chart 
                : Icons.rocket_launch,
              ),
              label: Text('Save to $selectedDb'),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedDb == 'Hive' ? Colors.orange 
                    : selectedDb == 'SQLite' ? Colors.blue 
                    : Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper to build list based on selection ---
  Widget _buildList() {
    switch (selectedDb) {
      case 'Isar':
        return _buildIsarList();
      case 'SQLite':
        return _buildSqliteList();
      case 'Hive':
        return _buildHiveList();
      default:
        return const SliverToBoxAdapter(child: Center(child: Text('Unknown DB')));
    }
  }

  Widget _buildIsarList() {
    if (_isarTasks.isEmpty) return _buildEmptyState('Isar (NoSQL Document)');
    
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = _isarTasks[index];
            return _buildTaskItem(
              title: task.title,
              isCompleted: task.isCompleted,
              created: task.createdDate,
              onToggle: () async {
                await widget.isar.toggleComplete(task.id);
                await widget.sqlite.logAction("Toggled Isar Task: ${task.title}");
                _refreshIsar(); 
              },
              onEdit: () {
                _showEditDialog(task.title, (newTitle) async {
                  await widget.isar.updateTaskTitle(task.id, newTitle);
                  await widget.sqlite.logAction("Updated Isar Task: $newTitle");
                  _refreshIsar();
                });
              },
              onDelete: () async {
                await widget.isar.deleteTask(task.id);
                await widget.sqlite.logAction("Deleted Isar Task: ${task.title}");
                _refreshIsar(); 
              },
              tag: 'Isar',
              tagIcon: Icons.rocket_launch,
              color: Colors.purple.shade100,
            );
          },
          childCount: _isarTasks.length,
        ),
      ),
    );
  }

  Widget _buildSqliteList() {
    if (_sqliteTasks.isEmpty) return _buildEmptyState('SQLite (Relational)');

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = _sqliteTasks[index];
            final id = task['id'] as int;
            final isCompleted = (task['isCompleted'] as int) == 1;
            final date = DateTime.parse(task['created']);
            
            return _buildTaskItem(
              title: task['title'],
              isCompleted: isCompleted,
              created: date,
              onToggle: () async {
                await widget.sqlite.toggleComplete(id, task['isCompleted']);
                await widget.sqlite.logAction("Toggled SQLite Task: ${task['title']}");
                _refreshSqlite();
              },
              onEdit: () {
                _showEditDialog(task['title'], (newTitle) async {
                  await widget.sqlite.updateTaskTitle(id, newTitle);
                  await widget.sqlite.logAction("Updated SQLite Task: $newTitle");
                  _refreshSqlite();
                });
              },
              onDelete: () async {
                await widget.sqlite.deleteTask(id);
                await widget.sqlite.logAction("Deleted SQLite Task: ${task['title']}");
                _refreshSqlite();
              },
              tag: 'SQLite',
              tagIcon: Icons.table_chart,
              color: Colors.blue.shade100,
            );
          },
          childCount: _sqliteTasks.length,
        ),
      ),
    );
  }

  Widget _buildHiveList() {
    return ValueListenableBuilder(
      valueListenable: widget.hive.getTasksListenable(),
      builder: (context, Box box, _) {
        final tasks = widget.hive.getTasks();
        final filtered = searchQuery.isEmpty 
            ? tasks 
            : tasks.where((t) => (t['title'] as String).toLowerCase().contains(searchQuery.toLowerCase())).toList();

        if (filtered.isEmpty) return _buildEmptyState('Hive (Key-Value)');

          return SliverPadding(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final task = filtered[index];
                  final key = task['key'] as int;
                  final isCompleted = task['isCompleted'] as bool;
                  final date = DateTime.parse(task['created']);

                  return _buildTaskItem(
                    title: task['title'],
                    isCompleted: isCompleted,
                    created: date,
                    onToggle: () async {
                       await widget.hive.toggleComplete(key, task);
                       await widget.sqlite.logAction("Toggled Hive Task: ${task['title']}");
                    },
                    onEdit: () {
                      _showEditDialog(task['title'], (newTitle) async {
                        await widget.hive.updateTaskTitle(key, task, newTitle);
                        await widget.sqlite.logAction("Updated Hive Task: $newTitle");
                        // Hive ValueListenable will auto update UI
                      });
                    },
                    onDelete: () async {
                       await widget.hive.deleteTask(key);
                       await widget.sqlite.logAction("Deleted Hive Task: ${task['title']}");
                    },
                    tag: 'Hive',
                    tagIcon: Icons.inventory_2,
                    color: Colors.orange.shade100,
                  );
                },
                childCount: filtered.length,
              ),
            ),
          );
        },
      );
  }

  Widget _buildEmptyState(String dbName) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No tasks in $dbName',
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (selectedDb == 'Isar' && searchQuery.isNotEmpty)
               const Text('Search query active', style: TextStyle(fontSize: 12, color: Colors.purple)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required bool isCompleted,
    required DateTime created,
    required VoidCallback onToggle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required String tag,
    required IconData tagIcon,
    required Color color,
  }) {
    return Dismissible(
      key: UniqueKey(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Checkbox(
            value: isCompleted,
            shape: const CircleBorder(),
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (_) => onToggle(),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tagIcon, size: 12, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${created.hour}:${created.minute}',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                tooltip: 'Update Task',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 20, color: Colors.grey),
                tooltip: 'Delete Task',
              ),
            ],
          ),
        ),
      ),
    );
  }
}