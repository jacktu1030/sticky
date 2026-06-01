# 雨然日历 Flutter/Android 版

本目录是雨然日历的 Flutter 实现，当前重点支持 Android。它移植自根目录 `sticky_note.py` 的 Python tkinter 桌面版，并补充 Android 原生闹钟、通知、定位和桌面小组件能力。

完整项目文档见根目录：

- `../README.md`
- `../docs/README.md`

## 功能

- 便签文本编辑和自动保存。
- 公历月历、农历、传统节日、法定休假和调休标记。
- 日程安排，点击日期添加。
- 7 类提醒：单次、每天、每周、每月、每年、每年农历、每月农历。
- 提醒列表查看与删除。
- 7 种预设主题颜色。
- 天气定位、手动城市查询和 7 日预报。
- 应用内模拟/数字时钟。
- Android 数字时钟和模拟时钟桌面小组件。
- Android 原生 `AlarmManager` 提醒、通知、开机恢复和前台保活服务。
- WebDAV 加密同步，可与 Windows 桌面版共用同一个云端同步文件。

## 编译运行

### 前提条件

1. 安装 Flutter SDK。
2. 安装 Android Studio 或 Android SDK。
3. 配置 JDK 17。
4. 确认 `flutter doctor -v` 没有阻断性错误。

### 调试运行

```bash
cd sticky_android
flutter pub get
flutter run
```

### 打包 APK

```bash
cd sticky_android
flutter build apk --release
```

APK 输出路径：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 文件结构

```text
lib/main.dart
  数据模型、存储、天气、农历、主界面、日历和时钟 UI

android/app/src/main/kotlin/com/example/sticky_android/
  MainActivity.kt             # MethodChannel、权限、原生闹钟、定位、小组件固定
  AlarmReceiver.kt            # 闹钟触发、声音、振动、通知、重复调度
  BootReceiver.kt             # 开机恢复
  AlarmKeepAliveService.kt    # 前台保活服务
  ClockWidgetProvider.kt      # 数字/模拟时钟小组件

tools/
  apple_setup_check.sh
  build_ios.sh
  build_macos.sh
```

## 数据

Android 数据保存到应用私有目录：

```text
sticky_notes.json
sync_config.json
```

主要字段包括：

- `content`
- `color`
- `show_calendar`
- `show_clock`
- `clock_style`
- `weather`
- `reminders`
- `schedules`
- `_sync_meta`

详细字段见 `../docs/data-model.md`。

## 注意事项

- Android 原生闹钟当前只调度 `once`、`daily`、`weekly`、`monthly`、`yearly` 这 5 类公历提醒。
- 农历重复提醒仍由 Flutter 侧运行时检查，应用完全退出后可靠性低于原生闹钟。
- `sync_config.json` 位于应用私有目录，包含 WebDAV 应用密码和同步密码；卸载应用会删除该配置。
- 天气依赖网络和 Open-Meteo 服务。
- `test/widget_test.dart` 仍是 Flutter 模板测试，需要改造成当前应用的真实 smoke test。
- iOS/macOS 构建需要 macOS + Xcode，详见 `APPLE_BUILD.md`。
