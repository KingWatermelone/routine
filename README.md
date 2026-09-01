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

Operating-system notifications and custom-category management are planned next.

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
