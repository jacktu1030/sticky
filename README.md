# 雨然日历

雨然日历是一个本地优先的便签、日历、提醒和天气小工具项目。仓库当前包含两条实现线：

- `sticky_note.py`：Windows 桌面版，基于 Python tkinter，可打包为独立 EXE。
- `sticky_android/`：Flutter 版，面向 Android，同时保留 macOS/iOS 构建脚本与说明。

## 核心能力

- 便签文本编辑与自动保存。
- 公历日历、农历显示、节日/节气、法定休假和调休标记，支持返回今天和跳转年月。
- 今日事项面板，集中查看今天和明天的日程、提醒。
- 日程安排，支持按日期记录多个事项、列表查看、完成/撤销完成、编辑、删除，并可创建对应提醒。
- 提醒系统，支持单次、每天、每周、每月、每年、每年农历、每月农历和提前通知，也可同步写入日程。
- Windows 桌面版本地数据加密保存，并支持加密备份导入/导出。
- Windows 桌面版和 Android 版支持 WebDAV 加密同步，可在多台电脑和手机间同步数据。
- Windows 桌面版支持从右上角“设置”窗口开关当前用户开机自启动。
- 主题颜色切换，桌面版支持自定义主题。
- 天气显示与 7 日预报，使用 Open-Meteo 查询天气和地理编码。
- 时钟显示：
  - Windows 桌面版支持悬浮模拟/数字时钟。
  - Android 版支持应用内时钟和系统桌面小组件。
- Android 原生闹钟、通知、开机恢复和前台保活服务。

## 快速开始

### Windows 桌面版

建议使用 Python 3.10+。

```powershell
pip install pillow zhdate cnlunar cryptography pyinstaller
python sticky_note.py
```

打包 EXE：

```powershell
pyinstaller yuran_calendar.spec
```

或使用中文文件名规格：

```powershell
pyinstaller 雨然日历.spec
```

构建产物默认输出到 `dist/`。桌面版数据文件为程序目录下的 `notes.json`，Windows 版会使用当前 Windows 用户的 DPAPI 加密保存。WebDAV 同步配置单独保存到 `sync_config.json`，同样使用 DPAPI 加密。

### Android/Flutter 版

```powershell
cd sticky_android
flutter pub get
flutter run
```

打包 APK：

```powershell
flutter build apk --release
```

Android 版数据文件为应用私有目录中的 `sticky_notes.json`，WebDAV 同步配置保存为应用私有目录中的 `sync_config.json`。

## 项目结构

```text
.
├── sticky_note.py                  # Windows 桌面主程序
├── yuran_calendar.spec             # PyInstaller 英文产物名配置
├── 雨然日历.spec                    # PyInstaller 中文产物名配置
├── binder-fold.* / logo.*          # 桌面版图标和应用资源
├── sticky_android/                 # Flutter/Android 子项目
│   ├── lib/main.dart               # Flutter 主程序
│   ├── android/                    # Android 原生桥接、闹钟和小组件
│   ├── macos/                      # Flutter macOS 工程
│   └── tools/                      # Apple 平台构建检查脚本
└── docs/                           # 项目文档
```

## 文档

- [文档索引](docs/README.md)
- [需求规格](docs/requirements.md)
- [产品与交互设计](docs/design.md)
- [技术架构](docs/architecture.md)
- [数据模型](docs/data-model.md)
- [构建与发布](docs/build-and-release.md)
- [测试方案](docs/testing.md)
- [隐私与安全](docs/security-privacy.md)
- [路线图与已知限制](docs/roadmap.md)

## 当前注意事项

- `notes.json`、`sync_config.json` 和 `sticky_notes.json` 是用户本地数据，不应提交到版本库。
- Windows 桌面版右上角“设置”窗口整合主题、城市、开机启动、云同步和数据备份；明文 JSON 应妥善保管。
- WebDAV 云端同步文件使用同步密码加密；Windows 和 Android 使用同一格式，忘记同步密码后无法恢复云端数据。
- 天气功能依赖网络和 Open-Meteo 服务；定位失败时需要用户手动输入城市。
- Android 原生闹钟当前只调度公历单次、每天、每周、每月、每年提醒；农历重复提醒仍由 Flutter 侧运行时检查。
- `sticky_android/test/widget_test.dart` 仍是 Flutter 模板测试，和当前 `StickyApp` 入口不匹配，需要后续改造。
