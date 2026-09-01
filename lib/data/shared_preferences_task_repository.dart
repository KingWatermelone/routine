import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import 'task_repository.dart';

class SharedPreferencesTaskRepository implements TaskRepository {
  SharedPreferencesTaskRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _tasksKey = 'routine.tasks.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Task>> loadTasks() async {
    final String? encodedTasks = await _preferences.getString(_tasksKey);
    if (encodedTasks == null || encodedTasks.isEmpty) {
      return const <Task>[];
    }

    try {
      final Object? decoded = jsonDecode(encodedTasks);
      if (decoded is! List<Object?>) {
        return const <Task>[];
      }

      final List<Task> tasks = <Task>[];
      for (final Object? item in decoded) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        try {
          tasks.add(Task.fromJson(item));
        } on TypeError {
          // Keep valid tasks even if one stored record is malformed.
        }
      }
      return tasks;
    } on FormatException {
      return const <Task>[];
    }
  }

  @override
  Future<void> saveTasks(List<Task> tasks) {
    final String encodedTasks = jsonEncode(
      tasks.map((Task task) => task.toJson()).toList(growable: false),
    );
    return _preferences.setString(_tasksKey, encodedTasks);
  }
}
