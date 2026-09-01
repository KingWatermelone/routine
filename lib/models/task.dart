enum TaskPriority { low, normal, high }

enum TaskSource { manual, shoppingList, homeSystem, calendar, other }

/// A task is independent from the module that created it.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.category = 'Personal',
    this.tags = const <String>[],
    this.isCompleted = false,
    this.priority = TaskPriority.normal,
    this.dueDate,
    this.reminders = const <DateTime>[],
    this.completedAt,
    this.source = TaskSource.manual,
    this.relatedItemId,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime? dueDate;
  final List<DateTime> reminders;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final TaskSource source;
  final String? relatedItemId;

  Task copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    bool? isCompleted,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<DateTime>? reminders,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    TaskSource? source,
    String? relatedItemId,
    bool clearRelatedItemId = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: List<String>.unmodifiable(tags ?? this.tags),
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      reminders: List<DateTime>.unmodifiable(reminders ?? this.reminders),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      source: source ?? this.source,
      relatedItemId: clearRelatedItemId
          ? null
          : relatedItemId ?? this.relatedItemId,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'isCompleted': isCompleted,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'reminders': reminders
          .map((DateTime reminder) => reminder.toIso8601String())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'source': source.name,
      'relatedItemId': relatedItemId,
    };
  }

  factory Task.fromJson(Map<String, Object?> json) {
    final DateTime fallbackTimestamp = DateTime.now();

    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Personal',
      tags: _stringList(json['tags']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      priority: _enumByName(
        TaskPriority.values,
        json['priority'] as String?,
        TaskPriority.normal,
      ),
      dueDate: _dateTime(json['dueDate']),
      reminders: _dateTimeList(json['reminders']),
      createdAt: _dateTime(json['createdAt']) ?? fallbackTimestamp,
      updatedAt: _dateTime(json['updatedAt']) ?? fallbackTimestamp,
      completedAt: _dateTime(json['completedAt']),
      source: _enumByName(
        TaskSource.values,
        json['source'] as String?,
        TaskSource.manual,
      ),
      relatedItemId: json['relatedItemId'] as String?,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static List<DateTime> _dateTimeList(Object? value) {
    if (value is! List<Object?>) {
      return const <DateTime>[];
    }

    return value.map(_dateTime).whereType<DateTime>().toList(growable: false);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
