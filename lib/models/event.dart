import 'package:flutter/material.dart';

/// 事件（你要记录的时间类别，如「写代码」「开会」）
class Event {
  int? id;
  String name;
  String color; // 十六进制颜色，如 '#07C160'
  int sort;
  bool archived;

  Event({
    this.id,
    required this.name,
    required this.color,
    this.sort = 0,
    this.archived = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'sort': sort,
        'archived': archived ? 1 : 0,
      };

  factory Event.fromMap(Map<String, dynamic> m) => Event(
        id: m['id'],
        name: m['name'],
        color: m['color'],
        sort: m['sort'] ?? 0,
        archived: (m['archived'] ?? 0) == 1,
      );

  Color get colorValue =>
      Color(int.parse('FF${color.replaceFirst('#', '')}', radix: 16));
}
