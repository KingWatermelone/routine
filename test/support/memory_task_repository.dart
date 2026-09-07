import 'package:routine/data/task_repository.dart';
import 'package:routine/models/task.dart';
import 'package:routine/models/organizer_data.dart';

class MemoryTaskRepository implements TaskRepository {
  MemoryTaskRepository({List<Task> initialTasks = const <Task>[]})
    : storedTasks = List<Task>.of(initialTasks);

  List<Task> storedTasks;
  int saveCount = 0;
  OrganizerData? storedData;
  @override
  Future<OrganizerData> loadData() async =>
      storedData ?? OrganizerData.migrate(storedTasks);
  @override
  Future<void> saveData(OrganizerData data) async {
    await saveTasks(data.tasks);
    storedData = data;
  }

  Future<List<Task>> loadTasks() async => List<Task>.of(storedTasks);

  Future<void> saveTasks(List<Task> tasks) async {
    storedTasks = List<Task>.of(tasks);
    saveCount += 1;
  }
}
