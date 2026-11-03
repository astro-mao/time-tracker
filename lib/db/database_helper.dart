import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';
import '../models/time_record.dart';
import '../utils/format.dart';

/// 本地数据库（SQLite）。数据只存在手机上，无需服务器。
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper _instance = DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'time_tracker.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            color TEXT,
            sort INTEGER,
            archived INTEGER
          )
        ''');
        await database.execute('''
          CREATE TABLE records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER,
            event_name TEXT,
            event_color TEXT,
            start_time INTEGER,
            end_time INTEGER,
            duration INTEGER,
            date_str TEXT,
            status INTEGER,
            note TEXT,
            source INTEGER DEFAULT 0
          )
        ''');
      },
      // v1 -> v2：给记录增加「备注」列。用 ALTER TABLE 增量加列，老数据原样保留。
      // v2 -> v3：增加「来源」列（0 = 正常计时，1 = 手动补录）。
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('ALTER TABLE records ADD COLUMN note TEXT');
        }
        if (oldVersion < 3) {
          await database.execute(
              'ALTER TABLE records ADD COLUMN source INTEGER DEFAULT 0');
        }
      },
    );
  }

  // ---------------- 事件 ----------------
  Future<int> insertEvent(Event e) =>
      db.then((d) => d.insert('events', e.toMap()));

  Future<List<Event>> getEvents({bool includeArchived = false}) async {
    final d = await db;
    final rows = await d.query(
      'events',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort ASC',
    );
    return rows.map(Event.fromMap).toList();
  }

  Future<int> updateEvent(Event e) => db.then(
      (d) => d.update('events', e.toMap(), where: 'id = ?', whereArgs: [e.id]));

  Future<int> archiveEvent(int id) => db.then((d) =>
      d.update('events', {'archived': 1}, where: 'id = ?', whereArgs: [id]));

  // ---------------- 计时记录 ----------------
  Future<int> insertRecord(TimeRecord r) =>
      db.then((d) => d.insert('records', r.toMap()));

  Future<int> updateRecord(TimeRecord r) => db.then((d) =>
      d.update('records', r.toMap(), where: 'id = ?', whereArgs: [r.id]));

  /// 取当前正在计时的记录（status = 0），用于 App 启动恢复
  Future<TimeRecord?> getRunning() async {
    final d = await db;
    final rows = await d.query('records', where: 'status = 0', limit: 1);
    if (rows.isEmpty) return null;
    return TimeRecord.fromMap(rows.first);
  }

  Future<List<TimeRecord>> getDoneRecords() async {
    final d = await db;
    final rows =
        await d.query('records', where: 'status = 1', orderBy: 'end_time DESC');
    return rows.map(TimeRecord.fromMap).toList();
  }

  Future<int> deleteRecord(int id) =>
      db.then((d) => d.delete('records', where: 'id = ?', whereArgs: [id]));

  /// 查与 [start, end) 时间重叠的已完成记录（补录前的"重叠"提醒用）
  Future<List<TimeRecord>> getOverlaps(int start, int end) async {
    final d = await db;
    final rows = await d.query(
      'records',
      where: 'status = 1 AND start_time < ? AND end_time > ?',
      whereArgs: [end, start],
      orderBy: 'start_time ASC',
    );
    return rows.map(TimeRecord.fromMap).toList();
  }

  /// 只更新备注，避免整行覆盖（记录页补充描述时用）
  Future<int> updateNote(int id, String note) => db.then((d) => d.update(
        'records',
        {'note': note.trim().isEmpty ? null : note.trim()},
        where: 'id = ?',
        whereArgs: [id],
      ));

  /// 批量导入记录（用于「导入 CSV 恢复数据」）。
  /// 会按记录里的 event_name 自动复用已有事件，没有则新建（颜色优先用记录自带、否则按色板轮换）。
  /// 返回实际导入的条数。
  Future<int> importRecords(List<TimeRecord> records) async {
    if (records.isEmpty) return 0;
    final d = await db;

    // 现有事件（含已归档），按名称建立索引
    final existing = await d.query('events');
    final byName = <String, Map<String, dynamic>>{};
    var nextSort = 0;
    for (final e in existing) {
      byName[e['name'] as String] = e;
      final s = e['sort'] as int? ?? 0;
      if (s > nextSort) nextSort = s;
    }
    nextSort += 1;

    const palette = [
      '#2563EB', '#10B981', '#F59E0B', '#EF4444',
      '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16',
    ];

    var count = 0;
    await d.transaction((txn) async {
      for (final r in records) {
        var ev = byName[r.eventName];
        if (ev == null) {
          final color = r.eventColor.isNotEmpty
              ? r.eventColor
              : palette[nextSort % palette.length];
          final id = await txn.insert('events', {
            'name': r.eventName,
            'color': color,
            'sort': nextSort,
            'archived': 0,
          });
          ev = {'id': id, 'name': r.eventName, 'color': color};
          byName[r.eventName] = ev;
          nextSort++;
        }
        final map = r.toMap()..remove('id');
        map['event_id'] = ev['id'];
        map['event_name'] = ev['name'];
        map['event_color'] = ev['color'];
        await txn.insert('records', map);
        count++;
      }
    });
    return count;
  }

  // ---------------- 统计 ----------------
  // 统计一律按 start_time/end_time 与"自然日"的重叠来计算，
  // 不再依赖单一 date_str。这样跨天（如 10-01 23:30 ~ 10-02 00:30）的记录
  // 会按每天实际占用的时长分别计入对应日期，而不是整段算到某一天。

  /// 计算 [start, end) 与自然日 [dayStart, dayEnd) 的重叠毫秒数
  static int _overlapMs(int start, int end, int dayStart, int dayEnd) {
    final lo = start > dayStart ? start : dayStart;
    final hi = end < dayEnd ? end : dayEnd;
    return hi > lo ? hi - lo : 0;
  }

  static const int _dayMs = 24 * 60 * 60 * 1000;

  /// 今日按事件聚合：[{name, color, value(毫秒)}]，只统计落在今天的那部分时长。
  /// 传 eventId 时只统计该事件
  Future<List<Map<String, dynamic>>> getTodayByEvent({int? eventId}) async {
    final d = await db;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final dayEnd = dayStart + _dayMs;

    final where = eventId == null
        ? 'status = 1 AND start_time < ? AND end_time > ?'
        : 'status = 1 AND event_id = ? AND start_time < ? AND end_time > ?';
    final args =
        eventId == null ? [dayEnd, dayStart] : [eventId, dayEnd, dayStart];
    final rows = await d.query('records', where: where, whereArgs: args);

    final agg = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final r = TimeRecord.fromMap(row);
      final end = r.endTime ?? r.startTime;
      final v = _overlapMs(r.startTime, end, dayStart, dayEnd);
      if (v <= 0) continue;
      final cur = agg[r.eventName];
      if (cur != null) {
        cur['value'] = (cur['value'] as int) + v;
      } else {
        agg[r.eventName] = {'name': r.eventName, 'color': r.eventColor, 'value': v};
      }
    }
    return agg.values.toList();
  }

  /// 近 7 天每日总时长（缺失日期补 0），跨天记录按每天实际时长切分。
  /// 传 eventId 时只统计该事件
  Future<List<Map<String, dynamic>>> getWeekDaily({int? eventId}) async {
    final d = await db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final winStart = todayStart - 6 * _dayMs;
    final winEnd = todayStart + _dayMs;

    final where = eventId == null
        ? 'status = 1 AND start_time < ? AND end_time > ?'
        : 'status = 1 AND event_id = ? AND start_time < ? AND end_time > ?';
    final args = eventId == null
        ? [winEnd, winStart]
        : [eventId, winEnd, winStart];
    final rows = await d.query('records', where: where, whereArgs: args);

    final values = <String, int>{};
    final dates = <String>[];
    for (int i = 6; i >= 0; i--) {
      final dt = todayStr(now.subtract(Duration(days: i)));
      dates.add(dt);
      values[dt] = 0;
    }

    for (final row in rows) {
      final r = TimeRecord.fromMap(row);
      final end = r.endTime ?? r.startTime;
      var cursor = r.startTime;
      while (cursor < end) {
        final cd = DateTime.fromMillisecondsSinceEpoch(cursor);
        final key = todayStr(cd);
        final dayEnd =
            DateTime(cd.year, cd.month, cd.day + 1).millisecondsSinceEpoch;
        final segEnd = end < dayEnd ? end : dayEnd;
        if (values.containsKey(key)) {
          values[key] = values[key]! + (segEnd - cursor);
        }
        cursor = segEnd;
      }
    }

    return dates.map((dt) => {'date': dt, 'value': values[dt] ?? 0}).toList();
  }
}
