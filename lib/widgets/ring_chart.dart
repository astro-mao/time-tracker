import 'dart:math';
import 'package:flutter/material.dart';

/// 环形图的一瓣
class RingSlice {
  final Color color;
  final double value;
  RingSlice(this.color, this.value);
}

/// 自绘环形占比图（不依赖第三方图表库，包体更小）
class RingChart extends StatelessWidget {
  final List<RingSlice> data;
  final String centerTop;
  final String centerBottom;
  final double size;

  const RingChart({
    super.key,
    required this.data,
    this.centerTop = '',
    this.centerBottom = '',
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(data),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTop,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  )),
              const SizedBox(height: 2),
              Text(centerBottom,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<RingSlice> data;
  _RingPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (s, d) => s + d.value);
    if (total <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width / 2 - 4;
    final rInner = rOuter * 0.62;

    // 底层浅色轨道，让留白和有数据的部分看起来是一个完整的环
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rOuter - rInner
      ..color = const Color(0xFFEEF2F8);
    canvas.drawCircle(Offset(cx, cy), (rOuter + rInner) / 2, track);

    // 只有一个活动时，整圈都应是它的颜色。
    // 若用 arcTo 画 360°，起点与终点重合会让路径退化而不渲染（表现为空白），
    // 因此改用「描边圆环」直接画整圈。
    final positive = data.where((d) => d.value > 0).toList();
    if (positive.length == 1) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rOuter - rInner
        ..color = positive.first.color;
      canvas.drawCircle(Offset(cx, cy), (rOuter + rInner) / 2, ringPaint);
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;

    double start = -pi / 2;
    for (final d in data) {
      final angle = (d.value / total) * 2 * pi;
      final path = Path();
      path.moveTo(cx, cy);
      path.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: rOuter), start, angle, false);
      path.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: rInner), start + angle, -angle, false);
      path.close();
      paint.color = d.color;
      canvas.drawPath(path, paint);
      start += angle;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.data != data;
}
