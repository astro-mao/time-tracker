import 'package:flutter/material.dart';
import '../models/time_record.dart';
import '../models/event.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/format.dart';

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
    _load();
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

  Color _color(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final dates = _groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final activeEvent = _filterEventId == null ? null : _findEvent(_filterEventId!);

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: Column(
        children: [
          // -------- 筛选条 --------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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

          // -------- 列表 --------
          Expanded(
            child: _all.isEmpty
                ? Center(
                    child: Text(
                      _filterEventId == null
                          ? '还没有记录，去「计时」开始吧'
                          : '「${activeEvent?.name ?? ''}」下暂无记录',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            activeEvent == null
                                ? '累计已记录 ${formatDuration(_total)}'
                                : '「${activeEvent.name}」累计 ${formatDuration(_total)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...dates
                          .map((d) => _dayGroup(d, _groups[d]!))
                          .toList(),
                    ],
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

  Widget _dayGroup(String date, List<TimeRecord> items) {
    final dayTotal = items.fold(0, (s, r) => s + r.duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(formatDuration(dayTotal),
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Card(
          child: Column(
            children: items.map((r) => _recRow(r)).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _recRow(TimeRecord r) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: _color(r.eventColor), radius: 8),
      title: Text(r.eventName),
      subtitle: Text(
          '${formatClock(r.startTime)} - ${r.endTime != null ? formatClock(r.endTime!) : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatDuration(r.duration),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
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
    );
  }
}
