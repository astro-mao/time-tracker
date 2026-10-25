/// 一条计时记录
class TimeRecord {
  int? id;
  int eventId;
  String eventName; // 冗余存名称，统计免联表
  String eventColor; // 冗余存颜色
  int startTime; // 开始时间（epoch 毫秒）
  int? endTime; // 结束时间（计时中时为 null）
  int duration; // 时长（毫秒），结束才填
  String dateStr; // 'YYYY-MM-DD'，便于按日聚合
  int status; // 0 = 计时中(running)，1 = 已完成(done)

  TimeRecord({
    this.id,
    required this.eventId,
    required this.eventName,
    required this.eventColor,
    required this.startTime,
    this.endTime,
    this.duration = 0,
    required this.dateStr,
    this.status = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'event_id': eventId,
        'event_name': eventName,
        'event_color': eventColor,
        'start_time': startTime,
        'end_time': endTime,
        'duration': duration,
        'date_str': dateStr,
        'status': status,
      };

  factory TimeRecord.fromMap(Map<String, dynamic> m) => TimeRecord(
        id: m['id'],
        eventId: m['event_id'],
        eventName: m['event_name'],
        eventColor: m['event_color'],
        startTime: m['start_time'],
        endTime: m['end_time'],
        duration: m['duration'] ?? 0,
        dateStr: m['date_str'],
        status: m['status'] ?? 0,
      );
}
