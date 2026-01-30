import 'package:isar/isar.dart';

part 'benchmark_task.g.dart';

@collection
class BenchmarkTask {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  late String content; // For larger data payload

  bool isCompleted = false;

  DateTime createdDate = DateTime.now();
  
  // No relation needed for benchmark, just raw data
}
