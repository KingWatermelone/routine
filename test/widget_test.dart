import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/screens/task_list_screen.dart';

import 'support/memory_task_repository.dart';

void main() {
  testWidgets('fits a narrow mobile layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(home: TaskListScreen(repository: MemoryTaskRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('task-search-field')),
      findsOneWidget,
    );
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates, validates and completes a task', (
    WidgetTester tester,
  ) async {
    final MemoryTaskRepository repository = MemoryTaskRepository();
    await tester.pumpWidget(
      CupertinoApp(home: TaskListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No open tasks'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('add-task-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('save-task-button')));
    await tester.pump();
    expect(find.text('Enter a title for the task.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('task-title-field')),
      'Book dentist appointment',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-task-button')));
    await tester.pumpAndSettle();

    expect(find.text('Book dentist appointment'), findsOneWidget);
    expect(repository.storedTasks, hasLength(1));

    final String taskId = repository.storedTasks.single.id;
    await tester.tap(find.byKey(ValueKey<String>('toggle-task-$taskId')));
    await tester.pumpAndSettle();
    expect(find.text('No open tasks'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Book dentist appointment'), findsOneWidget);
  });

  testWidgets('search filters the visible task list', (
    WidgetTester tester,
  ) async {
    final MemoryTaskRepository repository = MemoryTaskRepository();
    await tester.pumpWidget(
      CupertinoApp(home: TaskListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-title-field')),
      'Buy printer paper',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-task-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('task-search-field')),
      'dentist',
    );
    await tester.pump();

    expect(find.text('No matching tasks'), findsOneWidget);
    expect(find.text('Buy printer paper'), findsNothing);
  });
}
