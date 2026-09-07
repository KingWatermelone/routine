import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/organizer_data.dart';
import 'package:routine/models/task.dart';
import 'package:routine/models/task_category.dart';

import 'support/memory_task_repository.dart';

void main() {
  final now = DateTime(2026, 9, 7);
  Task legacy(String id, String category) => Task(
    id: id,
    title: id,
    category: category,
    description: 'Keep me',
    tags: ['tag'],
    createdAt: now,
    updatedAt: now,
  );

  test(
    'migrates custom names, normalizes duplicates, preserves every task',
    () {
      final data = OrganizerData.migrate([
        legacy('a', ' Choir '),
        legacy('b', 'choir'),
        legacy('c', ''),
      ]);
      expect(data.tasks, hasLength(3));
      expect(data.tasks[0].categoryId, data.tasks[1].categoryId);
      expect(data.tasks[2].categoryId, isNull);
      expect(data.categories.where((c) => c.name == 'Choir'), hasLength(1));
      expect(data.tasks.first.description, 'Keep me');
      expect(data.tasks.first.createdAt, now);
      expect(data.tasks.first.tags, ['tag']);
      final reloaded = OrganizerData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, Object?>,
      );
      expect(reloaded.toJson(), data.toJson());
      expect(
        (data.toJson()['tasks'] as List).first.containsKey('category'),
        isFalse,
      );
    },
  );

  test(
    'creates unique IDs, renames without changing links, persists and deletes',
    () async {
      final repo = MemoryTaskRepository();
      final controller = TaskController(repository: repo, now: () => now);
      await controller.load();
      await controller.saveCategory(
        name: 'Choir',
        color: TaskCategory.colors.first,
        icon: 'heart',
      );
      await controller.saveCategory(
        name: 'Travel',
        color: TaskCategory.colors.last,
        icon: 'star',
      );
      expect(
        controller.categoryItems.map((c) => c.id).toSet().length,
        controller.categoryItems.length,
      );
      final id = controller.categoryItems
          .firstWhere((c) => c.name == 'Choir')
          .id;
      await controller.addTask(title: 'Rehearsal', categoryId: id);
      controller.setCategoryFilter(id);
      await controller.saveCategory(
        id: id,
        name: ' Ensemble ',
        color: TaskCategory.colors.last,
        icon: 'star',
      );
      expect(controller.visibleTasks.single.categoryId, id);
      expect(controller.categoryName(id), 'Ensemble');
      final restarted = TaskController(repository: repo);
      await restarted.load();
      expect(restarted.tasks.single.categoryId, id);
      expect(restarted.categoryById(id)!.icon, 'star');
      expect(restarted.categoryById(id)!.color, TaskCategory.colors.last);
      restarted.setCategoryFilter(id);
      await restarted.deleteCategory(id);
      expect(restarted.tasks, hasLength(1));
      expect(restarted.tasks.single.categoryId, isNull);
      expect(restarted.categoryFilter, isNull);
      final again = TaskController(repository: repo);
      await again.load();
      expect(again.tasks.single.categoryId, isNull);
      expect(again.categoryById(id), isNull);
      again.setCategoryFilter('');
      expect(again.visibleTasks, hasLength(1));
    },
  );

  test('rejects blank and case-insensitive duplicate category names', () async {
    final controller = TaskController(repository: MemoryTaskRepository());
    await controller.load();
    for (final name in ['', '  ', ' work ', 'WORK']) {
      await expectLater(
        controller.saveCategory(
          name: name,
          color: TaskCategory.colors.first,
          icon: 'folder',
        ),
        throwsA(isA<TaskValidationException>()),
      );
    }
    await expectLater(
      controller.addTask(title: 'Bad link', categoryId: 'missing'),
      throwsA(isA<TaskValidationException>()),
    );
  });

  test(
    'all categories may be removed without returning after reload',
    () async {
      final repo = MemoryTaskRepository();
      final controller = TaskController(repository: repo);
      await controller.load();
      for (final category in controller.categoryItems) {
        await controller.deleteCategory(category.id);
      }
      final restarted = TaskController(repository: repo);
      await restarted.load();
      expect(restarted.categoryItems, isEmpty);
      await restarted.addTask(title: 'Uncategorized', categoryId: '');
      expect(restarted.tasks.single.categoryId, isNull);
    },
  );
}
