import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../models/task.dart';

enum TaskStatusFilter { open, completed, all }

class TaskValidationException implements Exception {
  const TaskValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TaskController extends ChangeNotifier {
  TaskController({required this.repository, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const List<String> defaultCategories = <String>[
    'Personal',
    'Work',
    'Study',
    'Home',
    'Shopping',
  ];

  final TaskRepository repository;
  final DateTime Function() _now;
  final List<Task> _tasks = <Task>[];

  bool _isLoading = true;
  String? _storageError;
  String _searchQuery = '';
  TaskStatusFilter _statusFilter = TaskStatusFilter.open;
  String? _categoryFilter;
  TaskPriority? _priorityFilter;

  bool get isLoading => _isLoading;
  String? get storageError => _storageError;
  String get searchQuery => _searchQuery;
  TaskStatusFilter get statusFilter => _statusFilter;
  String? get categoryFilter => _categoryFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  List<Task> get tasks => List<Task>.unmodifiable(_tasks);

  List<String> get categories {
    final Set<String> categories = <String>{...defaultCategories};
    categories.addAll(_tasks.map((Task task) => task.category));
    final List<String> result = categories.toList();
    result.sort();
    return result;
  }

  List<Task> get visibleTasks {
    final String normalizedQuery = _searchQuery.trim().toLowerCase();
    final List<Task> result = _tasks.where((Task task) {
      final bool matchesStatus = switch (_statusFilter) {
        TaskStatusFilter.open => !task.isCompleted,
        TaskStatusFilter.completed => task.isCompleted,
        TaskStatusFilter.all => true,
      };

      final bool matchesCategory =
          _categoryFilter == null || task.category == _categoryFilter;
      final bool matchesPriority =
          _priorityFilter == null || task.priority == _priorityFilter;
      final bool matchesSearch =
          normalizedQuery.isEmpty ||
          task.title.toLowerCase().contains(normalizedQuery) ||
          task.description.toLowerCase().contains(normalizedQuery) ||
          task.tags.any(
            (String tag) => tag.toLowerCase().contains(normalizedQuery),
          );

      return matchesStatus &&
          matchesCategory &&
          matchesPriority &&
          matchesSearch;
    }).toList();

    result.sort(_compareTasks);
    return result;
  }

  Future<void> load() async {
    _isLoading = true;
    _storageError = null;
    notifyListeners();

    try {
      _tasks
        ..clear()
        ..addAll(await repository.loadTasks());
    } on Object {
      _storageError = 'Tasks could not be loaded from this device.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(TaskStatusFilter filter) {
    if (_statusFilter == filter) {
      return;
    }
    _statusFilter = filter;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    if (_categoryFilter == category) {
      return;
    }
    _categoryFilter = category;
    notifyListeners();
  }

  void setPriorityFilter(TaskPriority? priority) {
    if (_priorityFilter == priority) {
      return;
    }
    _priorityFilter = priority;
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    String description = '',
    String category = 'Personal',
    List<String> tags = const <String>[],
    TaskPriority priority = TaskPriority.normal,
    DateTime? dueDate,
    List<DateTime> reminders = const <DateTime>[],
    TaskSource source = TaskSource.manual,
    String? relatedItemId,
  }) async {
    _validate(title: title, dueDate: dueDate, reminders: reminders);
    final DateTime timestamp = _now();
    final Task task = Task(
      id: _createTaskId(timestamp),
      title: title.trim(),
      description: description.trim(),
      category: category,
      tags: List<String>.unmodifiable(tags),
      priority: priority,
      dueDate: dueDate,
      reminders: List<DateTime>.unmodifiable(reminders),
      createdAt: timestamp,
      updatedAt: timestamp,
      source: source,
      relatedItemId: relatedItemId,
    );

    _tasks.add(task);
    notifyListeners();
    await _persist();
  }

  Future<void> updateTask(Task task) async {
    _validate(
      title: task.title,
      dueDate: task.dueDate,
      reminders: task.reminders,
    );
    final int index = _tasks.indexWhere(
      (Task existingTask) => existingTask.id == task.id,
    );
    if (index == -1) {
      return;
    }

    _tasks[index] = task.copyWith(
      title: task.title.trim(),
      description: task.description.trim(),
      updatedAt: _now(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> toggleTask(Task task) async {
    final int index = _tasks.indexWhere(
      (Task existingTask) => existingTask.id == task.id,
    );
    if (index == -1) {
      return;
    }

    final DateTime timestamp = _now();
    if (task.isCompleted) {
      _tasks[index] = task.copyWith(
        isCompleted: false,
        clearCompletedAt: true,
        updatedAt: timestamp,
      );
    } else {
      _tasks[index] = task.copyWith(
        isCompleted: true,
        reminders: const <DateTime>[],
        completedAt: timestamp,
        updatedAt: timestamp,
      );
    }

    notifyListeners();
    await _persist();
  }

  Future<void> deleteTask(Task task) async {
    _tasks.removeWhere((Task existingTask) => existingTask.id == task.id);
    notifyListeners();
    await _persist();
  }

  void clearStorageError() {
    if (_storageError == null) {
      return;
    }
    _storageError = null;
    notifyListeners();
  }

  void _validate({
    required String title,
    required DateTime? dueDate,
    required List<DateTime> reminders,
  }) {
    if (title.trim().isEmpty) {
      throw const TaskValidationException('Enter a title for the task.');
    }
    if (reminders.isNotEmpty && dueDate == null) {
      throw const TaskValidationException(
        'Set a due date before adding a reminder.',
      );
    }
    if (dueDate != null &&
        reminders.any((DateTime reminder) => reminder.isAfter(dueDate))) {
      throw const TaskValidationException(
        'A reminder cannot be later than the due date.',
      );
    }
  }

  Future<void> _persist() async {
    try {
      await repository.saveTasks(List<Task>.unmodifiable(_tasks));
      _storageError = null;
    } on Object {
      _storageError = 'Changes could not be saved on this device.';
      notifyListeners();
    }
  }

  String _createTaskId(DateTime timestamp) {
    final String baseId = timestamp.microsecondsSinceEpoch.toString();
    String id = baseId;
    int collision = 1;
    while (_tasks.any((Task task) => task.id == id)) {
      id = '$baseId-$collision';
      collision += 1;
    }
    return id;
  }

  static int _compareTasks(Task first, Task second) {
    final DateTime? firstDueDate = first.dueDate;
    final DateTime? secondDueDate = second.dueDate;
    if (firstDueDate != null && secondDueDate != null) {
      final int dueDateOrder = firstDueDate.compareTo(secondDueDate);
      if (dueDateOrder != 0) {
        return dueDateOrder;
      }
    } else if (firstDueDate != null) {
      return -1;
    } else if (secondDueDate != null) {
      return 1;
    }

    final int priorityOrder = second.priority.index.compareTo(
      first.priority.index,
    );
    if (priorityOrder != 0) {
      return priorityOrder;
    }
    return second.createdAt.compareTo(first.createdAt);
  }
}
