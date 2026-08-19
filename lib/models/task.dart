class Task {
  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    this.isCompleted = false,
    this.dueDate
});

  final String id;
  String title;
  String description;
  String category;
  bool isCompleted;
  DateTime? dueDate;
}