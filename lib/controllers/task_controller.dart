import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../models/organizer_data.dart';
import '../notifications/reminder_scheduler.dart';

enum TaskStatusFilter { open, completed, all }

enum TaskDateFilter { all, today, upcoming, overdue }

class TaskValidationException implements Exception {
  const TaskValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TaskController extends ChangeNotifier {
  TaskController({
    required this.repository,
    this.reminderScheduler,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TaskRepository repository;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final ReminderScheduler? reminderScheduler;
  String? reminderError;

  Future<void> _syncReminders(
    List<Task> tasks, {
    bool requestPermission = false,
  }) async {
    try {
      reminderError = await reminderScheduler?.synchronize(
        tasks,
        requestPermission: requestPermission,
      );
    } on Object {
      reminderError = 'Erinnerungen konnten nicht mit iOS abgeglichen werden. Bitte erneut versuchen.';
    }
  }

  Future<void> refreshReminders({bool requestPermission = false}) async {
    if (!_loaded || reminderScheduler == null) return;
    final operation = _saveQueue.then((_) async {
      // Do not schedule changes whose local save failed.
      if (_storageError == null) {
        await _syncReminders(
          List.of(_tasks),
          requestPermission: requestPermission,
        );
      }
    });
    _saveQueue = operation.catchError((Object error) {});
    await operation;
    notifyListeners();
  }

  Future<void> openNotificationSettings() async {
    try {
      await reminderScheduler?.openSettings();
    } on Object {
      reminderError = 'Öffne Einstellungen → Mitteilungen → Routine und aktiviere Mitteilungen erlauben.';
      notifyListeners();
    }
  }

  final DateTime Function() _now;
  final List<Task> _tasks = <Task>[];
  final List<TaskCategory> _categories = [];
  bool _loaded = false;
  Future<void> _saveQueue = Future<void>.value();
  List<TaskCategory> get categoryItems => List.unmodifiable(_categories);
  TaskCategory? categoryById(String? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String categoryName(String? id) => categoryById(id)?.name ?? 'Ohne Kategorie';

  Future<void> saveCategory({
    String? id,
    required String name,
    required int color,
    required String icon,
  }) async {
    if (!_loaded) {
      throw const TaskValidationException('Daten sind noch nicht geladen.');
    }
    name = name.trim();
    if (name.isEmpty) {
      throw const TaskValidationException(
        'Bitte einen Kategorienamen eingeben.',
      );
    }
    if (_categories.any(
      (item) =>
          item.id != id && item.name.trim().toLowerCase() == name.toLowerCase(),
    )) {
      throw const TaskValidationException(
        'Eine Kategorie mit diesem Namen existiert bereits.',
      );
    }
    if (!TaskCategory.icons.containsKey(icon) ||
        !TaskCategory.colors.contains(color)) {
      throw const TaskValidationException(
        'Bitte eine gültige Farbe und ein Icon auswählen.',
      );
    }
    if (id != null && categoryById(id) == null) {
      throw const TaskValidationException('Kategorie existiert nicht mehr.');
    }
    final random = Random.secure();
    var newId =
        id ??
        'category-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    while (id == null && categoryById(newId) != null) {
      newId = '$newId-1';
    }
    final category = TaskCategory(
      id: newId,
      name: name,
      color: color,
      icon: icon,
    );
    final index = _categories.indexWhere((item) => item.id == newId);
    if (index < 0) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> deleteCategory(String id) async {
    _ensureLoaded();
    _categories.removeWhere((item) => item.id == id);
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].categoryId == id) {
        _tasks[i] = _tasks[i].copyWith(
          clearCategoryId: true,
          updatedAt: _now(),
        );
      }
    }
    if (_categoryFilter == id) _categoryFilter = null;
    notifyListeners();
    await _persist();
  }

  bool _isLoading = true;
  String? _storageError;
  String _searchQuery = '';
  TaskStatusFilter _statusFilter = TaskStatusFilter.open;
  String? _categoryFilter;
  TaskPriority? _priorityFilter;
  TaskDateFilter _dateFilter = TaskDateFilter.all;
  TaskDateFilter get dateFilter => _dateFilter;
  void setDateFilter(TaskDateFilter filter) {
    if (_dateFilter == filter) return;
    _dateFilter = filter;
    notifyListeners();
  }

  void refreshDateFilters() => notifyListeners();

  bool get isLoading => _isLoading;
  String? get storageError => _storageError;
  String get searchQuery => _searchQuery;
  TaskStatusFilter get statusFilter => _statusFilter;
  String? get categoryFilter => _categoryFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  List<Task> get tasks => List<Task>.unmodifiable(_tasks);

  List<String> get categories {
    return ['', ..._categories.map((category) => category.id)];
  }

  List<Task> get visibleTasks {
    final now = _now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    // Construct calendar boundaries instead of adding 24 hours (DST days differ).
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final String normalizedQuery = _searchQuery.trim().toLowerCase();
    final List<Task> result = _tasks.where((Task task) {
      final bool matchesStatus = switch (_statusFilter) {
        TaskStatusFilter.open => !task.isCompleted,
        TaskStatusFilter.completed => task.isCompleted,
        TaskStatusFilter.all => true,
      };

      final bool matchesCategory =
          _categoryFilter == null || (task.categoryId ?? '') == _categoryFilter;
      final due = task.dueDate?.toLocal();
      final matchesDate = switch (_dateFilter) {
        TaskDateFilter.all => true,
        TaskDateFilter.today =>
          due != null && !due.isBefore(today) && due.isBefore(tomorrow),
        TaskDateFilter.upcoming => due != null && !due.isBefore(tomorrow),
        TaskDateFilter.overdue =>
          due != null && due.isBefore(now) && !task.isCompleted,
      };
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
          matchesDate &&
          matchesCategory &&
          matchesPriority &&
          matchesSearch;
    }).toList();

    result.sort(_compareTasks);
    return result;
  }

  Future<void> load() async {
    _loaded = false;
    _isLoading = true;
    _storageError = null;
    notifyListeners();

    try {
      final data = await repository.loadData();
      _tasks
        ..clear()
        ..addAll(data.tasks);
      _categories
        ..clear()
        ..addAll(data.categories);
      await _syncReminders(List.of(_tasks));
      _loaded = true;
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
    String? categoryId,
    List<String> tags = const <String>[],
    TaskPriority priority = TaskPriority.normal,
    DateTime? dueDate,
    List<DateTime> reminders = const <DateTime>[],
    TaskSource source = TaskSource.manual,
    String? relatedItemId,
  }) async {
    _validate(title: title, dueDate: dueDate, reminders: reminders);
    _validateCategory(categoryId);
    final DateTime timestamp = _now();
    final Task task = Task(
      id: _createTaskId(timestamp),
      title: title.trim(),
      description: description.trim(),
      categoryId: categoryId == '' ? null : categoryId,
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
    _validateCategory(task.categoryId);
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
    _ensureLoaded();
    final int index = _tasks.indexWhere(
      (Task existingTask) => existingTask.id == task.id,
    );
    if (index == -1) {
      return;
    }

    task = _tasks[index];
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
    _ensureLoaded();
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
    _ensureLoaded();
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
    if (!_loaded) return;
    final data = OrganizerData(List.of(_tasks), List.of(_categories));
    final operation = _saveQueue.then((_) async {
      await repository.saveData(data);
      await _syncReminders(data.tasks, requestPermission: true);
    });
    _saveQueue = operation.catchError((Object error) {});
    try {
      await operation;
      _storageError = null;
      notifyListeners();
    } on Object {
      _storageError = 'Changes could not be saved on this device.';
      notifyListeners();
    }
  }

  Future<void> retrySave() => _persist();

  void _ensureLoaded() {
    if (!_loaded)
      throw const TaskValidationException(
        'Daten konnten noch nicht geladen werden.',
      );
  }

  void _validateCategory(String? id) {
    if (id != null && id.isNotEmpty && categoryById(id) == null) {
      throw const TaskValidationException(
        'Die ausgewählte Kategorie existiert nicht mehr.',
      );
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
