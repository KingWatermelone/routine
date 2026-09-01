import 'package:flutter/cupertino.dart';

import 'data/shared_preferences_task_repository.dart';
import 'screens/task_list_screen.dart';

void main() {
  runApp(const PersonalOrganizerApp());
}

class PersonalOrganizerApp extends StatelessWidget {
  const PersonalOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Personal Organizer',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: TaskListScreen(repository: SharedPreferencesTaskRepository()),
    );
  }
}
