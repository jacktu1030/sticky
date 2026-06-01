# 数据模型

## 存储位置

### Windows 桌面版

文件：程序目录下的 `notes.json`。

开发环境中即仓库根目录的 `notes.json`。Windows 桌面版会使用 Windows DPAPI 以当前 Windows 用户身份加密保存该文件。旧版明文 JSON 仍可读取，下一次保存会自动迁移为加密封套。

加密封套格式：

```json
{
  "magic": "yuran_calendar_encrypted",
  "version": 1,
  "encrypted": true,
  "method": "windows-dpapi-current-user",
  "payload": "base64..."
}
```

其中 `payload` 解密后才是下文的业务数据结构。

WebDAV 同步配置单独保存到程序目录下的 `sync_config.json`，同样使用 Windows DPAPI 加密。该文件只保存在本机，不会写入云端同步 payload。

### Android/Flutter 版

文件：应用私有目录下的 `sticky_notes.json`。

Android 上 Flutter 通过 MethodChannel 调用 `getAppFilesDir` 获取原生 `filesDir`，再写入 `sticky_notes.json`。

Android WebDAV 同步配置保存到同目录的 `sync_config.json`。该文件位于应用私有目录，包含 WebDAV 应用密码和同步密码；当前 Android 版不额外做系统级加密。

macOS 上路径为：

```text
~/Library/Application Support/雨然日历/sticky_notes.json
```

## 顶层字段

桌面版和 Flutter 版字段接近，但不是完全一致。

| 字段 | 类型 | 桌面版 | Flutter 版 | 说明 |
| --- | --- | --- | --- | --- |
| `content` | string | 是 | 是 | 便签正文 |
| `color` | string | 是 | 是 | 当前主题 key |
| `custom_colors` | object | 是 | 否 | 桌面版自定义主题 |
| `reminders` | array | 是 | 是 | 提醒列表 |
| `schedules` | object | 是 | 是 | 日期到日程列表的映射 |
| `show_calendar` | boolean | 是 | 是 | 是否显示日历 |
| `weather` | object | 是 | 是 | 天气信息 |
| `show_clock` | boolean | 是 | 是 | 是否显示时钟 |
| `clock_style` | string | 是 | 是 | `analog` 或 `digital` |
| `clock_position` | object | 是 | 否 | 桌面悬浮时钟位置 |
| `position` | object | 旧字段 | 否 | 桌面主窗口历史位置字段 |
| `_sync_meta` | object | 是 | 是 | WebDAV 同步元数据，包含 `updated_at` 和 `device_id` |

示例：

```json
{
  "content": "发票\n房租",
  "color": "green",
  "show_calendar": true,
  "show_clock": true,
  "clock_style": "digital",
  "reminders": [],
  "schedules": {
    "2026-06-01": [
      {
        "text": "09:30 周会",
        "done": false
      }
    ]
  },
  "weather": {
    "location": "上海",
    "display": "上海 晴 26°",
    "icon": "☀",
    "code": 0,
    "temperature": 26.2,
    "forecast": []
  },
  "_sync_meta": {
    "updated_at": "2026-06-01T12:00:00Z",
    "device_id": "local-device-id"
  }
}
```

## WebDAV 同步

### 本机同步配置

Windows 版 `sync_config.json` 使用 DPAPI 加密，Android 版 `sync_config.json` 位于应用私有目录。配置结构：

```json
{
  "enabled": true,
  "server_url": "https://dav.example.com/dav/",
  "username": "user@example.com",
  "password": "webdav-app-password",
  "remote_path": "yuran-calendar-sync.json",
  "sync_password": "user-sync-password",
  "auto_sync": false,
  "device_id": "local-device-id",
  "last_sync_at": "2026-06-01T12:10:00Z",
  "last_synced_updated_at": "2026-06-01T12:00:00Z"
}
```

### 云端同步封套

云端 WebDAV 文件不保存明文业务数据。文件格式：

```json
{
  "magic": "yuran_calendar_webdav_sync",
  "version": 1,
  "encrypted": true,
  "method": "pbkdf2-sha256+aes-256-gcm",
  "kdf": {
    "name": "PBKDF2-HMAC-SHA256",
    "iterations": 390000,
    "salt": "base64..."
  },
  "cipher": {
    "name": "AES-256-GCM",
    "nonce": "base64..."
  },
  "updated_at": "2026-06-01T12:00:00Z",
  "device_id": "local-device-id",
  "payload": "base64..."
}
```

`payload` 解密后：

```json
{
  "magic": "yuran_calendar_sync_payload",
  "version": 1,
  "updated_at": "2026-06-01T12:00:00Z",
  "device_id": "local-device-id",
  "data": {}
}
```

跨端兼容要求：

- Android 版读取 Windows 提醒时，应兼容每月提醒的 `day` 与 `monthly_day` 字段。
- Android 版读取 Windows 每年提醒时，应兼容 `month/day` 与 `yearly_month/yearly_day` 字段。
- Android 版读取 Windows 日程时，应兼容字符串日程和 `{ "text": "...", "done": true }` 对象日程。

## 导入导出

Windows 桌面版右上角“设置”窗口中的“数据备份”提供：

- 导出加密备份：生成 `.yuran` 文件，使用 Windows 当前用户 DPAPI 加密，通常只能在当前 Windows 用户下导入。
- 导出明文 JSON：生成可跨设备查看/迁移的 JSON，但会直接包含便签、提醒、日程等内容。
- 导入数据：支持导入 `.yuran` 加密备份或明文 `.json`，导入后会覆盖当前本地数据并重新以加密形式保存到 `notes.json`。

## 提醒字段

通用字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | 提醒类型 |
| `message` | string | 提醒内容 |
| `hour` | number | 0-23 |
| `minute` | number | 0-59 |
| `advance_minutes` | number | 提前通知分钟数，缺省为 0 |
| `enabled` | boolean | 是否启用，缺省为 true |
| `last_triggered` | string/null | 已触发日期，格式 `YYYY-MM-DD` |
| `last_triggered_key` | string/null | 新版触发去重 key，用于区分跨天提前通知 |
| `is_lunar` | boolean | 是否农历语义 |
| `snooze` | boolean | 是否为稍后提醒生成的临时单次提醒 |
| `source` | string | 可选，桌面版从日程创建提醒时为 `schedule` |
| `schedule_date` | string | 可选，来源日程日期，格式 `YYYY-MM-DD` |
| `schedule_item` | string | 可选，创建提醒时对应的日程文本 |

### 单次提醒

桌面版和 Flutter 版一致：

```json
{
  "type": "once",
  "year": 2026,
  "month": 6,
  "day": 1,
  "hour": 9,
  "minute": 0,
  "message": "提交材料",
  "advance_minutes": 30,
  "enabled": true,
  "last_triggered": null,
  "is_lunar": false
}
```

如果 `is_lunar` 为 `true`，`year/month/day` 表示农历年月日。

桌面版从日程勾选“同时提醒我”创建的提醒仍保存为普通单次提醒，并额外带来源字段：

```json
{
  "type": "once",
  "year": 2026,
  "month": 6,
  "day": 1,
  "hour": 9,
  "minute": 30,
  "message": "周会",
  "advance_minutes": 10,
  "enabled": true,
  "last_triggered": null,
  "is_lunar": false,
  "source": "schedule",
  "schedule_date": "2026-06-01",
  "schedule_item": "09:30 周会"
}
```

### 每天

```json
{
  "type": "daily",
  "hour": 9,
  "minute": 0,
  "message": "喝水",
  "advance_minutes": 0,
  "last_triggered": null,
  "is_lunar": false
}
```

### 每周

`weekday` 使用 0-6 表示周一到周日。

```json
{
  "type": "weekly",
  "weekday": 0,
  "hour": 9,
  "minute": 30,
  "message": "周报",
  "advance_minutes": 10,
  "last_triggered": null,
  "is_lunar": false
}
```

### 每月

桌面版字段：

```json
{
  "type": "monthly",
  "day": 12,
  "hour": 15,
  "minute": 0,
  "message": "收租",
  "last_triggered": null,
  "is_lunar": false
}
```

Flutter 版字段：

```json
{
  "type": "monthly",
  "monthly_day": 12,
  "hour": 15,
  "minute": 0,
  "message": "收租",
  "last_triggered": null,
  "is_lunar": false
}
```

### 每年

桌面版字段：

```json
{
  "type": "yearly",
  "month": 4,
  "day": 6,
  "hour": 9,
  "minute": 0,
  "message": "生日",
  "last_triggered": null,
  "is_lunar": false
}
```

Flutter 版字段：

```json
{
  "type": "yearly",
  "yearly_month": 4,
  "yearly_day": 6,
  "hour": 9,
  "minute": 0,
  "message": "生日",
  "last_triggered": null,
  "is_lunar": false
}
```

### 每年农历

```json
{
  "type": "lunar_yearly",
  "lunar_month": 5,
  "lunar_day": 8,
  "hour": 16,
  "minute": 0,
  "message": "农历生日",
  "last_triggered": null,
  "is_lunar": true
}
```

### 每月农历

```json
{
  "type": "lunar_monthly",
  "lunar_day": 15,
  "hour": 20,
  "minute": 0,
  "message": "农历十五提醒",
  "last_triggered": null,
  "is_lunar": true
}
```

## 日程字段

`schedules` 是日期字符串到日程数组的映射。旧版日程可以是字符串；新版桌面版保存为对象，以支持已办状态。

```json
{
  "schedules": {
    "2026-06-01": [
      {
        "text": "09:30 周会",
        "done": false
      },
      {
        "text": "18:00 买菜",
        "done": true
      }
    ]
  }
}
```

日期格式必须为 `YYYY-MM-DD`。`text` 通常以 `HH:MM ` 开头，后面接日程内容；编辑旧字符串数据时会尽量解析该时间前缀。`done` 表示是否已办，缺省按 `false` 处理。删除某天最后一条日程后，桌面版会移除对应日期 key。

提醒勾选“同步到日程”时不会新增提醒专用字段，而是根据提醒下一次触发时间向 `schedules` 写入一条普通日程对象。重复提醒只写入下一次触发日期，后续重复仍由提醒系统负责。

## 天气字段

桌面版天气对象：

```json
{
  "location": {
    "name": "上海",
    "latitude": 31.2304,
    "longitude": 121.4737,
    "source": "manual"
  },
  "display": "上海 晴 26°",
  "icon": "☀",
  "code": 0,
  "temperature": 26.2,
  "forecast": [
    {
      "date": "2026-06-01",
      "icon": "☀",
      "weather": "晴",
      "min_temp": 21.0,
      "max_temp": 28.0
    }
  ],
  "updated_at": "2026-06-01 10:30"
}
```

Flutter 版天气对象：

```json
{
  "location": "上海",
  "display": "上海 晴 26°",
  "icon": "☀",
  "latitude": 31.2304,
  "longitude": 121.4737,
  "temperature": 26.2,
  "code": 0,
  "updated_at": "2026-06-01T10:30:00.000",
  "forecast": [
    {
      "date": "2026-06-01T00:00:00.000",
      "code": 0,
      "min_temp": 21.0,
      "max_temp": 28.0
    }
  ]
}
```

## 主题字段

预设主题 key：

- `yellow`
- `green`
- `blue`
- `pink`
- `purple`
- `white`
- `dark`

桌面版自定义主题保存到 `custom_colors`：

```json
{
  "custom_colors": {
    "custom_1": {
      "bg": "#FFFFFF",
      "fg": "#212121",
      "today": "#1976D2",
      "holiday": "#D32F2F",
      "weekend": "#EEEEEE"
    }
  }
}
```

## 兼容性注意

- 桌面版和 Flutter 版不是同一个数据文件，字段也存在差异，不应直接互相覆盖。
- 如需做跨平台迁移，应先写迁移脚本处理 `monthly/day` 与 `monthly_day`、`yearly/month/day` 与 `yearly_month/yearly_day` 的差异。
- 建议后续增加顶层 `schema_version` 字段，便于安全迁移。
