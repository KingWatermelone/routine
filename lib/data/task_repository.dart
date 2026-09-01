import '../models/task.dart';

abstract interface class TaskRepository {
  Future<List<Task>> loadTasks();

  Future<void> saveTasks(List<Task> tasks);
}
