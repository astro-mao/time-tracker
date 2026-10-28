import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import '../models/event.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/ui.dart';
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
    AppState().addListener(_onChange);
  }

  @override
  void dispose() {
    AppState().removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => _load();

  Future<void> _load() async {
    final e = await db.getEvents();
    if (!mounted) return;
    setState(() => _events = e);
  }

  Future<void> _edit(Event? e) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventEditPage(event: e)));
    await _load();
  }

  Future<void> _delete(Event e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('删除事件', style: TextStyle(fontSize: 18)),
        content: const Text('历史计时记录仍会保留，确定删除该事件？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消', style: TextStyle(color: AppColors.sub))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await db.archiveEvent(e.id!);
      AppState().notify();
      await _load();
    }
  }

  /// 导出 CSV：本地生成文件，调用系统分享（可发微信/存文件）
  Future<void> _export() async {
    final records = await db.getDoneRecords();
    final buf = StringBuffer();
    buf.writeln('事件,开始时间,结束时间,时长(分钟),时长(秒),日期,备注');
    for (final r in records) {
      final end = r.endTime ?? r.startTime;
      final note = (r.note ?? '').replaceAll('"', '""'); // CSV 双引号转义
      buf.writeln(
          '"${r.eventName}","${_dt(r.startTime)}","${_dt(end)}",'
          '${(r.duration / 60000).toStringAsFixed(1)},'
          '${(r.duration / 1000).round()},'
          '"${r.dateStr}","$note"');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
          _header(),
          const SizedBox(height: 18),
          sectionTitle('我的事件', trailing: '共 ${_events.length} 个'),
          Container(
            decoration: softCard(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < _events.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58,
                      color: Color(0xFFF1F4F9),
                    ),
                  _eventRow(_events[i]),
                ],
                _addButton(),
              ],
            ),
          ),
          const SizedBox(height: 18),
          sectionTitle('数据导出'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: softCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.ios_share_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('导出为 CSV',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                          SizedBox(height: 3),
                          Text('包含备注列，可用 Excel / Numbers 打开',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.faint)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('导出全部记录'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              '时间记录 · 数据仅保存在本机',
              style: TextStyle(fontSize: 11.5, color: AppColors.faint),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: gradientCard(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '时间记录',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '把时间花在哪里，一目了然',
                  style: TextStyle(
                      color: Colors.white.withOpacity(.85), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRow(Event e) {
    final c = hexColor(e.color);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  e.name.isEmpty ? '·' : e.name.substring(0, 1),
                  style: TextStyle(
                      color: c, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 19, color: AppColors.faint),
                onPressed: () => _edit(e),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 19, color: AppColors.faint),
                onPressed: () => _delete(e),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(null),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _events.isEmpty ? '创建第一个事件' : '新建事件',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
