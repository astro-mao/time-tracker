import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/event.dart';
import '../models/time_record.dart';
import '../utils/format.dart';
import '../utils/ui.dart';

/// 打开「补录」底部弹层。
///
/// 用于「忘了开计时器」的场景：手动指定「开始 + 结束」，直接生成一条已完成记录。
/// 返回 true 表示保存成功。
Future<bool?> showBackfillSheet(
  BuildContext context, {
  required List<Event> events,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BackfillSheet(events: events),
  );
}

class _BackfillSheet extends StatefulWidget {
  final List<Event> events;
  const _BackfillSheet({required this.events});

  @override
  State<_BackfillSheet> createState() => _BackfillSheetState();
}

class _BackfillSheetState extends State<_BackfillSheet> {
  final _db = DatabaseHelper();
  final _noteCtrl = TextEditingController();

  int _eventIdx = 0;
  late DateTime _start;
  late DateTime _end;
  String? _error;
  bool _saving = false;
  List<TimeRecord> _overlaps = []; // 与已有记录时间重叠的部分（只提醒，不拦截）

  @override
  void initState() {
    super.initState();
    // 默认：结束 = 现在（取到分钟），开始 = 一小时前。多数补录只改几处就能存。
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _start = _end.subtract(const Duration(hours: 1));
    _checkOverlap();
  }

  /// 每次改完时间都查一次重叠：有重叠只提示，不阻止保存（分段记录是合理的）
  Future<void> _checkOverlap() async {
    if (_duration <= 0) {
      if (mounted) setState(() => _overlaps = []);
      return;
    }
    final list = await _db.getOverlaps(
      _start.millisecondsSinceEpoch,
      _end.millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() => _overlaps = list);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Event? get _event => widget.events.isEmpty ? null : widget.events[_eventIdx];

  int get _duration => _end.difference(_start).inMilliseconds;

  bool get _crossDay => !_sameDay(_start, _end);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateText(DateTime d) => '${d.month} 月 ${d.day} 日';

  String _timeText(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final base = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(base.year, base.month, base.day),
      // 补录只能落在过去（含今天），不能记到未来
      firstDate: isStart
          ? DateTime(now.year - 5)
          : DateTime(_start.year, _start.month, _start.day),
      lastDate: today,
      helpText: isStart ? '开始日期' : '结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      if (isStart) {
        final keep = _end.difference(_start);
        _start = DateTime(
            picked.year, picked.month, picked.day, _start.hour, _start.minute);
        // 改了开始日期后若结束早于开始，保持原来的时长顺势后移
        if (!_end.isAfter(_start)) {
          var e = _start.add(
              keep.inMilliseconds > 0 ? keep : const Duration(hours: 1));
          if (e.isAfter(now)) e = now;
          _end = e;
        }
      } else {
        _end = DateTime(
            picked.year, picked.month, picked.day, _end.hour, _end.minute);
      }
    });
    _checkOverlap();
  }

  Future<void> _pickTime(bool isStart) async {
    final base = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      helpText: isStart ? '开始时间' : '结束时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      if (isStart) {
        _start = DateTime(
            _start.year, _start.month, _start.day, picked.hour, picked.minute);
        if (!_end.isAfter(_start)) {
          var e = _start.add(const Duration(minutes: 30));
          final now = DateTime.now();
          if (e.isAfter(now)) e = now;
          _end = e;
        }
      } else {
        var d = DateTime(
            _end.year, _end.month, _end.day, picked.hour, picked.minute);
        // 只是改了"时刻"、且落在开始之前 → 视为跨夜，自动顺延一天
        if (!d.isAfter(_start) && _sameDay(d, _start)) {
          d = d.add(const Duration(days: 1));
        }
        _end = d;
      }
    });
    _checkOverlap();
  }

  Future<void> _save() async {
    final e = _event;
    if (e == null || e.id == null) return;
    final now = DateTime.now();
    if (_duration <= 0) {
      setState(() => _error = '结束时间要晚于开始时间');
      return;
    }
    if (_end.isAfter(now.add(const Duration(minutes: 1)))) {
      setState(() => _error = '不能补录尚未发生的时间');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _noteCtrl.text.trim();
    await _db.insertRecord(TimeRecord(
      eventId: e.id!,
      eventName: e.name,
      eventColor: e.color,
      startTime: _start.millisecondsSinceEpoch,
      endTime: _end.millisecondsSinceEpoch,
      duration: _duration,
      dateStr: todayStr(_end),
      status: 1,
      note: note.isEmpty ? null : note,
      source: 1,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _tapField(String text, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ),
      ),
    );
  }

  Widget _timeRow(String label, DateTime d, bool isStart) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.sub)),
          ),
          Expanded(flex: 3, child: _tapField(_dateText(d), () => _pickDate(isStart))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _tapField(_timeText(d), () => _pickTime(isStart))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('补录一段时间',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('忘了开计时器也不怕，手动记一段',
                style: TextStyle(fontSize: 12, color: AppColors.faint)),
            const SizedBox(height: 16),
            if (widget.events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('还没有事件，先去「我的」创建一个',
                    style: TextStyle(fontSize: 13, color: AppColors.sub)),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < widget.events.length; i++)
                    pill(
                      widget.events[i].name,
                      active: i == _eventIdx,
                      dotColor: hexColor(widget.events[i].color),
                      onTap: () => setState(() {
                        _eventIdx = i;
                        _error = null;
                      }),
                    ),
                ],
              ),
              _timeRow('开始', _start, true),
              _timeRow('结束', _end, false),
              if (_crossDay)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 48),
                  child: Text('跨天：这条记录会算在结束那天',
                      style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
                ),
              if (_overlaps.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE2B8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.warn),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '与「${_overlaps.first.eventName}」'
                          '${formatClock(_overlaps.first.startTime)}-'
                          '${formatClock(_overlaps.first.endTime ?? _overlaps.first.startTime)}'
                          ' 时间重叠，仍可保存',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timelapse_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('时长',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.sub)),
                    const Spacer(),
                    Text(
                      _duration > 0 ? formatDuration(_duration) : '结束需晚于开始',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _duration > 0
                            ? AppColors.primary
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  maxLength: 100,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '备注（可选），例如「昨晚补记」',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: AppColors.faint),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.danger)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_saving ? '保存中…' : '保存',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
