#!/usr/bin/env bash
# 本机已安装 Flutter + Android SDK 时，一键打包安卓 APK（macOS / Linux）
# 用法：在 time_tracker_app 目录下执行  ./build_apk.sh
set -e

echo "==> 生成安卓工程脚手架（首次需要，已存在会自动跳过）"
flutter create --platforms=android . || true

echo "==> 拉取依赖"
flutter pub get

echo "==> 编译 APK（debug，免签名，可直接装手机测试）"
flutter build apk --debug

echo "----------------------------------------"
echo "完成！APK 在："
echo "build/app/outputs/flutter-apk/app-debug.apk"
echo "----------------------------------------"
