import 'models/time_record.dart';

/// 极简全局状态：持有「当前正在计时的记录」+ 一个通知机制。
/// 任何页面改动数据（开始/结束计时、增删事件）后调用 notify()，
/// 订阅的页面就会重新拉取，保持各 Tab 数据一致。
class AppState {
  AppState._();

  static final AppState _instance = AppState._();
  factory AppState() => _instance;

  TimeRecord? running;

  final List<void Function()> _listeners = [];

  void addListener(void Function() fn) => _listeners.add(fn);

  void removeListener(void Function() fn) => _listeners.remove(fn);

  void notify() {
    for (final fn in List.of(_listeners)) {
      fn();
    }
  }
}
