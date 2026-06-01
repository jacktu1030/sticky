# 技术架构

## 总览

雨然日历采用本地单体架构。桌面版和 Flutter 版独立实现 UI 和运行时能力，但共享产品概念：便签、日历、日程、提醒、天气、主题和时钟。

```text
Windows 桌面版
  sticky_note.py
    ├─ tkinter UI
    ├─ 本地 notes.json（Windows DPAPI 加密）
    ├─ 本地 sync_config.json（Windows DPAPI 加密）
    ├─ 提醒检查线程
    ├─ Open-Meteo 天气请求
    ├─ WebDAV 加密同步
    └─ Windows 注册表开机启动

Flutter/Android 版
  sticky_android/lib/main.dart
    ├─ Flutter UI
    ├─ 本地 sticky_notes.json
    ├─ 本地 sync_config.json（应用私有目录）
    ├─ Open-Meteo 天气请求
    ├─ WebDAV 加密同步
    └─ MethodChannel
         └─ Android Kotlin 原生层
             ├─ AlarmManager
             ├─ Notification
             ├─ BootReceiver
             ├─ Foreground Service
             └─ AppWidgetProvider
```

## 桌面版模块

主文件：`sticky_note.py`。

### 常量和工具函数

- 应用目录和数据文件路径。
- 主题颜色。
- 天气码映射。
- 农历文本格式化。
- 星座计算。
- Open-Meteo HTTP JSON 请求。

### `StickyNote`

承担桌面版全部业务和 UI：

- 初始化窗口、加载数据、构建 UI。
- 构建月历、节日、休班、日程和提醒标记。
- 展示今日事项面板，汇总今天和明天的日程、提醒。
- 提供上一月、下一月、返回今天和跳转年月的日历导航。
- 新增/删除提醒。
- 新增、列表查看、编辑和删除日程。
- 从日程创建单次提醒，并保留日程来源字段。
- 从提醒的下一次触发时间创建普通日程条目。
- 自动保存。
- 数据加密保存、加密/明文导入导出。
- 通过当前用户注册表开关 Windows 开机启动。
- 展示和更新悬浮时钟。
- 拉取天气和预报。
- 管理关闭流程和单实例 PID。

### 提醒机制

桌面版使用后台守护线程轮询：

- 启动后等待 5 秒。
- 每轮读取当前时间。
- 匹配当前小时和分钟。
- 根据提醒类型判断是否触发。
- 使用 `last_triggered` 避免同一天重复提醒。
- 通过 tkinter 主线程弹窗展示提醒。

## Flutter 模块

主文件：`sticky_android/lib/main.dart`。

### 数据模型

- `Reminder`：提醒类型、时间、内容和重复参数。
- `ForecastDay`：单日天气预报。
- `WeatherInfo`：当前天气和预报集合。

### 服务

- `StorageService`：初始化平台数据路径，读写 `sticky_notes.json` 和 `sync_config.json`。
- `WeatherService`：地理编码和天气查询。
- `WebDavSyncService`：WebDAV 请求、PBKDF2 密钥派生和 AES-256-GCM 同步文件加解密。
- `LunarCalendar`：农历查表计算。

### 应用状态

`StickyApp` 维护核心状态：

- 便签内容。
- 当前主题。
- 日历显示开关。
- 时钟显示开关和样式。
- 天气数据。
- 提醒列表。
- 日程映射。

状态变化后调用 `_saveData()` 写入本地文件，并同步 Android 原生闹钟和小组件天气。

### UI 组件

- `HomeScreen`：主页面、日历和弹窗交互。
- `ClockPanel`：应用内时钟。
- `AnalogClockPainter`：Flutter Canvas 模拟时钟绘制。
- `CalendarWidget`：月视图日历。

## Android 原生模块

目录：`sticky_android/android/app/src/main/kotlin/com/example/sticky_android/`。

### `MainActivity.kt`

职责：

- 创建通知渠道。
- 请求通知、定位、精确闹钟和电池优化权限。
- 启动前台保活服务。
- 暴露 MethodChannel：
  - `scheduleAlarms`
  - `cancelAllAlarms`
  - `getAppFilesDir`
  - `checkAlarmPermission`
  - `getLastKnownLocation`
  - `pinClockWidget`
  - `syncWidgetWeather`
- 将公历提醒注册为 `AlarmManager.setAlarmClock`。

### `AlarmReceiver.kt`

职责：

- 接收闹钟广播。
- 点亮屏幕。
- 播放系统闹钟声音和振动。
- 发出 heads-up/full-screen 通知。
- 对部分重复提醒重新安排下一次。

### `BootReceiver.kt`

职责：

- 接收 `BOOT_COMPLETED`。
- 启动前台服务。
- 启动主 Activity，让 Flutter 侧重新设置闹钟。

### `AlarmKeepAliveService.kt`

职责：

- 启动常驻前台服务。
- 显示低优先级通知，降低提醒进程被系统回收的概率。

### `ClockWidgetProvider.kt`

职责：

- 提供数字和模拟时钟小组件。
- 每分钟更新显示。
- 从共享偏好或 `sticky_notes.json` 读取天气摘要。
- 点击小组件打开主应用。

## 外部依赖

### 桌面版

- Python 标准库：`tkinter`、`json`、`threading`、`urllib`、`winreg` 等。
- Pillow：图像资源处理。
- zhdate：农历日期转换，桌面版农历提醒依赖。
- cnlunar：部分农历信息兜底。
- cryptography：WebDAV 同步文件的 PBKDF2 + AES-256-GCM 加密。
- PyInstaller：Windows EXE 打包。

### Flutter/Android 版

- Flutter SDK。
- Android Gradle 插件和 Kotlin。
- Android 系统能力：`AlarmManager`、`NotificationManager`、`AppWidgetManager`、`LocationManager`。

## 关键数据流

### 保存

```text
用户操作
  -> 更新内存状态
  -> 序列化业务 JSON
  -> Windows DPAPI 加密封套
  -> 写入 notes.json
  -> Android: 重新调度原生闹钟
  -> Android: 同步天气到小组件存储
```

### 导入导出

```text
导出加密备份
  -> 读取当前内存状态
  -> DPAPI 加密
  -> 写入 .yuran

导出明文 JSON
  -> 用户二次确认
  -> 写入业务 JSON

导入数据
  -> 读取 .yuran 或 .json
  -> 必要时 DPAPI 解密
  -> 覆盖内存状态
  -> 加密写回 notes.json
```

### WebDAV 加密同步

```text
本机业务数据
  -> 写入 _sync_meta.updated_at
  -> PBKDF2-HMAC-SHA256 从同步密码派生密钥
  -> AES-256-GCM 加密同步 payload
  -> HTTP/WebDAV PUT 到远程同步文件

WebDAV GET 远程同步文件
  -> 使用同步密码解密
  -> 比较本机和云端 updated_at
  -> 云端较新时先生成本机冲突备份再覆盖
  -> 本机较新时上传覆盖云端
  -> 两端都修改时提示用户选择保留方向
```

### 天气

```text
系统定位或城市名
  -> Open-Meteo Geocoding
  -> Open-Meteo Forecast
  -> WeatherInfo/weather 字段
  -> UI 展示
  -> Android 数字小组件同步温度和天气码
```

### Android 闹钟

```text
Flutter reminders
  -> MethodChannel scheduleAlarms
  -> MainActivity 过滤支持类型
  -> AlarmManager.setAlarmClock
  -> AlarmReceiver
  -> 通知/声音/振动
```

## 设计取舍

- 单文件桌面版降低分发复杂度，但长期会增加维护成本。
- Android 使用原生闹钟而非纯 Flutter 定时器，提高后台提醒可靠性。
- 天气使用无账号的 Open-Meteo，减少密钥管理，但依赖外部网络。
- 数据本地 JSON 存储简单透明，但缺少并发写入保护和迁移版本号。
