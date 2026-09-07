import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/controllers/task_controller.dart';
import 'package:routine/models/task.dart';
import 'package:routine/notifications/reminder_scheduler.dart';

import 'support/memory_task_repository.dart';

class RecordingScheduler implements ReminderScheduler {
  final List<List<Task>> snapshots = [];
  final List<bool> permissionRequests = [];
  bool fail = false;
  @override
  Future<String?> synchronize(
    List<Task> tasks, {
    bool requestPermission = false,
  }) async {
    if (fail) throw PlatformException(code: 'schedule');
    snapshots.add(List.of(tasks));
    permissionRequests.add(requestPermission);
    return null;
  }

  @override
  Future<void> openSettings() async {}
}

class FailingRepository extends MemoryTaskRepository {
  bool fail = false;
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    if (fail) throw StateError('Storage unavailable');
    await super.saveTasks(tasks);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 7, 12);
  const channel = MethodChannel('routine/reminders-test');

  test('failed save keeps the last persisted notification state', () async {
    final repo = FailingRepository();
    final scheduler = RecordingScheduler();
    final controller = TaskController(
      repository: repo,
      reminderScheduler: scheduler,
    );
    await controller.load();
    await controller.addTask(title: 'Saved');
    final calls = scheduler.snapshots.length;
    repo.fail = true;
    await controller.deleteTask(controller.tasks.single);
    expect(controller.storageError, isNotNull);
    expect(scheduler.snapshots.length, calls);
    await controller.refreshReminders();
    expect(scheduler.snapshots.length, calls);
    repo.fail = false;
    await controller.retrySave();
    expect(scheduler.snapshots.last, isEmpty);
  });

  test('rapid mutations finish with the newest schedule', () async {
    final scheduler = RecordingScheduler();
    final controller = TaskController(
      repository: MemoryTaskRepository(),
      reminderScheduler: scheduler,
    );
    await controller.load();
    final adding = controller.addTask(title: 'Temporary');
    final deleting = controller.deleteTask(controller.tasks.single);
    await Future.wait([adding, deleting]);
    expect(
      scheduler.snapshots[scheduler.snapshots.length - 2].single.title,
      'Temporary',
    );
    expect(scheduler.snapshots.last, isEmpty);
  });

  test(
    'channel excludes past/completed reminders and deduplicates stable IDs',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final time = now.add(const Duration(minutes: 5));
      final task = Task(
        id: 'task/a',
        title: 'Practice',
        createdAt: now,
        updatedAt: now,
        reminders: [now.subtract(const Duration(minutes: 1)), time, time],
      );
      final scheduler = IosReminderScheduler(channel: channel, now: () => now);
      await scheduler.synchronize([
        task,
        task.copyWith(isCompleted: true),
      ], requestPermission: true);
      final args = calls.single.arguments as Map;
      expect(args['requestPermission'], isTrue);
      final reminder = (args['reminders'] as List).single as Map;
      expect(reminder['time'], time.millisecondsSinceEpoch);
      expect(reminder['title'], 'Practice');
      final id = reminder['id'];
      await scheduler.synchronize([task.copyWith(title: 'Renamed')]);
      expect(
        ((calls.last.arguments as Map)['reminders'] as List).single['id'],
        id,
      );
      await scheduler.synchronize([], requestPermission: true);
      expect((calls.last.arguments as Map)['requestPermission'], isFalse);
      expect((calls.last.arguments as Map)['reminders'], isEmpty);
      await scheduler.openSettings();
      expect(calls.last.method, 'openSettings');
    },
  );

  test(
    'load, edit, completion, reopen and deletion reconcile persisted snapshots',
    () async {
      final repo = MemoryTaskRepository();
      final scheduler = RecordingScheduler();
      final controller = TaskController(
        repository: repo,
        reminderScheduler: scheduler,
        now: () => now,
      );
      await controller.load();
      expect(scheduler.permissionRequests.single, isFalse);
      await controller.addTask(
        title: 'Practice',
        dueDate: now.add(const Duration(hours: 1)),
        reminders: [now.add(const Duration(minutes: 5))],
      );
      final task = controller.tasks.single;
      expect(
        scheduler.snapshots.last.single.toJson(),
        repo.storedTasks.single.toJson(),
      );
      await controller.updateTask(
        task.copyWith(
          title: 'Rehearsal',
          reminders: [now.add(const Duration(minutes: 10))],
        ),
      );
      expect(scheduler.snapshots.last.single.title, 'Rehearsal');
      await controller.toggleTask(controller.tasks.single);
      expect(scheduler.snapshots.last.single.reminders, isEmpty);
      await controller.toggleTask(controller.tasks.single);
      expect(scheduler.snapshots.last.single.reminders, isEmpty);
      await controller.deleteTask(controller.tasks.single);
      expect(scheduler.snapshots.last, isEmpty);
    },
  );

  test(
    'scheduling failure does not discard tasks; retry clears separate error',
    () async {
      final repo = MemoryTaskRepository();
      final scheduler = RecordingScheduler();
      final controller = TaskController(
        repository: repo,
        reminderScheduler: scheduler,
      );
      await controller.load();
      scheduler.fail = true;
      await controller.addTask(title: 'Keep me');
      expect(repo.storedTasks.single.title, 'Keep me');
      expect(controller.storageError, isNull);
      expect(controller.reminderError, isNotNull);
      scheduler.fail = false;
      await controller.refreshReminders();
      expect(controller.reminderError, isNull);
    },
  );
}
