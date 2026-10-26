/// 时间格式化工具
String todayStr([DateTime? d]) {
  d ??= DateTime.now();
  return '${d.year}-${_p(d.month)}-${_p(d.day)}';
}

String _p(int n) => n < 10 ? '0$n' : '$n';

/// 毫秒 -> 人类可读时长，如 "1小时20分" / "8分30秒" / "45秒"
String formatDuration(int ms) {
  if (ms <= 0) return '0秒';
  final total = (ms / 1000).floor();
  final h = (total / 3600).floor();
  final m = ((total % 3600) / 60).floor();
  final s = total % 60;
  if (h > 0) return '${h}小时${m}分';
  if (m > 0) return '${m}分${s}秒';
  return '${s}秒';
}

/// 时间戳 -> 'HH:mm'
String formatClock(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${_p(d.hour)}:${_p(d.minute)}';
}

/// 时间戳 -> 'YYYY-MM-DD HH:mm'
String formatDateTime(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
}
