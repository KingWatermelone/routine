import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/task.dart';
import 'package:routine/screens/task_list_screen.dart';

import 'support/memory_task_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  test('tags are normalized, persisted, searched and filtered', () async {
    final repository = MemoryTaskRepository();
    final controller = TaskController(repository: repository, now: () => now);
    await controller.load();

    await controller.addTask(
      title: 'Prepare rehearsal',
      description: 'Print scores',
      tags: const <String>[' Choir ', 'choir', '', 'Urgent'],
    );
    await controller.addTask(title: 'Buy milk', tags: const <String>['Home']);

    expect(controller.tasks.first.tags, <String>['Choir', 'Urgent']);
    expect(controller.tags, <String>['Choir', 'Home', 'Urgent']);

    controller.setTagFilter(' choir ');
    expect(controller.visibleTasks.single.title, 'Prepare rehearsal');
    controller
      ..setTagFilter(null)
      ..setSearchQuery('urgent');
    expect(controller.visibleTasks.single.title, 'Prepare rehearsal');

    final restarted = TaskController(repository: repository);
    await restarted.load();
    expect(restarted.tasks.first.tags, <String>['Choir', 'Urgent']);
  });

  test('all required task sort modes are selectable', () async {
    final tasks = <Task>[
      Task(
        id: 'work-high',
        title: 'Zulu',
        category: 'Work',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
      Task(
        id: 'home-low',
        title: 'Alpha',
        category: 'Home',
        priority: TaskPriority.low,
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'done',
        title: 'Done',
        category: '',
        isCompleted: true,
        createdAt: now.add(const Duration(days: 1)),
        updatedAt: now,
        completedAt: now,
      ),
    ];
    final controller = TaskController(
      repository: MemoryTaskRepository(initialTasks: tasks),
      now: () => now,
    );
    await controller.load();
    controller.setStatusFilter(TaskStatusFilter.all);

    controller.setSort(TaskSort.dueDate);
    expect(controller.visibleTasks.first.id, 'home-low');
    controller.setSort(TaskSort.priority);
    expect(controller.visibleTasks.first.id, 'work-high');
    controller.setSort(TaskSort.category);
    expect(controller.visibleTasks.first.id, 'home-low');
    controller.setSort(TaskSort.status);
    expect(controller.visibleTasks.last.id, 'done');
    controller.setSort(TaskSort.createdAt);
    expect(controller.visibleTasks.first.id, 'done');
  });

  for (final width in <double>[320, 1100]) {
    testWidgets('tag editor, list and filter fit at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryTaskRepository();

      await tester.pumpWidget(
        CupertinoApp(home: TaskListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-task-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Choir rehearsal',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-tag-field')),
        'Choir',
      );
      await tester.tap(find.byKey(const ValueKey('add-tag-button')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('task-tag-field')),
        ' choir ',
      );
      await tester.tap(find.byKey(const ValueKey('add-tag-button')));
      await tester.pump();
      expect(
        find.text('Dieses Tag wurde bereits hinzugefügt.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('task-tag-field')), '');
      await tester.tap(find.byKey(const ValueKey('save-task-button')));
      await tester.pumpAndSettle();

      expect(repository.storedTasks.single.tags, <String>['Choir']);
      expect(find.text('#Choir'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tag-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choir'));
      await tester.pumpAndSettle();
      expect(find.text('Choir rehearsal'), findsOneWidget);
      expect(find.byKey(const ValueKey('sort-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tag can be removed while editing a task', (tester) async {
    tester.view.physicalSize = const Size(1100, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryTaskRepository(
      initialTasks: <Task>[
        Task(
          id: '1',
          title: 'Tagged task',
          tags: const <String>['Temporary'],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(home: TaskListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tagged task'));
    await tester.pumpAndSettle();
    final removeButton = find.byKey(
      const ValueKey('remove-task-tag-Temporary'),
    );
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();

    expect(repository.storedTasks.single.tags, isEmpty);
    expect(find.text('#Temporary'), findsNothing);
  });
}
