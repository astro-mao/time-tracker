import 'package:flutter/material.dart';
import '../utils/ui.dart';

/// 作息规律图：横轴 0~24 点（每 2 小时一格），纵轴周一到周日。
/// 格子颜色深浅 = 近 N 周里该时段累计记录时长（由数据库按日逐段切分后聚合）。
class RoutineHeatmap extends StatelessWidget {
  /// [{weekday:1..7, slot:0..11, value(毫秒)}]
  final List<Map<String, dynamic>> cells;
  final int weeks;

  const RoutineHeatmap({
    super.key,
    required this.cells,
    this.weeks = 12,
  });

  static const _weekNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _slotLabels = ['0', '', '4', '', '8', '', '12', '', '16', '', '20', ''];

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    var max = 0;
    for (final c in cells) {
      final key = '${c['weekday']}_${c['slot']}';
      final v = (c['value'] as int?) ?? 0;
      map[key] = v;
      if (v > max) max = v;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 时段刻度
        Row(
          children: [
            const SizedBox(width: 30),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _slotLabels
                    .map((s) => SizedBox(
                          width: 18,
                          child: Text(
                            s,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 9.5, color: AppColors.faint),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 7 行 × 12 列
        ...List.generate(7, (row) {
          final weekday = row + 1;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    _weekNames[row],
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.sub),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: List.generate(12, (slot) {
                      final v = map['${weekday}_$slot'] ?? 0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Tooltip(
                            message: v > 0
                                ? '${_weekNames[row]} ${slot * 2}:00-${slot * 2 + 2}:00 · $_fmt(v)'
                                : '${_weekNames[row]} ${slot * 2}:00-${slot * 2 + 2}:00 · 无记录',
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: _cellColor(v, max),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('少',
                style: TextStyle(fontSize: 10, color: AppColors.faint)),
            const SizedBox(width: 4),
            ...[
              0.0, 0.2, 0.4, 0.6, 0.8, 1.0
            ].map((r) => Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: _ratioColor(r),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
            const SizedBox(width: 2),
            const Text('多',
                style: TextStyle(fontSize: 10, color: AppColors.faint)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '近 $weeks 周各时段累计（点格子可看详情）',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: AppColors.faint),
        ),
      ],
    );
  }

  Color _cellColor(int v, int max) {
    if (v <= 0 || max <= 0) return const Color(0xFFF1F5F9);
    return _ratioColor((v / max).clamp(0.08, 1.0));
  }

  Color _ratioColor(double r) {
    // 由浅到深的蓝：0 浅底 → 1 主色
    if (r <= 0.2) return const Color(0xFFDBEAFE);
    if (r <= 0.4) return const Color(0xFFBFDBFE);
    if (r <= 0.6) return const Color(0xFF93C5FD);
    if (r <= 0.8) return const Color(0xFF60A5FA);
    return AppColors.primary;
  }

  String _fmt(int ms) {
    final h = ms / 3600000;
    return h >= 1 ? '${h.toStringAsFixed(1)} 小时' : '${(ms / 60000).round()} 分钟';
  }
}
