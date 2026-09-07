import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';

abstract interface class ReminderScheduler {
  Future<String?> synchronize(
    List<Task> tasks, {
    bool requestPermission = false,
  });
  Future<void> openSettings();
}

class IosReminderScheduler implements ReminderScheduler {
  IosReminderScheduler({MethodChannel? channel, DateTime Function()? now})
    : _channel = channel ?? const MethodChannel('routine/reminders'),
      _now = now ?? DateTime.now;
  final MethodChannel _channel;
  final DateTime Function() _now;

  static ReminderScheduler? forPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? IosReminderScheduler()
      : null;

  @override
  Future<String?> synchronize(
    List<Task> tasks, {
    bool requestPermission = false,
  }) async {
    final now = _now();
    final reminders = <String, Map<String, Object>>{};
    for (final task in tasks.where((task) => !task.isCompleted)) {
      for (final time in task.reminders.where((time) => time.isAfter(now))) {
        final id =
            'routine.${Uri.encodeComponent(task.id)}.${time.millisecondsSinceEpoch}';
        reminders[id] = {
          'id': id,
          'title': task.title,
          'time': time.millisecondsSinceEpoch,
        };
      }
    }
    final sorted = reminders.values.toList()
      ..sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));
    return _channel.invokeMethod<String>('synchronize', {
      'reminders': sorted,
      'requestPermission': requestPermission && sorted.isNotEmpty,
    });
  }

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}
