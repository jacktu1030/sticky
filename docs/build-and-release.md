# 构建与发布

## Windows 桌面版

### 环境

- Windows 10/11。
- Python 3.10+。
- 推荐依赖：

```powershell
pip install pillow zhdate cnlunar cryptography pyinstaller
```

依赖说明：

- `pillow`：加载和处理图标资源。
- `zhdate`：农历日期转换，农历提醒依赖。
- `cnlunar`：农历信息兜底。
- `cryptography`：WebDAV 同步文件的 PBKDF2 + AES-256-GCM 加密。
- `pyinstaller`：打包 EXE。

### 本地运行

```powershell
python sticky_note.py
```

### 打包

英文产物名：

```powershell
pyinstaller yuran_calendar.spec
```

中文产物名：

```powershell
pyinstaller 雨然日历.spec
```

规格文件会打包：

- `sticky_note.py`
- `binder-fold.png`
- `logo.png`
- `binder-fold.ico`

默认输出：

```text
dist/
build/
```

### 开机启动

桌面版使用当前用户注册表：

```text
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
```

注册项名称：

```text
雨然日历
```

桌面版右上角“设置”窗口提供开机自启动开关。发布检查时应验证开启会写入该注册项，关闭会删除该注册项。

## Android/Flutter 版

### 环境

- Flutter SDK。
- Android SDK。
- JDK 17。
- 可用 Android 设备或模拟器。

Flutter 依赖包含：

- `cryptography`：WebDAV 同步文件的 PBKDF2 + AES-256-GCM 加密。

检查：

```powershell
cd sticky_android
flutter doctor -v
flutter pub get
```

### 调试运行

```powershell
cd sticky_android
flutter run
```

### 发布 APK

```powershell
cd sticky_android
flutter build apk --release
```

输出路径：

```text
sticky_android/build/app/outputs/flutter-apk/app-release.apk
```

### Android 权限检查

发布前确认 `AndroidManifest.xml` 包含并符合目标系统要求：

- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `WAKE_LOCK`
- `VIBRATE`
- `FOREGROUND_SERVICE`
- `INTERNET`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`

Android 12+ 需要用户授权精确闹钟。Android 13+ 需要用户授权通知。

## Apple 平台

仓库包含 macOS 工程和 Apple 构建脚本，但 iOS/macOS 发布必须在 macOS + Xcode 环境中完成。

详见：

```text
sticky_android/APPLE_BUILD.md
```

常用命令：

```bash
cd sticky_android
chmod +x tools/*.sh
./tools/apple_setup_check.sh
./tools/build_macos.sh
./tools/build_ios.sh nosign
```

## 发布前检查

- 根目录不应包含待提交的 `notes.json`、`sync_config.json`、token 或构建产物。
- 桌面版运行后能创建/更新 `notes.json`。
- Android 版运行后能创建/更新 `sticky_notes.json`。
- 新增提醒后 Android 原生闹钟能收到调度。
- 天气接口失败时 UI 有兜底显示。
- 应用图标在桌面版、Android 启动器和小组件中显示正常。

## 版本建议

当前 Flutter 版本号位于：

```text
sticky_android/pubspec.yaml
```

字段：

```yaml
version: 1.0.0+1
```

建议发布时遵循：

- 功能新增：递增次版本，例如 `1.1.0+2`。
- 缺陷修复：递增补丁版本，例如 `1.0.1+2`。
- Android `+build` 号每次上架必须递增。
