@echo off
REM 本机已安装 Flutter + Android SDK 时，一键打包安卓 APK（Windows）
REM 用法：在 time_tracker_app 目录下双击本文件，或命令行执行  build_apk.bat

echo == 生成安卓工程脚手架（首次需要，已存在会自动跳过）
flutter create --platforms=android . || echo scaffold 已存在，跳过

echo == 拉取依赖
call flutter pub get

echo == 编译 APK（debug，免签名，可直接装手机测试）
call flutter build apk --debug

echo ----------------------------------------
echo 完成！APK 在：
echo build\app\outputs\flutter-apk\app-debug.apk
echo ----------------------------------------
pause
