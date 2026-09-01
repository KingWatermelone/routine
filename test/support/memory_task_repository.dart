import 'package:routine/data/task_repository.dart';
import 'package:routine/models/task.dart';

class MemoryTaskRepository implements TaskRepository {
  MemoryTaskRepository({List<Task> initialTasks = const <Task>[]})
    : storedTasks = List<Task>.of(initialTasks);

  List<Task> storedTasks;
  int saveCount = 0;

  @override
  Future<List<Task>> loadTasks() async => List<Task>.of(storedTasks);

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    storedTasks = List<Task>.of(tasks);
    saveCount += 1;
  }
}
