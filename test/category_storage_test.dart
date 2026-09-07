import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/data/shared_preferences_task_repository.dart';
import 'package:routine/models/task.dart';
import 'package:routine/models/task_category.dart';

void main() {
  late Map<String, String> storage;
  late bool failWrite;
  SharedPreferencesTaskRepository repository() =>
      SharedPreferencesTaskRepository(
        readString: (key) async => storage[key],
        writeString: (key, value) async {
          if (failWrite) throw StateError('Disk unavailable');
          storage[key] = value;
        },
      );
  setUp(() {
    storage = {};
    failWrite = false;
  });

  test(
    'migration writes v2 once, leaves v1 unchanged and survives restart',
    () async {
      final now = DateTime(2026);
      final original = jsonEncode([
        Task(
          id: 'a',
          title: 'Practice',
          category: 'Choir',
          createdAt: now,
          updatedAt: now,
        ).toJson(),
      ]);
      storage['routine.tasks.v1'] = original;
      final data = await repository().loadData();
      expect(storage['routine.tasks.v1'], original);
      expect(storage['routine.organizer.v2'], isNotNull);
      final reloaded = await repository().loadData();
      expect(reloaded.toJson(), data.toJson());
      expect(
        reloaded.categories
            .firstWhere((c) => c.id == reloaded.tasks.single.categoryId)
            .name,
        'Choir',
      );
    },
  );

  test('failed migration preserves legacy data and can be retried', () async {
    storage['routine.tasks.v1'] = '[]';
    failWrite = true;
    await expectLater(repository().loadData(), throwsStateError);
    expect(storage, {'routine.tasks.v1': '[]'});
    failWrite = false;
    expect((await repository().loadData()).categories, hasLength(5));
  });

  test('corrupt and future-version data is not overwritten', () async {
    for (final entry in [
      {'routine.tasks.v1': 'invalid'},
      {'routine.organizer.v2': '{"version":99}'},
      {'routine.organizer.v2': 'invalid'},
    ]) {
      storage = Map.of(entry);
      final controller = TaskController(repository: repository());
      await controller.load();
      expect(controller.storageError, isNotNull);
      await expectLater(
        controller.addTask(title: 'Do not overwrite'),
        throwsA(isA<TaskValidationException>()),
      );
      await controller.retrySave();
      expect(storage, entry);
    }
  });

  test(
    'category write errors are visible and retry persists current data',
    () async {
      final controller = TaskController(repository: repository());
      await controller.load();
      failWrite = true;
      await controller.saveCategory(
        name: 'Choir',
        color: TaskCategory.colors.first,
        icon: 'heart',
      );
      expect(controller.storageError, isNotNull);
      failWrite = false;
      await controller.retrySave();
      expect(controller.storageError, isNull);
      final restarted = TaskController(repository: repository());
      await restarted.load();
      expect(restarted.categoryItems.last.name, 'Choir');
    },
  );
}
