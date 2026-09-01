import 'package:flutter_test/flutter_test.dart';
import 'package:routine/models/task.dart';

void main() {
  test('task survives a JSON round trip', () {
    final DateTime createdAt = DateTime.utc(2026, 9, 1, 12);
    final Task task = Task(
      id: 'task-1',
      title: 'Prepare presentation',
      description: 'Finish the final slides',
      category: 'Study',
      tags: const <String>['university', 'slides'],
      isCompleted: true,
      priority: TaskPriority.high,
      dueDate: DateTime.utc(2026, 9, 3, 15),
      reminders: <DateTime>[DateTime.utc(2026, 9, 3, 12)],
      createdAt: createdAt,
      updatedAt: DateTime.utc(2026, 9, 2, 10),
      completedAt: DateTime.utc(2026, 9, 2, 11),
      source: TaskSource.calendar,
      relatedItemId: 'event-4',
    );

    final Task restored = Task.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.description, task.description);
    expect(restored.category, task.category);
    expect(restored.tags, task.tags);
    expect(restored.isCompleted, isTrue);
    expect(restored.priority, TaskPriority.high);
    expect(restored.dueDate, task.dueDate);
    expect(restored.reminders, task.reminders);
    expect(restored.createdAt, createdAt);
    expect(restored.completedAt, task.completedAt);
    expect(restored.source, TaskSource.calendar);
    expect(restored.relatedItemId, 'event-4');
  });

  test('older JSON receives safe defaults for new fields', () {
    final Task task = Task.fromJson(<String, Object?>{
      'id': 'legacy-task',
      'title': 'Legacy task',
    });

    expect(task.category, 'Personal');
    expect(task.priority, TaskPriority.normal);
    expect(task.source, TaskSource.manual);
    expect(task.tags, isEmpty);
    expect(task.reminders, isEmpty);
  });
}
