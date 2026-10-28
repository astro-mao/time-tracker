import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/time_record.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/format.dart';
import '../utils/ui.dart';
import '../widgets/event_item.dart';
import '../widgets/backfill_sheet.dart';
import 'timer_running_page.dart';

/// 计时主页：列出事件，点一下开始；有进行中的计时会在顶部横幅提示
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
  int _todayTotal = 0;
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
    final today = await db.getTodayByEvent();

    int total = 0;
    for (final m in today) {
      total += (m['value'] as int?) ?? 0;
    }
    if (running != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (running.dateStr == todayStr()) {
        total += now - running.startTime;
      } else {
        // 跨天：只把"今天 0 点到现在"算进今日
        final n = DateTime.now();
        final dayStart =
            DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
        if (now > dayStart) total += now - dayStart;
      }
    }

    if (!mounted) return;
    setState(() {
      _events = events;
      _running = running;
      _todayTotal = total;
    });
    if (running != null) {
      AppState().running = running;
      _elapsed =
          formatDuration(DateTime.now().millisecondsSinceEpoch - running.startTime);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先结束当前计时')));
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
    if (!mounted) return;
    setState(() {
      _running = withId;
    });
    AppState().running = withId;
    AppState().notify();
    _startTicker();
    // 点事件后直接进入独立全屏计时页
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerRunningPage(running: withId),
      ),
    );
    // 从计时页返回后再拉一次，确保横幅/今日时长是最新的
    if (mounted) _load();
  }

  /// 补录：忘了开计时器时，手动记一段（不启动计时器）
  Future<void> _openBackfill() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先去「我的」创建一个事件，再来补录')),
      );
      return;
    }
    final ok = await showBackfillSheet(context, events: _events);
    if (ok != true || !mounted) return;
    AppState().notify(); // 通知记录页/统计页一起刷新
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已补录，可在「记录」里查看')),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  String _dateLine() {
    const week = ['一', '二', '三', '四', '五', '六', '日'];
    final n = DateTime.now();
    return '${n.month} 月 ${n.day} 日 · 周${week[n.weekday - 1]}';
  }

  /// 顶部概览卡片
  Widget _overview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: gradientCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()}，今天',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.82),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateLine(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apps_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_events.length} 个事件',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '今日已记录',
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatDuration(_todayTotal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _running != null
                    ? Icons.radio_button_checked
                    : Icons.touch_app_outlined,
                color: Colors.white.withOpacity(.85),
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _running != null
                      ? '正在计时：${_running!.eventName} · $_elapsed'
                      : '点击下面的事件，开始记录时间',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.85),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 进行中横幅：点一下进入独立全屏计时页
  Widget _runningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TimerRunningPage(running: _running!),
              ),
            );
            if (mounted) _load();
          },
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.timer, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _running!.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '点此查看 / 结束',
                      style: TextStyle(fontSize: 12, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _elapsed,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '进行中',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 已运行超过 2 小时：给出"可能忘了结束"的提示，引导去修正。
  Widget _lateWarning() {
    if (_running == null) return const SizedBox.shrink();
    final ms = DateTime.now().millisecondsSinceEpoch - _running!.startTime;
    if (ms <= 2 * 3600 * 1000) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE2B8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.alarm_on_rounded,
              color: AppColors.warn, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本次计时已运行 $_elapsed，若你早已结束，点上方横幅 →「结束并修正」',
              style: const TextStyle(
                  color: Color(0xFFB45309), fontSize: 12.5, height: 1.45),
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
          _overview(),
          if (_running != null) ...[
            const SizedBox(height: 14),
            _runningBanner(),
            _lateWarning(),
          ],
          const SizedBox(height: 22),
          sectionTitle(
            '我的事件',
            action: TextButton.icon(
              onPressed: _openBackfill,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('补录'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Container(
            decoration: softCard(),
            clipBehavior: Clip.antiAlias,
            child: _events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 40, color: AppColors.faint),
                        SizedBox(height: 10),
                        Text('还没有事件',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.sub)),
                        SizedBox(height: 4),
                        Text('去「我的」里创建一个，就能开始计时了',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.faint)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < _events.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            color: Color(0xFFF1F4F9),
                          ),
                        EventItem(
                            event: _events[i], onTap: () => _start(_events[i])),
                      ],
                    ],
                  ),
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '提示：计时开始后即使锁屏或退出 App，时间也会继续计算。',
                style: TextStyle(fontSize: 11.5, color: AppColors.faint),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
