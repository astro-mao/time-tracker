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
  final _noteCtrl = TextEditingController(); // 结束前可填写备注

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
    _noteCtrl.dispose();
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
        SnackBar(
          content: Text(
              '结束时间需晚于开始时间 ${formatDateTime(_startTime)}'),
        ),
      );
      return;
    }
    _ticker?.cancel();
    final duration = end - _startTime;
    final noteText = _noteCtrl.text.trim();
    final updated = TimeRecord(
      id: widget.running.id,
      eventId: widget.running.eventId,
      eventName: widget.running.eventName,
      eventColor: widget.running.eventColor,
      startTime: widget.running.startTime,
      endTime: end,
      duration: duration,
      // 日期归属跟随"实际结束时间"：跨天修正后，记录应落在结束那天，
      // 否则在记录页/统计页会挂到开始那天的账上。
      dateStr: todayStr(DateTime.fromMillisecondsSinceEpoch(end)),
      status: 1,
      note: noteText.isEmpty ? null : noteText,
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

  /// 修正时可选日期的说明。
  /// 日期选择器里比开始日更早、或今天之后的日期都会变灰，这是刻意的限制，
  /// 但必须写出来，否则用户会误以为"选不了其他日期"是功能坏了。
  String _correctionRangeHint() {
    final firstDay = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(_startTime));
    final lastDay = DateUtils.dateOnly(DateTime.now());
    if (firstDay == lastDay) {
      return '本次计时今天才开始，日期只能选今天；时间可改到 '
          '${formatClock(_startTime)} 之后';
    }
    String md(DateTime d) => '${d.month}月${d.day}日';
    return '可修正日期：${md(firstDay)} ~ ${md(lastDay)}'
        '（不能早于开始，也不能选未来）';
  }

  /// 结束并修正：选真实结束时间（日期 + 时间），用于处理"忘记结束"的场景。
  ///
  /// 可选范围 = 开始当天 ~ 今天：
  /// - 不能早于开始日（结束不可能早于开始）；
  /// - 不能晚于今天（不能记到未来）。
  /// 如果本次计时是今天才开始的，那么"其他日期"本来就不该可选，
  /// 因此把范围直接写在标题里，避免用户以为选择器坏了。
  Future<void> _finishWithCorrection() async {
    final now = DateTime.now();
    final startDt = DateTime.fromMillisecondsSinceEpoch(_startTime);
    // 只保留日期部分，避免带时分秒的边界值导致选择器判定异常
    final firstDay = DateUtils.dateOnly(startDt);
    final lastDay = DateUtils.dateOnly(now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: lastDay,
      firstDate: firstDay,
      lastDate: lastDay,
      helpText: '实际结束日期',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: '实际结束时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (pickedTime == null) return;
    final endDt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);
    if (endDt.millisecondsSinceEpoch <= _startTime) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '结束时间需晚于开始时间 ${formatDateTime(_startTime)}'),
        ),
      );
      return;
    }
    _commitEnd(endDt.millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const deepBlue = Color(0xFF1E3A8A);
    return Scaffold(
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [deepBlue, blue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 上半部分可滚动：键盘弹出时不会把内容顶到溢出
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        _elapsed,
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('正在计时 · 锁屏或退出都不影响记录',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 28),
                      // 备注栏：结束计时前顺手记一句
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        minLines: 1,
                        maxLength: 100,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: '添加备注（可选）…',
                          hintStyle: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                          counterStyle: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                          filled: true,
                          fillColor: Colors.white.withOpacity(.15),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 按钮固定在底部，始终可见
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: deepBlue,
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
                          side:
                              const BorderSide(color: Colors.white, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('结束并修正（选实际结束时间）'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 说明可选范围：否则用户会以为"其他日期点不动"是坏了
                    Text(
                      _correctionRangeHint(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
