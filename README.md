# routine

Routine is a cross-platform personal organizer built with Flutter. The current
MVP focuses on an offline-first to-do list.

## Current functionality

- Create, edit, complete, reopen and delete tasks
- Add descriptions, categories, priorities, due dates and multiple reminders
- Search tasks and filter by status, category and priority
- Persist tasks locally across application restarts
- Preserve source and related-item fields for future organizer modules
- Validate empty titles and reminders that occur after a due date

## Date views

Use the date dropdown below the status selector:
- **Alle Termine**: all due dates, including tasks without a due date (default).
- **Heute**: due on the current local calendar day, including earlier today.
- **Demnächst**: due from tomorrow's local midnight onward.
- **Überfällig**: open tasks with a due time strictly earlier than now.

Date filtering combines with status, category, priority and search. Completed
tasks can be inspected by due date too, but never count as overdue. Tasks without
a due date appear only in Alle Termine. Existing due-date ordering is preserved.
Calendar boundaries account for local days rather than assuming 24-hour days.
While foregrounded the list refreshes every minute; on resume it refreshes
immediately, so day/time-zone changes are reflected without restarting. Filters
are session-only and do not change task data or the notification schedule.

Date-view validation: added controller boundary/combination/rollover tests and
320/1100px widget tests. Dart formatting/parsing and diff checks were completed;
Flutter analyzer/tests remain unexecuted due to the previously documented
bootstrap security stop. Manually check date dropdowns and combining filters,
including tasks before/at midnight and tasks without dates, before merging.

## Custom categories

Open the folder button at the top left of Tasks to create, rename, recolor,
change the icon of, or delete categories. Tap a category to edit it. The task
editor uses a dropdown menu, including an explicit **Ohne Kategorie** option.
The filter also supports tasks without a category. Deleting a category requires
confirmation and preserves all its tasks without a category assignment.

Category names are trimmed and compared case-insensitively for duplicates.
Tasks reference stable category IDs; renaming never changes task assignments.
Category names, colors and icons update immediately in the list, filter and editor.

### Storage migration

The first launch migrates `routine.tasks.v1` to the versioned
`routine.organizer.v2` record, containing both tasks and categories. Nonstandard
legacy categories are included; equivalent names are consolidated. The original
v1 record is retained unchanged as a backup. Migration only completes after the
new record is saved successfully. Subsequent launches use v2 and do not re-create
deleted categories. Returning to an older app version reads the old backup, not
new changes. Malformed or unsupported stored data causes a visible load error
instead of overwriting the data with defaults.

Writes are serialized and category deletion saves tasks and categories in one
record. Storage failures are displayed; the category screen offers a retry.
This remains SharedPreferences-based local storage, not a transactional database
or a cloud backup.

iOS local notifications are available on `main`. This branch adds the same
native scheduling behavior for macOS. Windows still only stores reminder times.
Cursor styling is unchanged.

## iOS reminders

The app uses Apple's UserNotifications framework through a Flutter MethodChannel,
with no additional Dart package or remote push service. It requests alert/sound
permission when saving future reminders, never on a plain launch. Permission
denial and scheduling failures appear separately from storage errors, with retry
and an iOS Settings button. Returning from Settings refreshes the schedule.

After a successful local save, open tasks' future reminders are reconciled with
iOS. Completing/deleting tasks or removing reminders cancels their pending
requests; changing a title/time updates them. Reopening a completed task does
not restore cleared reminders. Past reminders are not replayed. Scheduling is
serialized with saves to avoid older operations overwriting newer schedules.
If local saving fails, notifications retain the last saved state; resolve the
visible storage error before closing the app. After a crash between saving and
scheduling, the next launch reconciles the persisted state.

The conservative pending-request budget is 64 across the app. The nearest future
reminders fit first; excess reminders remain stored and a warning tells the user
to reopen the app for replenishment. There is no background replenishment while
the app stays closed. Foreign notification identifiers are preserved.

Scheduled requests are delivered by iOS even when the app is closed, subject to
permission, Focus, notification summaries and device settings. Foreground
delivery requests a banner and sound too. Task titles appear in notifications.
Reminder times represent absolute instants (UTC in the native trigger); changing
the device time zone does not move them. Tapping a notification opens the app;
navigation to a specific task and notification action buttons are not included.

### Test on iPhone (Mac and Xcode required)

1. Check out `main`, run `flutter pub get`, `flutter analyze`, and
   `flutter test` on your Mac.
2. Open `ios/Runner.xcworkspace` in Xcode, select your development team and a
   unique bundle identifier under Signing & Capabilities, then select your iPhone.
   No Push Notifications entitlement or background mode is needed for local requests.
3. Run Runner on the phone. Create a task due in ten minutes with two reminders
   a few minutes ahead. Grant notification permission, background/close the app,
   lock the phone, and verify the notifications arrive.
4. Repeat while keeping the app foregrounded, then edit reminder times/title and
   verify old requests do not fire. Complete/delete a task before its reminders
   and verify they do not fire; repeat after relaunch.
5. Deny permission on a fresh installation, verify the explanation, enable it in
   Settings, return to Routine and verify scheduling resumes. Test Focus and
   disabled banners/sound separately.
6. Verify no replay of past reminders, duplicate-time deduplication, and the
   visible limit warning with more than 64 future reminders.
7. Run the RunnerTests scheme tests in Xcode for native request validation.

The integrated iOS version was built and tested locally, including delivery on
an iPhone. The simulator-only haptic and keyboard diagnostics observed during
that check did not correspond to functional failures.

Implementation references: [Apple local scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app),
[notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications),
and [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels).

## macOS reminders

The macOS runner exposes the same `routine/reminders` method channel as iOS and
uses Apple's UserNotifications framework without another Dart dependency. Future
reminders for open tasks are reconciled after successful saves, launch, and
resume. Editing, completing, or deleting a task removes obsolete requests.
Permission and scheduling errors remain separate from storage failures.

The app requests notification permission only when a user saves a future
reminder. Foreground reminders request a banner, sound, and Notification Center
entry. The settings action opens the Notifications pane when macOS accepts the
deep link and otherwise falls back to opening System Settings. Delivery remains
subject to the user's macOS notification, Focus, banner, and sound settings.

### Test on macOS

1. Check out `codex/macos-reminders` and run `flutter clean`,
   `flutter pub get`, `flutter analyze`, and `flutter test`.
2. Run `flutter run -d macos`. Create a task due in ten minutes with two future
   reminders and allow notifications when macOS asks.
3. Verify one reminder while Routine is foregrounded and another after fully
   quitting Routine. Confirm that the task title, banner, and sound are correct.
4. Change a task title and reminder time. Verify the old request does not fire.
   Complete and delete tasks before their reminders and verify cancellation.
5. Disable notifications under System Settings → Notifications → Routine.
   Verify the visible explanation and settings button, then re-enable them and
   retry scheduling.
6. Close and reopen Routine and verify that persisted reminders are reconciled
   without replaying past reminders.
7. Open `macos/Runner.xcworkspace` in Xcode and run the RunnerTests target.

This implementation environment has no available macOS/Flutter runtime, so
`flutter analyze`, `flutter test`, the macOS build, XCTest, and notification
delivery must be executed locally before merging this branch.

### Manual category check

1. Create a category with a color and icon using the folder button.
2. Assign it to a task using the task editor dropdown and filter by it.
3. Rename it and change its color/icon; the task should keep its assignment.
4. Restart the application and check both the category and task.
5. Delete the category and confirm that the task remains under Ohne Kategorie.
6. Try an empty name and a duplicate with different case/outer spaces.
7. Repeat with a narrow window and a wide desktop window.

## Run locally

```sh
flutter pub get
flutter run
```

Run the checks with:

```sh
flutter analyze
flutter test
```

The category, date-view, and iOS-reminder changes were subsequently validated
locally before integration. Platform-specific checks for new changes are listed
in their sections above.
