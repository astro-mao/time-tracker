import 'package:flutter/material.dart';
import '../models/time_record.dart';
import '../models/event.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/format.dart';
import '../utils/ui.dart';

/// 记录明细：按日分组展示，可删除；支持按事件筛选
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final db = DatabaseHelper();
  List<TimeRecord> _all = [];
  List<Event> _events = [];
  Map<String, List<TimeRecord>> _groups = {};
  int _total = 0;
  int? _filterEventId; // null = 全部

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
    final all = await db.getDoneRecords();
    final filtered = _filterEventId == null
        ? all
        : all.where((r) => r.eventId == _filterEventId).toList();

    final groups = <String, List<TimeRecord>>{};
    int total = 0;
    for (final r in filtered) {
      groups.putIfAbsent(r.dateStr, () => []).add(r);
      total += r.duration;
    }
    if (!mounted) return;
    setState(() {
      _events = events;
      _all = filtered;
      _groups = groups;
      _total = total;
    });
  }

  Future<void> _delete(TimeRecord r) async {
    await db.deleteRecord(r.id!);
    AppState().notify();
    await _load();
  }

  void _setFilter(int? eventId) {
    setState(() => _filterEventId = eventId);
    _load();
  }

  Event? _findEvent(int id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 补充/修改备注。返回 null = 取消；返回字符串（可为空）= 保存。
  Future<void> _editNote(TimeRecord r) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NoteEditDialog(initial: r.note ?? ''),
    );
    if (result == null) return;
    await db.updateNote(r.id!, result);
    AppState().notify();
    await _load();
  }

  String _weekday(String date) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    try {
      final d = DateTime.parse(date);
      return names[d.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final activeEvent =
        _filterEventId == null ? null : _findEvent(_filterEventId!);

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
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

          // -------- 列表 --------
          Expanded(
            child: _all.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_rounded,
                            size: 46, color: AppColors.faint.withOpacity(.7)),
                        const SizedBox(height: 12),
                        Text(
                          _filterEventId == null
                              ? '还没有记录，去「计时」开始吧'
                              : '「${activeEvent?.name ?? ''}」下暂无记录',
                          style: const TextStyle(
                              color: AppColors.faint, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      children: [
                        _summaryCard(activeEvent),
                        const SizedBox(height: 18),
                        ...dates
                            .map((d) => _dayGroup(d, _groups[d]!))
                            .toList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Event? activeEvent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: gradientCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activeEvent == null ? '累计已记录' : '「${activeEvent.name}」累计',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.82),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatDuration(_total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 13, color: Colors.white.withOpacity(.8)),
              const SizedBox(width: 5),
              Text(
                '共 ${_all.length} 条记录',
                style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayGroup(String date, List<TimeRecord> items) {
    final dayTotal = items.fold(0, (s, r) => s + r.duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _weekday(date),
                style: const TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              const Spacer(),
              Text(
                formatDuration(dayTotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: softCard(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 40,
                    color: Color(0xFFF1F4F9),
                  ),
                _recRow(items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _recRow(TimeRecord r) {
    final note = (r.note ?? '').trim();
    final c = hexColor(r.eventColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _editNote(r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        Text(
                          formatDuration(r.duration),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppColors.faint),
                        const SizedBox(width: 4),
                        Text(
                          '${formatClock(r.startTime)} - ${r.endTime != null ? formatClock(r.endTime!) : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.sub),
                        ),
                        // 手动补录的记录加个小标签，和真实计时区分开
                        if (r.source == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '补录',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FC),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.sub, height: 1.4),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      const Text(
                        '＋ 点此添加备注',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.faint),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.faint),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('删除记录'),
                      content: const Text('确定删除这条计时记录？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除')),
                      ],
                    ),
                  );
                  if (ok == true) await _delete(r);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 备注编辑弹窗。自己持有 controller 并在 dispose 里释放，
/// 避免在 showDialog 返回后立刻 dispose 导致关闭动画期间报 "used after dispose"。
class _NoteEditDialog extends StatefulWidget {
  final String initial;
  const _NoteEditDialog({required this.initial});

  @override
  State<_NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<_NoteEditDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('备注', style: TextStyle(fontSize: 18)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        maxLength: 100,
        decoration: const InputDecoration(
          hintText: '补充说明这条记录…',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // null = 取消
          child: const Text('取消', style: TextStyle(color: AppColors.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
