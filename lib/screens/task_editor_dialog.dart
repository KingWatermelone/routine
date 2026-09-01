import 'package:flutter/cupertino.dart';

import '../models/task.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.dueDate,
    required this.reminders,
  });

  final String title;
  final String description;
  final String category;
  final TaskPriority priority;
  final DateTime? dueDate;
  final List<DateTime> reminders;
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({required this.categories, this.task, super.key});

  final List<String> categories;
  final Task? task;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _category;
  late TaskPriority _priority;
  late DateTime? _dueDate;
  late List<DateTime> _reminders;
  String? _validationMessage;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final Task? task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _category = widget.categories.contains(task?.category)
        ? task!.category
        : widget.categories.first;
    _priority = task?.priority ?? TaskPriority.normal;
    _dueDate = task?.dueDate;
    _reminders = List<DateTime>.of(task?.reminders ?? const <DateTime>[])
      ..sort();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'New Task'),
      content: SizedBox(
        height: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              CupertinoTextField(
                key: const ValueKey<String>('task-title-field'),
                controller: _titleController,
                autofocus: true,
                placeholder: 'What needs to be done?',
                textInputAction: TextInputAction.next,
                cursorWidth: 1,
                cursorRadius: Radius.zero,
                cursorOpacityAnimates: false,
                cursorColor: CupertinoColors.systemBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                style: const TextStyle(fontSize: 16, height: 1.25),
                onChanged: (_) => _clearValidationMessage(),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                key: const ValueKey<String>('task-description-field'),
                controller: _descriptionController,
                placeholder: 'Description (optional)',
                maxLines: 3,
                cursorWidth: 1,
                cursorRadius: Radius.zero,
                cursorOpacityAnimates: false,
                cursorColor: CupertinoColors.systemBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                style: const TextStyle(fontSize: 16, height: 1.25),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Category'),
              const SizedBox(height: 8),
              _buildCategoryMenu(),
              const SizedBox(height: 16),
              _fieldLabel('Priority'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<TaskPriority>(
                  groupValue: _priority,
                  children: const <TaskPriority, Widget>{
                    TaskPriority.low: Text('Low'),
                    TaskPriority.normal: Text('Normal'),
                    TaskPriority.high: Text('High'),
                  },
                  onValueChanged: (TaskPriority? priority) {
                    if (priority == null) {
                      return;
                    }
                    setState(() => _priority = priority);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildDateRow(
                label: 'Due date',
                value: _dueDate,
                onPressed: _selectDueDate,
                onClear: _dueDate == null
                    ? null
                    : () {
                        setState(() {
                          _dueDate = null;
                          _reminders.clear();
                          _validationMessage = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _fieldLabel('Reminders'),
                  CupertinoButton(
                    key: const ValueKey<String>('add-reminder-button'),
                    padding: EdgeInsets.zero,
                    onPressed: _addReminder,
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_reminders.isEmpty)
                const Text(
                  'No reminders',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 13,
                  ),
                )
              else
                ..._reminders.map(_buildReminderRow),
              if (_validationMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _validationMessage!,
                  key: const ValueKey<String>('task-validation-message'),
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          key: const ValueKey<String>('save-task-button'),
          isDefaultAction: true,
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: CupertinoColors.secondaryLabel,
        fontSize: 13,
      ),
    );
  }

  Widget _buildCategoryMenu() {
    return CupertinoMenuAnchor(
      menuChildren: widget.categories.map((String category) {
        return CupertinoMenuItem(
          leading: Icon(
            category == _category
                ? CupertinoIcons.check_mark
                : CupertinoIcons.circle,
            size: 16,
            color: categoryColor(category),
          ),
          onPressed: () => setState(() => _category = category),
          child: Text(category),
        );
      }).toList(),
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                key: const ValueKey<String>('category-menu-button'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: CupertinoColors.tertiarySystemFill,
                onPressed: controller.isOpen
                    ? controller.close
                    : controller.open,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: categoryColor(_category),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_category),
                      ],
                    ),
                    const Icon(CupertinoIcons.chevron_down, size: 15),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
    required VoidCallback? onClear,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: CupertinoButton(
            key: const ValueKey<String>('due-date-button'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: CupertinoColors.tertiarySystemFill,
            onPressed: onPressed,
            child: Row(
              children: <Widget>[
                const Icon(CupertinoIcons.calendar, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null ? 'Add $label' : formatDateTime(value),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onClear != null)
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            onPressed: onClear,
            child: const Icon(
              CupertinoIcons.clear_circled,
              color: CupertinoColors.systemRed,
              size: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildReminderRow(DateTime reminder) {
    return Row(
      children: <Widget>[
        const Icon(
          CupertinoIcons.bell,
          size: 16,
          color: CupertinoColors.secondaryLabel,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(formatDateTime(reminder))),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _reminders.remove(reminder)),
          child: const Icon(
            CupertinoIcons.minus_circle,
            color: CupertinoColors.systemRed,
            size: 18,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDueDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _dueDate ?? now.add(const Duration(days: 1));
    final DateTime? selectedDate = await showDateTimePicker(
      context,
      initialDate: initialDate,
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _dueDate = selectedDate;
      _reminders.removeWhere(
        (DateTime reminder) => reminder.isAfter(selectedDate),
      );
      _validationMessage = null;
    });
  }

  Future<void> _addReminder() async {
    final DateTime? dueDate = _dueDate;
    final DateTime now = DateTime.now();
    if (dueDate == null) {
      setState(() {
        _validationMessage = 'Set a due date before adding a reminder.';
      });
      return;
    }
    if (!dueDate.isAfter(now)) {
      setState(() {
        _validationMessage =
            'The due date must be in the future for a reminder.';
      });
      return;
    }

    DateTime initialDate = dueDate.subtract(const Duration(hours: 1));
    if (!initialDate.isAfter(now)) {
      initialDate = now.add(const Duration(minutes: 5));
    }
    if (initialDate.isAfter(dueDate)) {
      initialDate = dueDate;
    }

    final DateTime? reminder = await showDateTimePicker(
      context,
      initialDate: initialDate,
      minimumDate: now,
      maximumDate: dueDate,
    );
    if (reminder == null || !mounted) {
      return;
    }

    setState(() {
      if (!_reminders.contains(reminder)) {
        _reminders.add(reminder);
        _reminders.sort();
      }
      _validationMessage = null;
    });
  }

  void _clearValidationMessage() {
    if (_validationMessage == null) {
      return;
    }
    setState(() => _validationMessage = null);
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationMessage = 'Enter a title for the task.');
      return;
    }
    final DateTime? dueDate = _dueDate;
    if (dueDate != null &&
        _reminders.any((DateTime reminder) => reminder.isAfter(dueDate))) {
      setState(() {
        _validationMessage = 'A reminder cannot be later than the due date.';
      });
      return;
    }

    Navigator.of(context).pop(
      TaskDraft(
        title: title,
        description: _descriptionController.text.trim(),
        category: _category,
        priority: _priority,
        dueDate: _dueDate,
        reminders: List<DateTime>.unmodifiable(_reminders),
      ),
    );
  }
}

Future<DateTime?> showDateTimePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) {
  DateTime selectedDate = initialDate;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (BuildContext popupContext) {
      return Container(
        height: 330,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  CupertinoButton(
                    onPressed: () => Navigator.of(popupContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () =>
                        Navigator.of(popupContext).pop(selectedDate),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initialDate,
                  minimumDate: minimumDate,
                  maximumDate: maximumDate,
                  use24hFormat: true,
                  onDateTimeChanged: (DateTime date) => selectedDate = date,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String formatDateTime(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

Color categoryColor(String category) {
  return switch (category) {
    'Work' => CupertinoColors.systemBlue,
    'Study' => CupertinoColors.systemPurple,
    'Home' => CupertinoColors.systemOrange,
    'Shopping' => CupertinoColors.systemGreen,
    'Personal' => CupertinoColors.systemPink,
    _ => CupertinoColors.systemTeal,
  };
}
