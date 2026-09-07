import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/task_category.dart';
import 'package:routine/screens/category_screen.dart';
import 'package:routine/screens/task_editor_dialog.dart';

import 'support/memory_task_repository.dart';

void main() {
  for (final width in [320.0, 1100.0]) {
    testWidgets('category CRUD and validation at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TaskController(repository: MemoryTaskRepository());
      await controller.load();
      await tester.pumpWidget(
        CupertinoApp(home: CategoryScreen(controller: controller)),
      );
      await tester.tap(find.byKey(const ValueKey('add-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      expect(find.text('Bitte einen Kategorienamen eingeben.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Choir',
      );
      await tester.tap(find.byKey(const ValueKey('icon-heart')));
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      final category = controller.categoryItems.last;
      expect(category.name, 'Choir');
      expect(category.icon, 'heart');
      await controller.addTask(title: 'Sing', categoryId: category.id);
      await tester.tap(find.text('Choir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Ensemble',
      );
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      expect(find.text('Ensemble'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('delete-category-${category.id}')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Alle zugehörigen Aufgaben bleiben erhalten'),
        findsOneWidget,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(controller.tasks.single.categoryId, category.id);
      await tester.tap(find.byKey(ValueKey('delete-category-${category.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(controller.tasks.single.categoryId, isNull);
      expect(controller.tasks.single.title, 'Sing');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('open dropdown follows rename and deletion on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TaskController(repository: MemoryTaskRepository());
    await controller.load();
    final category = controller.categoryItems.first;
    await controller.addTask(title: 'Test', categoryId: category.id);
    await tester.pumpWidget(
      CupertinoApp(
        home: TaskEditorDialog(
          controller: controller,
          task: controller.tasks.single,
        ),
      ),
    );
    await controller.saveCategory(
      id: category.id,
      name: 'A very long category name to check narrow layouts',
      color: TaskCategory.colors.first,
      icon: 'star',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('A very long category name to check narrow layouts'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('category-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(tester.takeException(), isNull);
    await controller.deleteCategory(category.id);
    await tester.pumpAndSettle();
    expect(find.textContaining('A very long category'), findsNothing);
    expect(find.text('Ohne Kategorie'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
