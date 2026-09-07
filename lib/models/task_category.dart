import 'package:flutter/cupertino.dart';

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final int color;
  final String icon;

  static const icons = <String, IconData>{
    'folder': CupertinoIcons.folder,
    'person': CupertinoIcons.person,
    'work': CupertinoIcons.briefcase,
    'study': CupertinoIcons.book,
    'home': CupertinoIcons.house,
    'shopping': CupertinoIcons.cart,
    'heart': CupertinoIcons.heart,
    'star': CupertinoIcons.star,
  };
  static const colors = <int>[
    0xFF007AFF,
    0xFF34C759,
    0xFFFF9500,
    0xFFAF52DE,
    0xFFFF2D55,
    0xFF5856D6,
  ];
  IconData get iconData => icons[icon] ?? CupertinoIcons.folder;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'icon': icon,
  };
  factory TaskCategory.fromJson(Map<String, Object?> json) => TaskCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
    icon: json['icon'] as String,
  );
}
