import 'package:flutter/material.dart';
import '../models/event.dart';

/// 事件条目：颜色圆点 + 名称，整行可点击
class EventItem extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventItem({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: event.colorValue, radius: 9),
      title: Text(event.name),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
