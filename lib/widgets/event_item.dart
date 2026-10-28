import 'package:flutter/material.dart';
import '../models/event.dart';
import '../utils/ui.dart';

/// 事件条目：彩色圆角图标 + 名称 + 「开始」小标签，整行可点击
class EventItem extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventItem({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = hexColor(event.color);
    final initial = event.name.isEmpty ? '·' : event.name.substring(0, 1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: c,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '点击开始计时',
                      style: TextStyle(fontSize: 12, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 16, color: c),
                    const SizedBox(width: 2),
                    Text(
                      '开始',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
