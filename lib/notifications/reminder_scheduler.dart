import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart'
    as windows_notifications;
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

abstract interface class ReminderScheduler {
  Future<String?> synchronize(
    List<Task> tasks, {
    bool requestPermission = false,
  });
  Future<void> openSettings();
}

ReminderScheduler? reminderSchedulerForPlatform({
  WindowsNotificationClient? windowsClient,
}) {
  if (kIsWeb) return null;
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return AppleReminderScheduler();
  }
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsReminderScheduler(client: windowsClient);
  }
  return null;
}

class AppleReminderScheduler implements ReminderScheduler {
  AppleReminderScheduler({MethodChannel? channel, DateTime Function()? now})
    : _channel = channel ?? const MethodChannel('routine/reminders'),
      _now = now ?? DateTime.now;

  final MethodChannel _channel;
  final DateTime Function() _now;

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

class WindowsReminder {
  const WindowsReminder({
    required this.id,
    required this.taskId,
    required this.title,
    required this.time,
  });

  final int id;
  final String taskId;
  final String title;
  final DateTime time;
}

abstract interface class WindowsNotificationClient {
  Future<bool> initialize();
  Future<bool> notificationsEnabled();
  Future<Set<int>> pendingNotificationIds();
  Future<void> cancel(int id);
  Future<void> schedule(WindowsReminder reminder);
  Future<void> openSettings();
}

class FlutterWindowsNotificationClient implements WindowsNotificationClient {
  FlutterWindowsNotificationClient({
    windows_notifications.FlutterLocalNotificationsWindows? plugin,
    MethodChannel? settingsChannel,
  }) : _plugin =
           plugin ?? windows_notifications.FlutterLocalNotificationsWindows(),
       _settingsChannel =
           settingsChannel ?? const MethodChannel('routine/reminders');

  static const _settings = windows_notifications.WindowsInitializationSettings(
    appName: 'Routine',
    appUserModelId: 'KingWatermelone.Routine',
    guid: '6a63e7b2-cb4f-4ca8-a3e2-6453609bc623',
  );

  final windows_notifications.FlutterLocalNotificationsWindows _plugin;
  final MethodChannel _settingsChannel;
  bool? _initialized;

  @override
  Future<bool> initialize() async =>
      _initialized ??= await _plugin.initialize(settings: _settings);

  @override
  Future<bool> notificationsEnabled() async =>
      await _settingsChannel.invokeMethod<bool>('notificationsEnabled') ??
      false;

  @override
  Future<Set<int>> pendingNotificationIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toSet();

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(WindowsReminder reminder) => _plugin.zonedSchedule(
    id: reminder.id,
    title: reminder.title,
    body: 'Aufgabe ist fällig.',
    scheduledDate: tz.TZDateTime.from(reminder.time.toUtc(), tz.UTC),
    payload: reminder.taskId,
  );

  @override
  Future<void> openSettings() =>
      _settingsChannel.invokeMethod<void>('openSettings');
}

class WindowsReminderScheduler implements ReminderScheduler {
  WindowsReminderScheduler({
    WindowsNotificationClient? client,
    DateTime Function()? now,
  }) : _client = client ?? FlutterWindowsNotificationClient(),
       _now = now ?? DateTime.now;

  static const int _namespaceStart = 0x40000000;
  static const int _namespaceMask = 0x3fffffff;
  static const int _pendingLimit = 64;

  final WindowsNotificationClient _client;
  final DateTime Function() _now;

  @visibleForTesting
  static bool ownsNotificationId(int id) =>
      id >= _namespaceStart && id <= _namespaceStart + _namespaceMask;

  @override
  Future<String?> synchronize(
    List<Task> tasks, {
    bool requestPermission = false,
  }) async {
    if (!await _client.initialize()) {
      return 'Windows-Benachrichtigungen konnten nicht initialisiert werden. '
          'Bitte die Mitteilungseinstellungen prüfen.';
    }

    final reminders = _buildReminders(tasks);
    final pendingIds = await _client.pendingNotificationIds();
    for (final id in pendingIds.where(ownsNotificationId)) {
      await _client.cancel(id);
    }
    if (!await _client.notificationsEnabled()) {
      return reminders.isEmpty
          ? null
          : 'Mitteilungen sind unter Windows deaktiviert. Aktiviere sie '
                'unter Einstellungen → System → Benachrichtigungen → Routine.';
    }
    for (final reminder in reminders.take(_pendingLimit)) {
      await _client.schedule(reminder);
    }

    if (reminders.length > _pendingLimit) {
      return 'Windows plant nur die nächsten $_pendingLimit Erinnerungen. '
          'Öffne Routine später erneut, um weitere Erinnerungen einzuplanen.';
    }
    return null;
  }

  List<WindowsReminder> _buildReminders(List<Task> tasks) {
    final now = _now();
    final byKey = <String, ({Task task, DateTime time})>{};
    for (final task in tasks.where((task) => !task.isCompleted)) {
      for (final time in task.reminders.where((time) => time.isAfter(now))) {
        final key = '${task.id}:${time.millisecondsSinceEpoch}';
        byKey[key] = (task: task, time: time);
      }
    }

    final entries = byKey.entries.toList()
      ..sort((first, second) {
        final timeOrder = first.value.time.compareTo(second.value.time);
        return timeOrder != 0 ? timeOrder : first.key.compareTo(second.key);
      });
    final usedIds = <int>{};
    return entries
        .map((entry) {
          var id = _notificationId(entry.key);
          while (!usedIds.add(id)) {
            id =
                _namespaceStart + ((id - _namespaceStart + 1) & _namespaceMask);
          }
          return WindowsReminder(
            id: id,
            taskId: entry.value.task.id,
            title: entry.value.task.title,
            time: entry.value.time,
          );
        })
        .toList(growable: false);
  }

  static int _notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final byte in key.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return _namespaceStart + (hash & _namespaceMask);
  }

  @override
  Future<void> openSettings() => _client.openSettings();
}
