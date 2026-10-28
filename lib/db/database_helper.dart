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

  // ---------------- 统计 ----------------
  /// 今日按事件聚合：[{name, color, value(毫秒)}]
  /// 传 eventId 时只统计该事件
  Future<List<Map<String, dynamic>>> getTodayByEvent({int? eventId}) async {
    final d = await db;
    final where = eventId == null
        ? 'status = 1 AND date_str = ?'
        : 'status = 1 AND date_str = ? AND event_id = ?';
    final args = eventId == null ? [todayStr()] : [todayStr(), eventId];
    return d.rawQuery('''
      SELECT event_name AS name, event_color AS color, SUM(duration) AS value
      FROM records
      WHERE $where
      GROUP BY event_name
    ''', args);
  }

  /// 近 7 天每日总时长（缺失日期补 0）
  /// 传 eventId 时只统计该事件
  Future<List<Map<String, dynamic>>> getWeekDaily({int? eventId}) async {
    final d = await db;
    final dates = <String>[];
    for (int i = 6; i >= 0; i--) {
      dates.add(todayStr(DateTime.now().subtract(Duration(days: i))));
    }
    final placeholders = List.filled(dates.length, '?').join(',');
    final where = eventId == null
        ? 'status = 1 AND date_str IN ($placeholders)'
        : 'status = 1 AND event_id = ? AND date_str IN ($placeholders)';
    final args = eventId == null ? dates : [eventId, ...dates];
    final rows = await d.rawQuery('''
      SELECT date_str AS date, SUM(duration) AS value
      FROM records
      WHERE $where
      GROUP BY date_str
    ''', args);

    final map = {
      for (var r in rows) r['date'] as String: (r['value'] as int?) ?? 0
    };
    return dates.map((dt) => {'date': dt, 'value': map[dt] ?? 0}).toList();
  }
}
