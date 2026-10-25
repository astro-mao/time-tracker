import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/time_record.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/format.dart';
import '../widgets/event_item.dart';
import 'timer_running_page.dart';

/// 计时主页：列出事件，点一下开始；再点「结束」完成一次记录
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final db = DatabaseHelper();
  List<Event> _events = [];
  TimeRecord? _running;
  String _elapsed = '0秒';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    AppState().addListener(_onChange);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    AppState().removeListener(_onChange);
    super.dispose();
  }

  /// 订阅全局状态变化（其他页面增删/结束计时后刷新本页）
  void _onChange() => _load();

  Future<void> _load() async {
    final events = await db.getEvents();
    final running = await db.getRunning();
    if (!mounted) return;
    setState(() {
      _events = events;
      _running = running;
    });
    if (running != null) {
      AppState().running = running;
      _elapsed = formatDuration(
          DateTime.now().millisecondsSinceEpoch - running.startTime);
      _startTicker();
    } else {
      _elapsed = '0秒';
    }
  }

  /// 每秒刷新一次显示时长（只更新一个字符串，开销极小）
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running == null) return;
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - _running!.startTime;
      if (mounted) setState(() => _elapsed = formatDuration(elapsed));
    });
  }

  Future<void> _start(Event e) async {
    if (_running != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先结束当前计时')));
      return;
    }
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final rec = TimeRecord(
      eventId: e.id!,
      eventName: e.name,
      eventColor: e.color,
      startTime: startTime,
      dateStr: todayStr(),
      status: 0,
    );
    final id = await db.insertRecord(rec);
    final withId = TimeRecord(
      id: id,
      eventId: e.id!,
      eventName: e.name,
      eventColor: e.color,
      startTime: startTime,
      dateStr: todayStr(),
      status: 0,
    );
    setState(() {
      _running = withId;
    });
    AppState().running = withId;
    AppState().notify();
    _startTicker();
    // 点事件后直接进入独立全屏计时页
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimerRunningPage(running: withId),
        ),
      );
    }
  }

  Future<void> _stop() async {
    if (_running == null) return;
    _ticker?.cancel();
    final end = DateTime.now().millisecondsSinceEpoch;
    final duration = end - _running!.startTime;
    final updated = TimeRecord(
      id: _running!.id,
      eventId: _running!.eventId,
      eventName: _running!.eventName,
      eventColor: _running!.eventColor,
      startTime: _running!.startTime,
      endTime: end,
      duration: duration,
      dateStr: _running!.dateStr,
      status: 1,
    );
    await db.updateRecord(updated);
    setState(() {
      _running = null;
      _elapsed = '0秒';
    });
    AppState().running = null;
    AppState().notify();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已记录 ${formatDuration(duration)}')));
    }
  }

  /// 主页顶部横幅：有进行中计时时显示，点一下进入独立全屏计时页
  Widget _runningBanner() {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      color: color,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TimerRunningPage(running: _running!),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('正在计时：${_running!.eventName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const Text('点此查看 / 结束',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Text(_elapsed,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Color _color(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  /// 当一条计时已运行超过 2 小时，给出"可能忘了结束"的提示，引导去修正。
  Widget _lateWarning() {
    if (_running == null) return const SizedBox.shrink();
    final ms = DateTime.now().millisecondsSinceEpoch - _running!.startTime;
    if (ms <= 2 * 3600 * 1000) return const SizedBox.shrink();
    final color = Colors.orange.shade700;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本次计时已运行 $_elapsed，若你早已结束，点上方横幅 →「结束并修正」',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('计时')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_running != null) ...[
            _runningBanner(),
            _lateWarning(),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Text('点击下面的事件开始计时',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('记录你把时间用在了哪里',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('我的事件', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Card(
            child: _events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('还没有事件，去「我的」里创建',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  )
                : Column(
                    children: _events
                        .map((e) => EventItem(event: e, onTap: () => _start(e)))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
