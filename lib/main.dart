import 'package:flutter/cupertino.dart';
import 'screens/task_list_screen.dart';

void main() {
  runApp(const PersonalOrganizerApp());
}

class PersonalOrganizerApp extends StatelessWidget {
  const PersonalOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Personal Organizer',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: TaskListScreen(),
    );
  }
}