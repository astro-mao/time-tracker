import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../models/time_record.dart';
import '../models/event.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/ring_chart.dart';

/// 数据看板：今日环形占比图 + 近 7 天柱状趋势，支持按事件筛选
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final db = DatabaseHelper();
  List<Event> _events = [];
  List<Map<String, dynamic>> _today = [];
  List<Map<String, dynamic>> _week = [];
  int? _filterEventId; // null = 全部

  static const _primary = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _load();
    AppState().addListener(_onChange);
  }

  @override
  void dispose() {
    AppState().removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => _load();

  Future<void> _load() async {
    final events = await db.getEvents();
    final running = await db.getRunning();
    final today = await db.getTodayByEvent(eventId: _filterEventId);
    final week = await db.getWeekDaily(eventId: _filterEventId);
    _mergeRunning(today, week, running); // 把"进行中"的已用时间也算进统计
    if (!mounted) return;
    setState(() {
      _events = events;
      _today = today;
      _week = week;
    });
  }

  /// 把"进行中"的计时（status=0）按已用时间合并进统计。
  /// 这样即使还没点"结束"，你回来也能在统计里看到已经花了多少时间。
  /// 处于筛选状态时，只合并该事件的进行中时长。
  void _mergeRunning(List<Map<String, dynamic>> today,
      List<Map<String, dynamic>> week, TimeRecord? running) {
    if (running == null) return;
    if (_filterEventId != null && running.eventId != _filterEventId) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - running.startTime;
    if (elapsed <= 0) return;
    final startDay = running.dateStr;
    final todayS = todayStr();

    // 归属开始日：加进近 7 天（若开始日在范围内）
    _addToWeek(week, startDay, elapsed);
    // 若开始日就是今天，整段都算今天
    if (startDay == todayS) {
      _addToToday(today, running, elapsed);
    } else {
      // 跨天补偿：开始日 < 今天且仍在跑 → 今天 0 点至今的部分计入今日
      final part = now - _startOfTodayMs();
      if (part > 0) _addToToday(today, running, part);
    }
  }

  void _addToToday(List<Map<String, dynamic>> today, TimeRecord r, int v) {
    final i = today.indexWhere((m) => m['name'] == r.eventName);
    if (i >= 0) {
      today[i] = {...today[i], 'value': (today[i]['value'] as int) + v};
    } else {
      today.add({'name': r.eventName, 'color': r.eventColor, 'value': v});
    }
  }

  void _addToWeek(List<Map<String, dynamic>> week, String date, int v) {
    final i = week.indexWhere((m) => m['date'] == date);
    if (i >= 0) {
      week[i] = {...week[i], 'value': (week[i]['value'] as int) + v};
    }
  }

  int _startOfTodayMs() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  Event? _findEvent(int id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _setFilter(int? eventId) {
    setState(() => _filterEventId = eventId);
    _load();
  }

  Color _color(String hex) => hexColor(hex);

  @override
  Widget build(BuildContext context) {
    final total = _today.fold(0, (s, m) => s + ((m['value'] as int?) ?? 0));
    final slices = _today
        .map((m) => RingSlice(_color(m['color']), (m['value'] as int).toDouble()))
        .toList();
    final maxWeek = _week.fold(0, (s, m) {
      final v = m['value'] as int;
      return v > s ? v : s;
    });
    final weekTotal = _week.fold(0, (s, m) => s + (m['value'] as int));
    final activeEvent =
        _filterEventId == null ? null : _findEvent(_filterEventId!);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: Column(
        children: [
          // -------- 筛选条 --------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  pill('全部',
                      active: _filterEventId == null,
                      onTap: () => _setFilter(null)),
                  const SizedBox(width: 8),
                  ..._events.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: pill(
                          e.name,
                          dotColor: hexColor(e.color),
                          active: _filterEventId == e.id,
                          onTap: () => _setFilter(e.id),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  _summaryCard(total, activeEvent, slices.length),
                  const SizedBox(height: 16),
                  _ringCard(total, slices, activeEvent),
                  const SizedBox(height: 16),
                  _weekCard(maxWeek, weekTotal, activeEvent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(int total, Event? activeEvent, int kinds) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: gradientCard(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeEvent == null ? '今日总计' : '「${activeEvent.name}」今日',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatDuration(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$kinds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '个事件',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringCard(int total, List<RingSlice> slices, Event? activeEvent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: softCard(),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                activeEvent == null ? '今日时间分布' : '「${activeEvent.name}」占比',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.donut_large_rounded,
                      size: 40, color: AppColors.faint.withOpacity(.5)),
                  const SizedBox(height: 10),
                  const Text('今天还没有记录',
                      style:
                          TextStyle(color: AppColors.faint, fontSize: 13)),
                ],
              ),
            )
          else ...[
            RingChart(
              data: slices,
              size: 196,
              centerTop: formatDuration(total),
              centerBottom: activeEvent == null ? '今日总计' : '今日',
            ),
            const SizedBox(height: 10),
            ..._today.map((m) => _legend(m, total)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _legend(Map<String, dynamic> m, int total) {
    final value = (m['value'] as int?) ?? 0;
    final pct = total > 0 ? (value / total * 100).round() : 0;
    final c = _color(m['color']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.text),
                ),
              ),
              Text(
                formatDuration(value),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: const Color(0xFFEEF2F8),
              color: c,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(int maxWeek, int weekTotal, Event? activeEvent) {
    final todayS = todayStr();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                activeEvent == null ? '近 7 天趋势' : '「${activeEvent.name}」近 7 天',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '合计 ${formatDuration(weekTotal)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.faint),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _week.map((m) {
                final v = m['value'] as int;
                final ratio = maxWeek > 0 ? (v / maxWeek).clamp(0.0, 1.0) : 0.0;
                final date = m['date'] as String;
                final isToday = date == todayS;
                final label = date.substring(5);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          v > 0 ? '${(v / 60000).round()}' : '',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isToday ? _primary : AppColors.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 96 * ratio + 4,
                          width: 26,
                          decoration: BoxDecoration(
                            color: isToday
                                ? _primary
                                : _primary.withOpacity(.20),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isToday ? _primary : AppColors.faint,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '柱上数字单位：分钟',
            style: TextStyle(fontSize: 10.5, color: AppColors.faint),
          ),
        ],
      ),
    );
  }
}
