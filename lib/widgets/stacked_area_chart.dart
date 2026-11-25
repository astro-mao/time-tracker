import 'package:flutter/material.dart';
import '../utils/ui.dart';

/// 30 天此消彼长图：按天堆叠各事件时长，看结构变化。
/// 数据来自 getDailyByEvent（已按自然日切分，口径与今日/近7天一致）。
class StackedAreaChart extends StatelessWidget {
  /// [{date:'YYYY-MM-DD', name, color, value(毫秒)}]
  final List<Map<String, dynamic>> daily;

  const StackedAreaChart({super.key, required this.daily});

  @override
  Widget build(BuildContext context) {
    // 按总量取前 5 个事件，其余归为"其他"，避免图例过长
    final totals = <String, int>{};
    final colorOf = <String, Color>{};
    for (final m in daily) {
      final name = m['name'] as String;
      totals[name] = (totals[name] ?? 0) + (m['value'] as int);
      colorOf.putIfAbsent(name, () => hexColor(m['color'] as String));
    }
    final names = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final layers = names.take(5).toList();
    if (names.length > 5) layers.add('其他');

    final byDate = <String, int>{};
    final valueMap = <String, Map<String, int>>{};
    for (final m in daily) {
      final date = m['date'] as String;
      var name = m['name'] as String;
      final v = m['value'] as int;
      if (!layers.contains(name)) name = '其他';
      byDate[date] = (byDate[date] ?? 0) + v;
      valueMap.putIfAbsent(date, () => {});
      valueMap[date]![name] = (valueMap[date]![name] ?? 0) + v;
    }

    final dates = byDate.keys.toList()..sort();
    if (dates.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('近 30 天还没有记录',
              style: TextStyle(fontSize: 13, color: AppColors.faint)),
        ),
      );
    }

    final maxTotal = byDate.values.fold(0, (s, v) => v > s ? v : s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 132,
          child: CustomPaint(
            painter: _AreaPainter(dates, layers, valueMap, colorOf, maxTotal),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: layers.map((n) {
            final c = n == '其他'
                ? const Color(0xFFB4B2A9)
                : (colorOf[n] ?? AppColors.primary);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 5),
                Text(n,
                    style: const TextStyle(fontSize: 11, color: AppColors.sub)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dates.first.substring(5),
                style: const TextStyle(fontSize: 10, color: AppColors.faint)),
            Text(dates.last.substring(5),
                style: const TextStyle(fontSize: 10, color: AppColors.faint)),
          ],
        ),
      ],
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<String> dates;
  final List<String> layers;
  final Map<String, Map<String, int>> valueMap;
  final Map<String, Color> colorOf;
  final int maxTotal;

  _AreaPainter(this.dates, this.layers, this.valueMap, this.colorOf, this.maxTotal);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - 8;
    final w = size.width;
    final n = dates.length;
    if (n < 2 || maxTotal <= 0) return;

    // 每个日期的累计基线（从底往上堆叠）
    final baseline = List<double>.filled(n, 0);
    for (var li = 0; li < layers.length; li++) {
      final name = layers[li];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = name == '其他'
            ? const Color(0xFFB4B2A9).withOpacity(.75)
            : (colorOf[name] ?? AppColors.primary).withOpacity(.82);

      final upper = <Offset>[];
      final lower = <Offset>[];
      for (var i = 0; i < n; i++) {
        final v = valueMap[dates[i]]?[name] ?? 0;
        final x = n == 1 ? w / 2 : (i / (n - 1)) * w;
        final add = (v / maxTotal) * h;
        lower.add(Offset(x, h - baseline[i]));
        upper.add(Offset(x, h - baseline[i] - add));
        baseline[i] += add;
      }

      final path = Path();
      path.moveTo(lower.first.dx, lower.first.dy);
      for (var i = 1; i < lower.length; i++) path.lineTo(lower[i].dx, lower[i].dy);
      for (var i = upper.length - 1; i >= 0; i--) path.lineTo(upper[i].dx, upper[i].dy);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.dates != dates || old.layers != layers || old.maxTotal != maxTotal;
}
