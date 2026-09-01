import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/task.dart';

import 'support/memory_task_repository.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 1, 10);

  Task task({
    required String id,
    required String title,
    String category = 'Personal',
    TaskPriority priority = TaskPriority.normal,
    bool completed = false,
  }) {
    return Task(
      id: id,
      title: title,
      category: category,
      priority: priority,
      isCompleted: completed,
      createdAt: now,
      updatedAt: now,
      completedAt: completed ? now : null,
    );
  }

  test('loads tasks and shows open tasks by default', () async {
    final MemoryTaskRepository repository = MemoryTaskRepository(
      initialTasks: <Task>[
        task(id: 'open', title: 'Open task'),
        task(id: 'done', title: 'Done task', completed: true),
      ],
    );
    final TaskController controller = TaskController(repository: repository);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.tasks, hasLength(2));
    expect(controller.visibleTasks.single.id, 'open');
  });

  test('adds and persists a fully initialized task', () async {
    final MemoryTaskRepository repository = MemoryTaskRepository();
    final TaskController controller = TaskController(
      repository: repository,
      now: () => now,
    );
    await controller.load();

    await controller.addTask(
      title: '  Write report  ',
      description: '  Add the figures  ',
      category: 'Work',
      priority: TaskPriority.high,
      dueDate: now.add(const Duration(days: 1)),
      reminders: <DateTime>[now.add(const Duration(hours: 2))],
    );

    expect(repository.saveCount, 1);
    final Task savedTask = repository.storedTasks.single;
    expect(savedTask.title, 'Write report');
    expect(savedTask.description, 'Add the figures');
    expect(savedTask.createdAt, now);
    expect(savedTask.updatedAt, now);
    expect(savedTask.priority, TaskPriority.high);
  });

  test(
    'generates unique IDs when tasks are created at the same instant',
    () async {
      final MemoryTaskRepository repository = MemoryTaskRepository();
      final TaskController controller = TaskController(
        repository: repository,
        now: () => now,
      );
      await controller.load();

      await controller.addTask(title: 'First task');
      await controller.addTask(title: 'Second task');

      expect(
        repository.storedTasks.map((Task task) => task.id).toSet(),
        hasLength(2),
      );
    },
  );

  test('search, status, category and priority filters combine', () async {
    final MemoryTaskRepository repository = MemoryTaskRepository(
      initialTasks: <Task>[
        task(
          id: '1',
          title: 'Prepare report',
          category: 'Work',
          priority: TaskPriority.high,
        ),
        task(
          id: '2',
          title: 'Read chapter',
          category: 'Study',
          priority: TaskPriority.low,
        ),
        task(
          id: '3',
          title: 'Old report',
          category: 'Work',
          priority: TaskPriority.high,
          completed: true,
        ),
      ],
    );
    final TaskController controller = TaskController(repository: repository);
    await controller.load();

    controller
      ..setSearchQuery('report')
      ..setCategoryFilter('Work')
      ..setPriorityFilter(TaskPriority.high);

    expect(controller.visibleTasks.map((Task task) => task.id), <String>['1']);

    controller.setStatusFilter(TaskStatusFilter.completed);
    expect(controller.visibleTasks.map((Task task) => task.id), <String>['3']);
  });

  test('completing a task timestamps it and clears reminders', () async {
    final Task openTask = Task(
      id: '1',
      title: 'Call client',
      reminders: <DateTime>[now.add(const Duration(hours: 1))],
      dueDate: now.add(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    );
    final MemoryTaskRepository repository = MemoryTaskRepository(
      initialTasks: <Task>[openTask],
    );
    final TaskController controller = TaskController(
      repository: repository,
      now: () => now,
    );
    await controller.load();

    await controller.toggleTask(openTask);

    final Task completedTask = repository.storedTasks.single;
    expect(completedTask.isCompleted, isTrue);
    expect(completedTask.completedAt, now);
    expect(completedTask.reminders, isEmpty);
  });

  test('rejects empty titles and reminders after the due date', () async {
    final TaskController controller = TaskController(
      repository: MemoryTaskRepository(),
      now: () => now,
    );
    await controller.load();

    expect(
      () => controller.addTask(title: '   '),
      throwsA(isA<TaskValidationException>()),
    );
    expect(
      () => controller.addTask(
        title: 'Invalid reminder',
        dueDate: now.add(const Duration(hours: 1)),
        reminders: <DateTime>[now.add(const Duration(hours: 2))],
      ),
      throwsA(isA<TaskValidationException>()),
    );
  });
}
