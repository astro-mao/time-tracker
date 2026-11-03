import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/event.dart';
import '../models/time_record.dart';
import '../db/database_helper.dart';
import '../app_state.dart';
import '../utils/ui.dart';
import '../utils/format.dart';
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
    buf.writeln('事件,颜色,开始时间,结束时间,时长(分钟),时长(秒),日期,备注');
    for (final r in records) {
      final end = r.endTime ?? r.startTime;
      final note = (r.note ?? '').replaceAll('"', '""'); // CSV 双引号转义
      buf.writeln(
          '"${r.eventName}","${r.eventColor}","${_dt(r.startTime)}","${_dt(end)}",'
          '${(r.duration / 60000).toStringAsFixed(1)},'
          '${(r.duration / 1000).round()},'
          '"${todayStr(DateTime.fromMillisecondsSinceEpoch(r.startTime))}","$note"');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/时间记录.csv');
    await file.writeAsString('\uFEFF' + buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: '时间记录导出');
  }

  /// 导入 CSV：从之前导出的文件恢复数据（升级/换机保留数据用）。
  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      String content;
      if (f.bytes != null) {
        content = utf8.decode(f.bytes!, allowMalformed: true);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        _toast('无法读取该文件');
        return;
      }
      if (content.startsWith('\uFEFF')) content = content.substring(1);
      final records = _parseImport(content);
      if (records.isEmpty) {
        _toast('没找到可导入的记录，请确认选的是导出的 CSV 文件');
        return;
      }
      final n = await db.importRecords(records);
      AppState().notify();
      if (!mounted) return;
      _toast('成功导入 $n 条记录');
      await _load();
    } catch (e) {
      _toast('导入失败：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  /// 解析 CSV 内容为 TimeRecord 列表。
  /// 兼容两种格式：旧版（7 列，无颜色）、新版（8 列，含颜色）。按表头定位列，位置不敏感。
  List<TimeRecord> _parseImport(String content) {
    final rows = _parseCsv(content);
    if (rows.isEmpty) return [];
    final header = rows.first.map((c) => c.trim()).toList();
    final idxName = header.indexOf('事件');
    final idxColor = header.indexOf('颜色');
    final idxStart = header.indexOf('开始时间');
    final idxEnd = header.indexOf('结束时间');
    final idxMin = header.indexOf('时长(分钟)');
    final idxSec = header.indexOf('时长(秒)');
    final idxNote = header.indexOf('备注');
    if (idxName < 0 || idxStart < 0 || idxEnd < 0) return [];

    final out = <TimeRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final c = rows[i];
      if (c.length <= idxName) continue;
      final name = c[idxName].trim();
      if (name.isEmpty) continue;
      final start = _parseDt(c.length > idxStart ? c[idxStart] : '');
      final end = _parseDt(c.length > idxEnd ? c[idxEnd] : '');
      if (start == null || end == null) continue;

      int dur;
      if (idxSec >= 0 && c.length > idxSec) {
        final s = int.tryParse(c[idxSec].trim());
        dur = s != null ? s * 1000 : end.difference(start).inMilliseconds;
      } else if (idxMin >= 0 && c.length > idxMin) {
        final m = double.tryParse(c[idxMin].trim());
        dur = m != null ? (m * 60000).round() : end.difference(start).inMilliseconds;
      } else {
        dur = end.difference(start).inMilliseconds;
      }
      if (dur < 0) dur = 0;

      final color = (idxColor >= 0 && c.length > idxColor) ? c[idxColor].trim() : '';
      final note = (idxNote >= 0 && c.length > idxNote) ? c[idxNote].trim() : '';

      out.add(TimeRecord(
        eventId: 0, // 占位，importRecords 里会重建事件映射
        eventName: name,
        eventColor: color,
        startTime: start.millisecondsSinceEpoch,
        endTime: end.millisecondsSinceEpoch,
        duration: dur,
        dateStr: todayStr(start),
        status: 1,
        note: note.isEmpty ? null : note,
        source: 0,
      ));
    }
    return out;
  }

  DateTime? _parseDt(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    try {
      // 兼容 "2026-10-01 23:30" 与 "2026-10-01T23:30:00"
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  /// 简单但健壮的 CSV 解析：支持引号包裹、字段内逗号/换行、"" 转义为 "。
  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    final row = <String>[];
    final buf = StringBuffer();
    var inQ = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQ) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQ = false;
          }
        } else {
          buf.write(ch);
        }
      } else {
        if (ch == '"') {
          inQ = true;
        } else if (ch == ',') {
          row.add(buf.toString());
          buf.clear();
        } else if (ch == '\n') {
          row.add(buf.toString());
          buf.clear();
          rows.add(List<String>.from(row));
          row.clear();
        } else if (ch != '\r') {
          buf.write(ch);
        }
      }
    }
    if (buf.isNotEmpty || row.isNotEmpty) {
      row.add(buf.toString());
      rows.add(row);
    }
    return rows;
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
          sectionTitle('数据备份'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: softCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '升级或换机前先点「导出」，装好新版后点「导入」，历史记录就不会丢。',
                  style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('导出 CSV'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('导入 CSV'),
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
