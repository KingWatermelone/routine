import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/task.dart';
import 'package:routine/screens/task_list_screen.dart';

import 'support/memory_task_repository.dart';

void main() {
  final today = DateTime(2026, 9, 7);
  final now = DateTime(2026, 9, 7, 12);
  Task task(String id, DateTime? due, {bool completed = false}) => Task(
    id: id,
    title: id,
    dueDate: due,
    isCompleted: completed,
    createdAt: now,
    updatedAt: now,
  );
  List<Task> fixtures() => [
    task('yesterday', DateTime(2026, 9, 6, 23, 59)),
    task('midnight', today.toUtc()),
    task('noon', now),
    task('tonight', DateTime(2026, 9, 7, 23, 59, 59)),
    task('tomorrow', DateTime(2026, 9, 8)),
    task('later', DateTime(2026, 10, 1)),
    task('undated', null),
    task('completed', today, completed: true),
  ];

  test(
    'local day boundaries, UTC instants, overdue and undated tasks',
    () async {
      final controller = TaskController(
        repository: MemoryTaskRepository(initialTasks: fixtures()),
        now: () => now,
      );
      await controller.load();
      controller.setDateFilter(TaskDateFilter.today);
      expect(controller.visibleTasks.map((t) => t.id), [
        'midnight',
        'noon',
        'tonight',
      ]);
      controller.setDateFilter(TaskDateFilter.upcoming);
      expect(controller.visibleTasks.map((t) => t.id), ['tomorrow', 'later']);
      controller.setDateFilter(TaskDateFilter.overdue);
      expect(controller.visibleTasks.map((t) => t.id), [
        'yesterday',
        'midnight',
      ]);
      controller.setDateFilter(TaskDateFilter.all);
      expect(controller.visibleTasks.any((t) => t.id == 'undated'), isTrue);
    },
  );

  test('date combines with status, category, priority and search', () async {
    final controller = TaskController(
      repository: MemoryTaskRepository(initialTasks: fixtures()),
      now: () => now,
    );
    await controller.load();
    controller.setDateFilter(TaskDateFilter.today);
    controller.setStatusFilter(TaskStatusFilter.completed);
    expect(controller.visibleTasks.single.id, 'completed');
    controller.setStatusFilter(TaskStatusFilter.open);
    controller.setSearchQuery('noon');
    controller.setPriorityFilter(TaskPriority.normal);
    controller.setCategoryFilter(
      controller.categoryItems.firstWhere((c) => c.name == 'Personal').id,
    );
    expect(controller.visibleTasks.single.id, 'noon');
    controller.setPriorityFilter(TaskPriority.high);
    expect(controller.visibleTasks, isEmpty);
  });

  test(
    'day rollover recomputes membership without persisting anything',
    () async {
      var clock = now;
      final repo = MemoryTaskRepository(initialTasks: fixtures());
      final controller = TaskController(repository: repo, now: () => clock);
      await controller.load();
      controller.setDateFilter(TaskDateFilter.today);
      clock = DateTime(2026, 9, 8);
      var refreshed = false;
      controller.addListener(() => refreshed = true);
      controller.refreshDateFilters();
      expect(refreshed, isTrue);
      expect(controller.visibleTasks.single.id, 'tomorrow');
      expect(repo.saveCount, 0);
    },
  );

  for (final width in [320.0, 1100.0]) {
    testWidgets('date menu and rollover at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var clock = now;
      await tester.pumpWidget(
        CupertinoApp(
          home: TaskListScreen(
            repository: MemoryTaskRepository(initialTasks: fixtures()),
            now: () => clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('date-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();
      expect(find.text('noon'), findsOneWidget);
      expect(find.text('tomorrow'), findsNothing);
      clock = DateTime(2026, 9, 8);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('tomorrow'), findsOneWidget);
      expect(find.text('noon'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
