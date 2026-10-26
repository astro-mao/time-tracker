import 'dart:async';
import 'package:flutter/material.dart';
import '../models/time_record.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/format.dart';

/// 独立的全屏计时页：点事件后跳转进来。
///
/// 关键：本页只负责"展示"。真正的计时锚点（startTime 时间戳）已经在
/// 点击事件的那一刻写进了本地库（status = 0 的 running 记录）。
/// 所以即使本页被销毁、App 被系统杀掉、手机锁屏，重新打开 App 时，
/// 依然能用「现在 - startTime」算出已经花了多少时间，完全不受影响。
///
/// 关于"忘记结束"：计时会一直累计到当下，不会丢，但统计会被虚高。
/// 因此提供「结束并修正」——让用户选真实结束时间，把 endTime 改回去。
class TimerRunningPage extends StatefulWidget {
  final TimeRecord running;
  const TimerRunningPage({super.key, required this.running});

  @override
  State<TimerRunningPage> createState() => _TimerRunningPageState();
}

class _TimerRunningPageState extends State<TimerRunningPage> {
  final db = DatabaseHelper();
  late final int _startTime;
  String _elapsed = '00:00:00';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTime = widget.running.startTime;
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _startTime;
    if (mounted) setState(() => _elapsed = _formatClock(elapsed));
  }

  String _formatClock(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final p = (n) => n.toString().padLeft(2, '0');
    return '${p(h)}:${p(m)}:${p(sec)}';
  }

  /// 把结束时间写回本地库（封口）。end 既可以是"现在"，也可以是用户修正的过去时刻。
  Future<void> _commitEnd(int end) async {
    if (end <= _startTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束时间需晚于开始时间')),
      );
      return;
    }
    _ticker?.cancel();
    final duration = end - _startTime;
    final updated = TimeRecord(
      id: widget.running.id,
      eventId: widget.running.eventId,
      eventName: widget.running.eventName,
      eventColor: widget.running.eventColor,
      startTime: widget.running.startTime,
      endTime: end,
      duration: duration,
      dateStr: widget.running.dateStr,
      status: 1,
    );
    await db.updateRecord(updated);
    AppState().running = null;
    AppState().notify();
    if (!mounted) return;
    // 先取 messenger 再 pop：pop 之后本页 context 已失效，不能再用它查祖先
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('已记录 ${formatDuration(duration)}')),
    );
  }

  /// 正常结束：以"现在"封口
  Future<void> _finish() async {
    _commitEnd(DateTime.now().millisecondsSinceEpoch);
  }

  /// 结束并修正：选真实结束时间（日期 + 时间），用于处理"忘记结束"的场景
  Future<void> _finishWithCorrection() async {
    final now = DateTime.now();
    final startDt = DateTime.fromMillisecondsSinceEpoch(_startTime);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: startDt,
      lastDate: now,
      helpText: '选择实际结束日期',
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: '选择实际结束时间',
    );
    if (pickedTime == null) return;
    final endDt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);
    _commitEnd(endDt.millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(
        'FF${widget.running.eventColor.replaceFirst('#', '')}', radix: 16));
    return Scaffold(
      backgroundColor: color,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.running.eventName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('收起', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(flex: 2),
          Center(
            child: Text(
              _elapsed,
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('正在计时 · 锁屏或退出都不影响记录',
                style: TextStyle(color: Colors.white70)),
          ),
          const Spacer(flex: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('结束计时'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _finishWithCorrection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('结束并修正（选实际结束时间）'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
