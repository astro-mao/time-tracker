import 'package:flutter/material.dart';

/// 当前计时大卡片：事件名 + 已用时长 + 结束按钮
class TimerCard extends StatelessWidget {
  final String eventName;
  final Color color;
  final String elapsedText;
  final VoidCallback onStop;

  const TimerCard({
    super.key,
    required this.eventName,
    required this.color,
    required this.elapsedText,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            const Text('正在计时', style: TextStyle(color: Colors.grey, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(eventName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 16),
            Text(elapsedText,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text('结束'),
            ),
          ],
        ),
      ),
    );
  }
}
