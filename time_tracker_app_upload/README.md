# 时间记录 App（安卓端 · Flutter）

用 **Flutter** 写的安卓 App：点击事件开始计时，再点「结束」完成记录，支持看板统计与 CSV 导出。**数据只存在你手机本地**（SQLite），无需服务器、无需联网、无需后端。

> 和之前的微信小程序版不同：这是一个可以装到你安卓手机上的真·App（生成 APK 安装包即可分发）。

## 功能对应

| 页面 | 功能 |
|------|------|
| 计时 | 列出事件，点一下开始，点「结束」完成一次计时；App 重启也能恢复未结束的计时 |
| 记录 | 按天分组查看历史，可删除 |
| 统计 | 今日各事件占比（环形图）+ 近 7 天趋势（柱状图） |
| 我的 | 事件增/改/删 + 一键导出 CSV |

## 目录结构

```
time_tracker_app/
├── pubspec.yaml              # 依赖（Flutter / sqflite / share_plus）
└── lib/
    ├── main.dart            # 入口 + 底部 4 Tab 导航
    ├── app_state.dart       # 极简全局状态（当前计时 + 刷新通知）
    ├── models/              # event.dart / time_record.dart 数据模型
    ├── db/database_helper.dart  # 本地 SQLite 增删改查 + 统计聚合
    ├── utils/format.dart    # 时长/日期格式化
    ├── widgets/             # event_item / timer_card / ring_chart(自绘环形图)
    └── pages/               # timer / records / statistics / profile / event_edit
```

## 环境准备（一次性）

1. 安装 **Flutter SDK**：https://docs.flutter.dev/get-started/install （选你系统对应的版本）
2. 安装 **Android Studio**（含 Android SDK + 模拟器）：https://developer.android.com/studio
3. 命令行执行 `flutter doctor`，按提示把勾都打上（尤其 Android toolchain）

## 运行到手机 / 模拟器

```bash
cd time_tracker_app
flutter pub get        # 拉取依赖
flutter run           # 连上手机或开模拟器后运行
```

- **真机调试**：手机打开「开发者选项 → USB 调试」，用数据线连电脑，选到该设备后 `flutter run`。
- **生成安装包（APK）**：`flutter build apk`，产物在 `build/app/outputs/flutter-apk/app-release.apk`，传到手机安装即可。

## 数据说明

- 所有数据存在手机本地数据库 `time_tracker.db`（SQLite），卸载 App 会一起清除。
- 想以后换手机不丢数据，可后续接入云同步（如 Firebase / 自建后端），当前版本未包含。

## 常见问题

- `flutter pub get` 卡住/报错：检查网络，或把 `pubspec.yaml` 里依赖版本号改成最新稳定版。
- 真机跑不起来：确认「USB 调试」已开，且 `flutter devices` 能看到你的手机。
- 图表/分享异常：确认 `share_plus`、`sqflite`、`cross_file` 三个依赖已成功安装。

> 想加功能（云同步、周报提醒、桌面小组件等）随时说。
