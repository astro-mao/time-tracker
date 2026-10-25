import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import '../models/event.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import 'event_edit_page.dart';

/// 我的：事件管理（增删改）+ CSV 导出
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final db = DatabaseHelper();
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await db.getEvents();
    if (!mounted) return;
    setState(() => _events = e);
  }

  Future<void> _edit(Event? e) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventEditPage(event: e)));
    _load();
  }

  Future<void> _delete(Event e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除事件'),
        content: const Text('历史计时记录仍会保留，确定删除该事件？'),
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
    if (ok == true) {
      await db.archiveEvent(e.id!);
      _load();
      AppState().notify();
    }
  }

  /// 导出 CSV：本地生成文件，调用系统分享（可发微信/存文件）
  Future<void> _export() async {
    final records = await db.getDoneRecords();
    final buf = StringBuffer();
    buf.writeln('事件,开始时间,结束时间,时长(分钟),时长(秒),日期');
    for (final r in records) {
      final end = r.endTime ?? r.startTime;
      buf.writeln(
          '"${r.eventName}","${_dt(r.startTime)}","${_dt(end)}",'
          '${(r.duration / 60000).toStringAsFixed(1)},'
          '${(r.duration / 1000).round()},'
          '"${r.dateStr}"');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/时间记录.csv');
    await file.writeAsString('\uFEFF' + buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: '时间记录导出');
  }

  String _dt(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final p = (n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  Color _color(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('我的事件',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                        onPressed: () => _edit(null), child: const Text('+ 新建')),
                  ],
                ),
                ..._events.map((e) => ListTile(
                      leading: CircleAvatar(
                          backgroundColor: _color(e.color), radius: 8),
                      title: Text(e.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(e)),
                          IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _delete(e)),
                        ],
                      ),
                    )),
                if (_events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('还没有事件，点「新建」创建一个',
                        style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('数据导出',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('将全部记录导出为 CSV，可分享或保存',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.download),
                    label: const Text('导出 CSV'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
