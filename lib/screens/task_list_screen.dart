import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../controllers/task_controller.dart';
import '../data/task_repository.dart';
import '../models/task.dart';
import 'task_editor_dialog.dart';
import 'category_screen.dart';
import '../notifications/reminder_scheduler.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({required this.repository, super.key});

  final TaskRepository repository;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with WidgetsBindingObserver {
  late final TaskController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TaskController(
      repository: widget.repository,
      reminderScheduler: IosReminderScheduler.forPlatform(),
    )..addListener(_onControllerChanged);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      unawaited(_controller.refreshReminders());
  }

  Widget _reminderStatus() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        Text(
          _controller.reminderError!,
          style: const TextStyle(color: CupertinoColors.systemRed),
        ),
        Wrap(
          children: [
            CupertinoButton(
              onPressed: () =>
                  _controller.refreshReminders(requestPermission: true),
              child: const Text('Erneut versuchen'),
            ),
            CupertinoButton(
              onPressed: _controller.openNotificationSettings,
              child: const Text('iOS-Einstellungen'),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Tasks'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          key: const ValueKey('manage-categories'),
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => CategoryScreen(controller: _controller),
            ),
          ),
          child: const Icon(CupertinoIcons.folder),
        ),
        trailing: CupertinoButton(
          key: const ValueKey<String>('add-task-button'),
          padding: EdgeInsets.zero,
          onPressed: _showAddTaskDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: <Widget>[
                _buildFilters(),
                if (_controller.storageError != null) _buildStorageError(),
                if (_controller.reminderError != null) _reminderStatus(),
                Expanded(child: _buildTaskContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: <Widget>[
          CupertinoSearchTextField(
            key: const ValueKey<String>('task-search-field'),
            controller: _searchController,
            placeholder: 'Search tasks',
            onChanged: _controller.setSearchQuery,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<TaskStatusFilter>(
              groupValue: _controller.statusFilter,
              children: const <TaskStatusFilter, Widget>{
                TaskStatusFilter.open: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Open'),
                ),
                TaskStatusFilter.completed: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Completed'),
                ),
                TaskStatusFilter.all: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('All'),
                ),
              },
              onValueChanged: (TaskStatusFilter? filter) {
                if (filter != null) {
                  _controller.setStatusFilter(filter);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _buildCategoryFilter()),
              const SizedBox(width: 10),
              Expanded(child: _buildPriorityFilter()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final String? selectedCategory = _controller.categoryFilter;
    return CupertinoMenuAnchor(
      menuChildren: <Widget>[
        CupertinoMenuItem(
          leading: Icon(
            selectedCategory == null
                ? CupertinoIcons.check_mark
                : CupertinoIcons.circle,
            size: 16,
          ),
          onPressed: () => _controller.setCategoryFilter(null),
          child: const Text('All categories'),
        ),
        ..._controller.categories.map((String category) {
          return CupertinoMenuItem(
            leading: Icon(
              selectedCategory == category
                  ? CupertinoIcons.check_mark
                  : _controller.categoryById(category)?.iconData ??
                        CupertinoIcons.folder,
              size: 16,
              color: Color(
                _controller.categoryById(category)?.color ?? 0xFF8E8E93,
              ),
            ),
            onPressed: () => _controller.setCategoryFilter(category),
            child: Text(_controller.categoryName(category)),
          );
        }),
      ],
      builder:
          (BuildContext context, MenuController menuController, Widget? child) {
            return _filterButton(
              key: const ValueKey<String>('category-filter-button'),
              label: selectedCategory == null
                  ? 'All categories'
                  : _controller.categoryName(selectedCategory),
              icon: CupertinoIcons.folder,
              onPressed: menuController.isOpen
                  ? menuController.close
                  : menuController.open,
            );
          },
    );
  }

  Widget _buildPriorityFilter() {
    final TaskPriority? selectedPriority = _controller.priorityFilter;
    return CupertinoMenuAnchor(
      menuChildren: <Widget>[
        CupertinoMenuItem(
          leading: Icon(
            selectedPriority == null
                ? CupertinoIcons.check_mark
                : CupertinoIcons.circle,
            size: 16,
          ),
          onPressed: () => _controller.setPriorityFilter(null),
          child: const Text('All priorities'),
        ),
        ...TaskPriority.values.map((TaskPriority priority) {
          return CupertinoMenuItem(
            leading: Icon(
              selectedPriority == priority
                  ? CupertinoIcons.check_mark
                  : CupertinoIcons.circle,
              size: 16,
            ),
            onPressed: () => _controller.setPriorityFilter(priority),
            child: Text(priorityLabel(priority)),
          );
        }),
      ],
      builder:
          (BuildContext context, MenuController menuController, Widget? child) {
            return _filterButton(
              key: const ValueKey<String>('priority-filter-button'),
              label: selectedPriority == null
                  ? 'All priorities'
                  : priorityLabel(selectedPriority),
              icon: CupertinoIcons.flag,
              onPressed: menuController.isOpen
                  ? menuController.close
                  : menuController.open,
            );
          },
    );
  }

  Widget _filterButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        color: CupertinoColors.tertiarySystemFill,
        onPressed: onPressed,
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(CupertinoIcons.chevron_down, size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageError() {
    return Container(
      key: const ValueKey<String>('storage-error'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _controller.storageError!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: _controller.clearStorageError,
            child: const Icon(CupertinoIcons.clear, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskContent() {
    if (_controller.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final List<Task> tasks = _controller.visibleTasks;
    if (tasks.isEmpty) {
      final bool hasFilters =
          _controller.searchQuery.trim().isNotEmpty ||
          _controller.categoryFilter != null ||
          _controller.priorityFilter != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                CupertinoIcons.check_mark_circled,
                color: CupertinoColors.systemGrey2,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                hasFilters ? 'No matching tasks' : _emptyMessage(),
                key: const ValueKey<String>('empty-task-message'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: <Widget>[
        CupertinoListSection.insetGrouped(
          header: Text(_sectionTitle()),
          children: tasks.map(_buildTaskTile).toList(),
        ),
      ],
    );
  }

  String _emptyMessage() {
    return switch (_controller.statusFilter) {
      TaskStatusFilter.open => 'No open tasks',
      TaskStatusFilter.completed => 'No completed tasks',
      TaskStatusFilter.all => 'No tasks yet',
    };
  }

  String _sectionTitle() {
    return switch (_controller.statusFilter) {
      TaskStatusFilter.open => 'OPEN TASKS',
      TaskStatusFilter.completed => 'COMPLETED TASKS',
      TaskStatusFilter.all => 'ALL TASKS',
    };
  }

  Widget _buildTaskTile(Task task) {
    final String metadata = <String>[
      _controller.categoryName(task.categoryId),
      priorityLabel(task.priority),
      if (task.dueDate != null) formatDateTime(task.dueDate!),
    ].join(' · ');

    return CupertinoListTile(
      key: ValueKey<String>('task-${task.id}'),
      onTap: () => _showEditTaskDialog(task),
      leading: CupertinoButton(
        key: ValueKey<String>('toggle-task-${task.id}'),
        padding: EdgeInsets.zero,
        onPressed: () => unawaited(_controller.toggleTask(task)),
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
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _controller.categoryById(task.categoryId)?.iconData ??
                    CupertinoIcons.folder,
                size: 14,
                color: Color(
                  _controller.categoryById(task.categoryId)?.color ??
                      0xFF8E8E93,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty)
            Text(
              task.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: CupertinoButton(
        key: ValueKey<String>('delete-task-${task.id}'),
        padding: EdgeInsets.zero,
        onPressed: () => _showDeleteConfirmation(task),
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.systemRed,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    final TaskDraft? draft = await showCupertinoDialog<TaskDraft>(
      context: context,
      builder: (BuildContext context) {
        return TaskEditorDialog(controller: _controller);
      },
    );
    if (draft == null) {
      return;
    }

    try {
      await _controller.addTask(
        title: draft.title,
        description: draft.description,
        categoryId: draft.category,
        priority: draft.priority,
        dueDate: draft.dueDate,
        reminders: draft.reminders,
      );
    } on TaskValidationException catch (error) {
      if (mounted) {
        await _showValidationError(error.message);
      }
    }
  }

  Future<void> _showEditTaskDialog(Task task) async {
    final TaskDraft? draft = await showCupertinoDialog<TaskDraft>(
      context: context,
      builder: (BuildContext context) {
        return TaskEditorDialog(controller: _controller, task: task);
      },
    );
    if (draft == null) {
      return;
    }

    try {
      await _controller.updateTask(
        task.copyWith(
          title: draft.title,
          description: draft.description,
          categoryId: draft.category,
          clearCategoryId: draft.category.isEmpty,
          priority: draft.priority,
          dueDate: draft.dueDate,
          clearDueDate: draft.dueDate == null,
          reminders: draft.reminders,
        ),
      );
    } on TaskValidationException catch (error) {
      if (mounted) {
        await _showValidationError(error.message);
      }
    }
  }

  Future<void> _showValidationError(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Task not saved'),
          content: Text(message),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Task task) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Task?'),
          content: Text('"${task.title}" will be permanently removed.'),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_controller.deleteTask(task));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

String priorityLabel(TaskPriority priority) {
  return switch (priority) {
    TaskPriority.low => 'Low',
    TaskPriority.normal => 'Normal',
    TaskPriority.high => 'High',
  };
}
