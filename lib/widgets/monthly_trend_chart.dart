import 'package:flutter/material.dart';
import '../utils/ui.dart';

/// 月度总量趋势：近 12 个月每月总时长柱状图，当月高亮，柱顶显示增减。
/// 数据由统计页按自然月聚合 getDailyByEvent 得到（口径统一）。
class MonthlyTrendChart extends StatelessWidget {
  /// [{label:'11月', value(毫秒), year, month}]
  final List<Map<String, dynamic>> months;

  const MonthlyTrendChart({super.key, required this.months});

  @override
  Widget build(BuildContext context) {
    final max = months.fold<int>(0, (s, m) {
      final v = (m['value'] as int?) ?? 0;
      return v > s ? v : s;
    });
    final total = months.fold<int>(0, (s, m) => s + ((m['value'] as int?) ?? 0));

    if (total <= 0) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text('还没有月度数据',
              style: TextStyle(fontSize: 13, color: AppColors.faint)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 148,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: months.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final v = (m['value'] as int?) ?? 0;
              final ratio = max > 0 ? (v / max).clamp(0.0, 1.0) : 0.0;
              final isLast = i == months.length - 1;
              final prev = i > 0 ? ((months[i - 1]['value'] as int?) ?? 0) : 0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 柱顶时长（小时）
                      Text(
                        v > 0 ? '${(v / 3600000).round()}' : '',
                        style: TextStyle(
                          fontSize: 9,
                          color: isLast ? AppColors.primary : AppColors.faint,
                          fontWeight:
                              isLast ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 96 * ratio + 3,
                        decoration: BoxDecoration(
                          color: isLast
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(.22),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['label'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isLast ? AppColors.primary : AppColors.faint,
                          fontWeight:
                              isLast ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 环比箭头：比上月多↑ 少↓（仅在两个月都有数据时显示）
                      if (i > 0 && v > 0 && prev > 0)
                        Text(
                          v > prev ? '↑' : (v < prev ? '↓' : '–'),
                          style: TextStyle(
                            fontSize: 9,
                            color: v >= prev ? AppColors.success : AppColors.warn,
                          ),
                        )
                      else
                        const SizedBox(height: 11),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('柱顶数字单位：小时',
                style: TextStyle(fontSize: 10.5, color: AppColors.faint)),
            Text('12 个月合计 ${(total / 3600000).round()} 小时',
                style: const TextStyle(fontSize: 10.5, color: AppColors.faint)),
          ],
        ),
      ],
    );
  }
}
