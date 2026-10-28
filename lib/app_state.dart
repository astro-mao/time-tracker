import 'models/time_record.dart';

/// 极简全局状态：持有「当前正在计时的记录」+ 一个通知机制。
///
/// 任何页面改动数据（开始/结束计时、增删改事件、改备注）后都必须调用
/// [notify]，订阅的页面就会重新从数据库拉取，保持各 Tab 数据一致。
///
/// 另外 [revision] 是一个自增版本号，页面可以把它当成"数据变了"的信号。
class AppState {
  AppState._();

  static final AppState _instance = AppState._();
  factory AppState() => _instance;

  TimeRecord? running;

  /// 每次 notify 自增，便于排查"到底有没有通知到"。
  int revision = 0;

  final List<void Function()> _listeners = [];

  void addListener(void Function() fn) {
    if (!_listeners.contains(fn)) _listeners.add(fn);
  }

  void removeListener(void Function() fn) => _listeners.remove(fn);

  /// 通知所有页面刷新。
  ///
  /// 关键点：单个页面在刷新时抛异常，不能连带把后面的页面也拖死
  /// （之前的写法没有任何保护，一个页面出错，其它页面就永远收不到刷新）。
  void notify() {
    revision++;
    for (final fn in List<void Function()>.of(_listeners)) {
      try {
        fn();
      } catch (_) {
        // 忽略单个订阅者的异常，保证其它页面照常刷新
      }
    }
  }
}
