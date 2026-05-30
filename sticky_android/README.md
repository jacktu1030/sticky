# 雨然日历

用 Flutter 重写的 Android 日历便签应用，移植自 Python tkinter 桌面版。

## 功能

- 便签文本编辑（自动保存）
- 公历日历显示（支持年月导航）
- 农历显示（含农历查表算法，初一只显示月份）
- 中国传统节日 + 法定节假日高亮标注
- 主题颜色切换（7 种预设主题）
- 提醒系统（7 种类型）：
  - 单次（支持农历）
  - 每天
  - 每周
  - 每月
  - 每年
  - 每年农历
  - 每月农历
- 日程安排（点击日期添加）
- 提醒列表查看与删除

## 编译运行

### 前提条件

1. 安装 Flutter SDK：https://docs.flutter.dev/get-started/install
2. 安装 Android Studio 或 Android SDK
3. 配置好 `flutter doctor` 无报错

### 步骤

```bash
cd sticky_android
flutter pub get
flutter run
```

### 打包 APK

```bash
flutter build apk --release
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

## 文件结构

```
lib/
  main.dart          # 单文件包含全部代码（数据模型、存储、日历、UI）
```

## 注意

- 数据存储在应用临时目录的 `sticky_notes.json` 文件中
- 后台提醒（app 关闭后响铃）当前未实现，需要接入 `flutter_local_notifications` + `android_alarm_manager_plus`
- 农历计算使用内置查表法，覆盖 1900-2100 年
