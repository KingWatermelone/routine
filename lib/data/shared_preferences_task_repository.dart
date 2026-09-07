import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/organizer_data.dart';
import 'task_repository.dart';

class SharedPreferencesTaskRepository implements TaskRepository {
  SharedPreferencesTaskRepository({
    SharedPreferencesAsync? preferences,
    Future<String?> Function(String)? readString,
    Future<void> Function(String, String)? writeString,
  }) : _readString =
           readString ?? (preferences ?? SharedPreferencesAsync()).getString,
       _writeString =
           writeString ?? (preferences ?? SharedPreferencesAsync()).setString;

  static const String _tasksKey = 'routine.tasks.v1';

  final Future<String?> Function(String) _readString;
  final Future<void> Function(String, String) _writeString;

  @override
  Future<OrganizerData> loadData() async {
    final encoded = await _readString('routine.organizer.v2');
    if (encoded != null) {
      // Fail visibly on damaged/newer data; never overwrite it with defaults.
      return OrganizerData.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );
    }
    final legacy = await _readString(_tasksKey);
    final tasks = legacy == null
        ? <Task>[]
        : (jsonDecode(legacy) as List)
              .map(
                (item) => Task.fromJson(Map<String, Object?>.from(item as Map)),
              )
              .toList();
    final data = OrganizerData.migrate(tasks);
    await saveData(data);
    return data;
  }

  @override
  Future<void> saveData(OrganizerData data) =>
      _writeString('routine.organizer.v2', jsonEncode(data.toJson()));
}
