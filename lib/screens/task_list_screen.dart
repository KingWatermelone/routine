import 'package:flutter/cupertino.dart';
import '../models/task.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Task> tasks = [
    Task(
      id: '1',
      title: 'Test the Flutter application',
      category: 'Development',
    ),
  ];

  void addTask(String title) {
    setState(() {
      tasks.add(
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
        ),
      );
    });
  }

  void toggleTask(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
  }

  void deleteTask(Task task) {
    setState(() {
      tasks.remove(task);
    });
  }

  Future<void> showAddTaskDialog() async {
    final controller = TextEditingController();

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('New Task'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: 'What needs to be done?',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                submitTask(controller, dialogContext);
              },
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                submitTask(controller, dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> showEditTaskDialog(Task task) async {
    final titleController = TextEditingController(
      text: task.title,
    );

    final descriptionController = TextEditingController(
      text: task.description,
    );

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Edit Task'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: titleController,
                  autofocus: true,
                  placeholder: 'Task title',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: descriptionController,
                  placeholder: 'Description',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                saveEditedTask(
                  task,
                  titleController,
                  descriptionController,
                  dialogContext,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  void saveEditedTask(
      Task task,
      TextEditingController titleController,
      TextEditingController descriptionController,
      BuildContext dialogContext,
      ) {
    final newTitle = titleController.text.trim();
    final newDescription = descriptionController.text.trim();

    if (newTitle.isEmpty) {
      return;
    }

    setState(() {
      task.title = newTitle;
      task.description = newDescription;
    });

    Navigator.of(dialogContext).pop();
  }

  void submitTask(
      TextEditingController controller,
      BuildContext dialogContext,
      ) {
    final title = controller.text.trim();

    if (title.isEmpty) {
      return;
    }

    addTask(title);
    Navigator.of(dialogContext).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Tasks'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: showAddTaskDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: tasks.isEmpty
            ? const Center(
          child: Text(
            'No tasks yet',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        )
            : ListView(
          padding: const EdgeInsets.only(
            top: 20,
            bottom: 20,
          ),
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('MY TASKS'),
              children: tasks.map(buildTaskTile).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTaskTile(Task task) {
    return CupertinoListTile(
      onTap: () {
        showEditTaskDialog(task);
      },
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          toggleTask(task);
        },
        child: Icon(
          task.isCompleted
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.circle,
          color: task.isCompleted
              ? CupertinoColors.systemGreen
              : CupertinoColors.systemGrey,
        ),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          color: task.isCompleted
              ? CupertinoColors.secondaryLabel
              : CupertinoColors.label,
          decoration: task.isCompleted
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: task.description.isEmpty
          ? Text(task.category)
          : Text('${task.category} · ${task.description}'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          showDeleteConfirmation(task);
        },
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.systemRed,
          size: 20,
        ),
      ),
    );
  }

  Future<void> showDeleteConfirmation(Task task) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Delete Task?'),
          content: Text(
            '"${task.title}" will be permanently removed.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                deleteTask(task);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}