# 把「时间记录 App」打包成安卓安装包（APK）

> 目标：让你在不懂代码的前提下，拿到一个能装到自己安卓手机上、用来测试功能的 APK 文件。

## 先说清楚一件事（很重要）

这台帮你写代码的机器是 **ARM64 架构的 Linux，且没有安装 Android 编译工具链**。安卓打包链路里有个叫 `aapt2` 的工具，Google 在 Linux 上**只提供 x86-64 版本**，在 ARM64 上跑不起来——所以**没法在这台机器上直接给你打出 APK**。

但没关系，给你两条**一定能成**的路：

- **路线 A（推荐·零安装）**：用 GitHub 免费云构建，你电脑上什么都不用装，几分钟后网页上下载 APK。
- **路线 B（本地装 Flutter）**：在你自己的 Windows / Mac 上装好 Flutter，一条命令出包。

下面分别讲。

---

## 路线 A：GitHub 云构建（推荐，电脑零安装）

适合：不想在电脑上装一堆开发工具的人。全程在浏览器里点。

### 第 1 步：注册 GitHub 账号
打开 https://github.com ，用邮箱注册一个免费账号。

### 第 2 步：新建一个仓库
1. 点右上角 `+` → `New repository`。
2. 仓库名随便起，比如 `time-tracker-app`。
3. 选 **Public**（私有也行，但公开最省事）。
4. 别勾 "Add a README"（我们要自己传）。
5. 点 `Create repository`。

### 第 3 步：把工程上传到仓库
最简单的方式（不用装 Git）：
1. 进到刚建的仓库，点 `Add file` → `Upload files`。
2. 把本地 `time_tracker_app` 文件夹里的**所有内容**（包括隐藏的 `.github` 文件夹！）拖进去。
   - ⚠️ 一定要把 `.github` 文件夹一起传上去，里面的 `build-apk.yml` 就是打包脚本。如果看不到 `.github`，说明它是隐藏文件夹，请用压缩包方式上传，或见下方「隐藏文件夹怎么传」。
3. 拉到最下面，写个提交说明（随便写），点 `Commit changes`。

> 隐藏文件夹怎么传：把你本地的 `time_tracker_app` 整个文件夹压缩成 zip，在 GitHub 的 `Upload files` 里传这个 zip 也可以（GitHub 不会自动解压，所以更稳妥的做法是用 GitHub Desktop 或命令行 `git push`，新手建议用下面的替代法：先传普通文件，再单独把 `.github/workflows/build-apk.yml` 这个文件也通过 `Add file → Create new file` 新建出来，把内容贴进去即可）。

### 第 4 步：一键打包
1. 进仓库顶部的 `Actions` 标签。
2. 左侧应能看到 `Build Android APK` 这个工作流；点它。
3. 右侧点 `Run workflow` → 再点绿色的 `Run workflow`。
4. 页面会开始转圈，显示黄色「进行中」。一般 **3~8 分钟** 完成（首次会慢一点，要下载 Flutter 和安卓 SDK）。

### 第 5 步：下载 APK
1. 等状态变绿色 ✓（点进去能看到日志）。
2. 页面下方 `Artifacts` 区域会出现 `time-tracker-apk`，点它下载（是个 zip）。
3. 解压得到 `app-debug.apk`。

### 第 6 步：装到手机测试
1. 把 `app-debug.apk` 传到安卓手机（微信文件传输 / 数据线 / 网盘都行）。
2. 手机上打开它，会提示「允许安装未知应用」——点允许（这是安卓对「非应用商店安装」的正常提醒，不是病毒）。
3. 安装完成后打开，就能测试了：建事件 → 点事件开始计时 → 锁屏/杀后台 → 再打开看计时还在 → 结束并修正。

---

## 路线 B：本机装 Flutter 本地打包（Windows / Mac）

适合：以后打算长期开发、改功能的人。

### 第 1 步：装 Flutter（含安卓环境）
1. 打开 https://flutter.dev/docs/get-started/install ，按你的系统（Windows / macOS）下载 Flutter SDK。
2. 按官方教程解压、把 `flutter/bin` 加进系统环境变量 `PATH`。
3. 安装 **Android Studio**（官网免费），打开后装 **Android SDK** 和 **Android SDK Command-line Tools**。
4. 命令行执行 `flutter doctor`，按它提示把缺的东西补完（尤其 `cmdline-tools` 和同意安卓许可 `flutter doctor --android-licenses`）。

### 第 2 步：打包
1. 命令行进入 `time_tracker_app` 目录。
2. 执行我们准备好的脚本：
   - **Windows**：双击 `build_apk.bat`
   - **macOS / Linux**：执行 `./build_apk.sh`（若提示没权限，先 `chmod +x build_apk.sh`）
3. 脚本会自动：补全安卓工程 → 拉依赖 → 编译。
4. 生成的文件在：
   - `build/app/outputs/flutter-apk/app-debug.apk`
5. 把这个 apk 传到手机安装即可（同路线 A 第 6 步）。

> 如果你更想手敲命令，等效步骤是：
> ```
> flutter create --platforms=android .
> flutter pub get
> flutter build apk --debug
> ```

---

## 常见问题

**Q：debug 版和正式版有区别吗？**
A：功能完全一样。区别只是 debug 版带调试信息、没做代码混淆，包稍大、启动略慢。测试功能完全够用。等你以后要正式发布到应用商店，再加签名证书打 release 版即可，我可以帮你弄。

**Q：手机提示「存在风险 / 未知应用」要紧吗？**
A：不要紧，这是安卓对非应用商店安装的正常提示。debug 包没上架商店，所以一定会弹这个。确认来源是你自己打的就是安全的。

**Q：为什么仓库里没有 `android/` 文件夹？**
A：因为我们的工程只提交了 `lib/`（Dart 代码）和 `pubspec.yaml`。安卓原生工程（`android/`）由打包流程里的 `flutter create --platforms=android .` 这一步**自动生成**，所以你不用管它，也别手动建。

**Q：换手机 / 卸载 App，数据会丢吗？**
A：会。目前数据只存在你这部手机的本地数据库里（没有云端）。杀后台、锁屏、关机都不丢；但**换手机、卸载重装会丢**。等你想「换手机也不丢」时，我再帮你加云端同步。

---

## 文件清单（本工程已为你准备好）
- `.github/workflows/build-apk.yml` — 云构建脚本（路线 A 用）
- `build_apk.sh` / `build_apk.bat` — 本地一键打包脚本（路线 B 用）
- `lib/` — App 全部源码
- `pubspec.yaml` — 依赖配置
