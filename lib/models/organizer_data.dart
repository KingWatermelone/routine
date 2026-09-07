import 'task.dart';
import 'task_category.dart';

class OrganizerData {
  OrganizerData(this.tasks, this.categories);
  final List<Task> tasks;
  final List<TaskCategory> categories;

  /// Build stable category IDs once, including every nonstandard legacy name.
  factory OrganizerData.migrate(List<Task> tasks) {
    final categories = <TaskCategory>[];
    final ids = <String, String>{};
    String? resolve(String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return null;
      return ids.putIfAbsent(trimmed.toLowerCase(), () {
        final id = 'migrated-${categories.length}';
        categories.add(
          TaskCategory(
            id: id,
            name: trimmed,
            color: TaskCategory
                .colors[categories.length % TaskCategory.colors.length],
            icon: 'folder',
          ),
        );
        return id;
      });
    }

    for (final name in ['Personal', 'Work', 'Study', 'Home', 'Shopping']) {
      resolve(name);
    }
    return OrganizerData(
      tasks
          .map(
            (task) => task.copyWith(
              categoryId: resolve(task.category),
              clearCategoryId: task.category.trim().isEmpty,
            ),
          )
          .toList(),
      categories,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 2,
    'tasks': tasks.map((task) => task.toJson()..remove('category')).toList(),
    'categories': categories.map((category) => category.toJson()).toList(),
  };

  factory OrganizerData.fromJson(Map<String, Object?> json) {
    if (json['version'] != 2)
      throw const FormatException('Unsupported data version');
    final categories = (json['categories'] as List)
        .map(
          (item) =>
              TaskCategory.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
    final tasks = (json['tasks'] as List)
        .map((item) => Task.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
    final ids = categories.map((category) => category.id).toSet();
    if (ids.length != categories.length ||
        tasks.any(
          (task) => task.categoryId != null && !ids.contains(task.categoryId),
        )) {
      throw const FormatException('Invalid category references');
    }
    return OrganizerData(tasks, categories);
  }
}
