import 'package:flutter/cupertino.dart';
import '../models/task.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {

  static const List<String> categories = [
    'Personal',
    'Work',
    'Study',
    'Home',
    'Shopping',
  ];

  final List<Task> tasks = [
    Task(
      id: '1',
      title: 'Test the Flutter application',
      category: 'Development',
    ),
  ];

  Color categoryColor(String category) {
    switch (category) {
      case 'Work':
        return CupertinoColors.systemBlue;

      case 'Study':
        return CupertinoColors.systemPurple;

      case 'Home':
        return CupertinoColors.systemOrange;

      case 'Shopping':
        return CupertinoColors.systemGreen;

      case 'Personal':
      default:
        return CupertinoColors.systemPink;
    }
  }


  void addTask(String title, String category) {
    setState(() {
      tasks.add(
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          category: category,
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

  Widget buildCategoryDropdown({
    required String selectedCategory,
    required ValueChanged<String> onSelected,
  }) {
    return CupertinoMenuAnchor(
      menuChildren: categories.map((category) {
        return CupertinoMenuItem(
          leading: Icon(
            category == selectedCategory
                ? CupertinoIcons.check_mark
                : CupertinoIcons.circle,
            size: 16,
            color: categoryColor(category),
          ),
          onPressed: () {
            onSelected(category);
          },
          child: Text(category),
        );
      }).toList(),
      builder: (
          BuildContext context,
          MenuController controller,
          Widget? child,
          ) {
        return SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color: CupertinoColors.tertiarySystemFill,
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: categoryColor(selectedCategory),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(selectedCategory),
                  ],
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 15,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showAddTaskDialog() async {
    final titleController = TextEditingController();
    String selectedCategory = categories.first;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('New Task'),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: titleController,
                    autofocus: true,
                    placeholder: 'What needs to be done?',
                    textInputAction: TextInputAction.done,

                    // Desktop-friendly cursor
                    cursorWidth: 1,
                    // cursorHeight: 18,
                    cursorRadius: Radius.zero,
                    cursorOpacityAnimates: false,
                    cursorColor: CupertinoColors.systemBlue,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                    ),
                    onSubmitted: (_) {
                      submitTask(
                        titleController,
                        selectedCategory,
                        dialogContext,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildCategoryDropdown(
                    selectedCategory: selectedCategory,
                    onSelected: (category) {
                      setDialogState(() {
                        selectedCategory = category;
                      });
                    },
                  ),
                ],
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
                    submitTask(
                      titleController,
                      selectedCategory,
                      dialogContext,
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
  }

  Future<void> showEditTaskDialog(Task task) async {
    final titleController = TextEditingController(
      text: task.title,
    );

    final descriptionController = TextEditingController(
      text: task.description,
    );

    String selectedCategory = categories.contains(task.category)
        ? task.category
        : categories.first;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('Edit Task'),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: titleController,
                    autofocus: true,
                    placeholder: 'Task title',
                    textInputAction: TextInputAction.next,
                    cursorWidth: 1,
                    cursorHeight: 18,
                    cursorRadius: Radius.zero,
                    cursorOpacityAnimates: false,
                    cursorColor: CupertinoColors.systemBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: descriptionController,
                    placeholder: 'Description',
                    maxLines: 3,
                    cursorWidth: 1,
                    cursorHeight: 18,
                    cursorRadius: Radius.zero,
                    cursorOpacityAnimates: false,
                    cursorColor: CupertinoColors.systemBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildCategoryDropdown(
                    selectedCategory: selectedCategory,
                    onSelected: (category) {
                      setDialogState(() {
                        selectedCategory = category;
                      });
                    },
                  ),
                ],
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
                      selectedCategory,
                      dialogContext,
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
      String selectedCategory,
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
      task.category = selectedCategory;
    });

    Navigator.of(dialogContext).pop();
  }

  void submitTask(
      TextEditingController titleController,
      String selectedCategory,
      BuildContext dialogContext,
      ) {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      return;
    }

    addTask(title, selectedCategory);
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
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: categoryColor(task.category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.description.isEmpty
                  ? task.category
                  : '${task.category} · ${task.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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