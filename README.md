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

Operating-system notifications are still planned; saved reminder times do not
yet trigger notifications. Cursor styling is unchanged.

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

Verification for the custom-category change: Dart formatting/parsing and
`git diff --check` completed. `flutter analyze`, `flutter test`, and native/browser
runtime checks were not completed in the implementation environment: Flutter
tool bootstrap was stopped by a security check after an unexpected request to a
cloud metadata endpoint. The added tests must be run locally before merging.
