import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../models/time_record.dart';
import '../models/event.dart';
import '../utils/format.dart';
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

  static const _primary = Color(0xFF2563EB);

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

  Color _color(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final total = _today.fold(0, (s, m) => s + (m['value'] as int));
    final slices = _today
        .map((m) => RingSlice(_color(m['color']), (m['value'] as int).toDouble()))
        .toList();
    final maxWeek = _week.fold(0, (s, m) {
      final v = m['value'] as int;
      return v > s ? v : s;
    });
    final activeEvent =
        _filterEventId == null ? null : _findEvent(_filterEventId!);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------- 筛选条 --------
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('全部', isActive: _filterEventId == null,
                      onTap: () => _setFilter(null)),
                  const SizedBox(width: 8),
                  ..._events.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _chip(
                          e.name,
                          color: _color(e.color),
                          isActive: _filterEventId == e.id,
                          onTap: () => _setFilter(e.id),
                        ),
                      )),
                ],
              ),
            ),
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                      activeEvent == null
                          ? '今日时间分布'
                          : '「${activeEvent.name}」今日',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  slices.isEmpty
                      ? const Text('今天还没有记录',
                          style: TextStyle(color: Colors.grey))
                      : RingChart(
                          data: slices,
                          centerTop: formatDuration(total),
                          centerBottom: activeEvent == null ? '今日总计' : '今日',
                        ),
                  if (slices.isNotEmpty) const SizedBox(height: 12),
                  ..._today.map(_legend).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      activeEvent == null
                          ? '近 7 天趋势'
                          : '「${activeEvent.name}」近 7 天',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ..._week.map((m) => _bar(m, maxWeek)).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label,
      {required bool isActive, required VoidCallback onTap, Color? color}) {
    final dot = color != null
        ? Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            if (dot != null) dot,
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Map<String, dynamic> m) {
    final pct = total > 0
        ? ((m['value'] as int) / total * 100).round()
        : 0;
    return ListTile(
      leading: CircleAvatar(backgroundColor: _color(m['color']), radius: 8),
      title: Text(m['name']),
      trailing: Text('${formatDuration(m['value'])} · $pct%',
          style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _bar(Map<String, dynamic> m, int maxWeek) {
    final v = m['value'] as int;
    final pct = maxWeek > 0 ? (v / maxWeek * 100).round() : 0;
    final label = (m['date'] as String).substring(5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 48,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF07C160),
              minHeight: 14,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(formatDuration(v),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
