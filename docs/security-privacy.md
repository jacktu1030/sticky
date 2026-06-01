# 隐私与安全

## 数据存储

雨然日历默认不使用账号体系。未启用云同步时，以下数据只保存在本机：

- 便签正文。
- 提醒内容。
- 日程内容。
- 主题配置。
- 天气位置和最近天气结果。
- 悬浮时钟状态。

桌面版：

```text
notes.json
```

Windows 桌面版的 `notes.json` 使用 Windows DPAPI 按当前 Windows 用户加密保存。旧版明文 JSON 可被读取，下一次保存会自动迁移为加密封套。

Android/Flutter 版：

```text
应用私有目录/sticky_notes.json
应用私有目录/sync_config.json
```

## 敏感文件

以下文件不应提交或发布到公开仓库：

- `notes.json`
- `sync_config.json`
- `*.yuran`
- `sync-conflict-*.yuran`
- `github_token.txt`
- `git.txt`
- 构建产物目录：`build/`、`dist/`、`output/`、`work/`
- 本地 SDK 和压缩包：`flutter/`、`android-sdk/`、`jdk-*/`、`flutter.zip`、`cmdline-tools.zip`

`.gitignore` 当前已经覆盖主要敏感文件和构建产物。

## 网络请求

天气功能使用 Open-Meteo：

- 地理编码：`https://geocoding-api.open-meteo.com/v1/search`
- 天气预报：`https://api.open-meteo.com/v1/forecast`

发送的数据包括：

- 手动输入的城市名，或
- 设备定位得到的经纬度。

项目当前没有使用天气 API 密钥。

启用 WebDAV 同步后，应用还会连接用户填写的 WebDAV 地址，并上传或下载加密后的同步文件。

## Android 权限

Android 版申请以下权限：

| 权限 | 用途 |
| --- | --- |
| `INTERNET` | 查询天气 |
| `ACCESS_COARSE_LOCATION` | 获取粗略定位用于天气 |
| `ACCESS_FINE_LOCATION` | 获取更准确定位用于天气 |
| `POST_NOTIFICATIONS` | Android 13+ 发送提醒通知 |
| `SCHEDULE_EXACT_ALARM` | Android 12+ 精确提醒 |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 降低后台提醒被系统限制的概率 |
| `RECEIVE_BOOT_COMPLETED` | 开机后恢复服务和提醒 |
| `WAKE_LOCK` | 提醒触发时短暂唤醒设备 |
| `VIBRATE` | 提醒振动 |
| `USE_FULL_SCREEN_INTENT` | 锁屏或重要提醒弹窗 |
| `FOREGROUND_SERVICE` | 保持提醒服务运行 |

权限申请应向用户说明用途，尤其是定位、通知、电池优化和精确闹钟。

## Windows 开机启动

桌面版开机启动写入当前用户注册表：

```text
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
```

注册值名称：

```text
雨然日历
```

该行为只影响当前用户，不需要管理员权限。

Windows 桌面版不再启动时自动弹窗要求开启自启动。用户可从右上角“设置”窗口查看状态并手动开启或关闭；关闭时会删除上述注册表值。

## 导入导出安全

Windows 桌面版右上角“设置”窗口中的“数据备份”支持：

- 导出加密备份：使用当前 Windows 用户 DPAPI 加密，适合本机备份；通常不能在其他 Windows 用户或其他电脑上解密。
- 导出明文 JSON：便于迁移和人工检查，但文件会直接包含便签、提醒、日程等内容。
- 导入数据：导入 `.yuran` 或 `.json` 后会覆盖当前数据，并重新加密写入本机 `notes.json`。

明文 JSON 不应上传到公开仓库、网盘共享目录或聊天窗口。加密备份也应妥善保存，避免被恶意覆盖或误导入。

## WebDAV 同步安全

Windows 桌面版 WebDAV 同步配置保存到本机 `sync_config.json`，使用当前 Windows 用户 DPAPI 加密。Android 版同步配置保存到应用私有目录 `sync_config.json`，包含 WebDAV 应用密码和同步密码；卸载应用会删除该配置。配置不会写入云端同步 payload。

云端同步文件使用同步密码加密：

- PBKDF2-HMAC-SHA256 派生密钥。
- AES-256-GCM 加密和完整性校验。
- 云端文件不应直接暴露便签、提醒、日程正文。

同步密码必须由用户自行记住。忘记同步密码后，云端同步文件无法恢复。WebDAV 服务提供商仍能看到账号、访问时间、远程文件名和加密文件大小。

缓解建议：

- 使用 WebDAV 服务提供的应用专用密码，不使用主账号密码。
- 同步密码应与 WebDAV 密码不同。
- 远程文件名避免包含敏感信息。
- 多设备同步前保留一次本地加密备份。
- Android 手机应开启系统锁屏，降低应用私有目录被本机攻击者读取的风险。

## 安全风险

### 本地加密边界

DPAPI 加密绑定当前 Windows 用户，能降低其他本机用户或普通文件读取工具直接查看内容的风险。但如果当前 Windows 账户已被登录、恶意程序在该账户下运行，仍可能通过应用或系统 API 访问解密后的数据。

缓解建议：

- 不在便签中保存密码、令牌、身份证号等高敏数据。
- Windows 账户应设置登录密码并保持系统更新。
- 跨设备迁移时优先短时间使用明文 JSON，导入后及时删除明文备份。
- 多设备同步优先使用 WebDAV 加密同步，不上传明文 JSON。

### 外部天气请求

天气查询会向第三方服务发送城市名或经纬度。

缓解建议：

- 首次请求天气前明确说明用途。
- 提供关闭天气或仅手动城市的选项。

### Android 后台保活

前台服务和电池优化白名单可能增加耗电和常驻通知。

缓解建议：

- 保持通知文案明确。
- 提供关闭后台提醒增强能力的配置项。

### 单实例和 PID 文件

桌面版存在单实例和旧进程处理逻辑。发布前应确认不会误杀非本应用进程。

## 发布安全清单

- 仓库中没有 token 和真实用户数据。
- APK/EXE 不包含开发者本地数据文件。
- Android 权限和隐私说明一致。
- WebDAV 同步密码、应用密码和本地数据文件没有提交到仓库。
- 天气失败不会泄露异常堆栈给普通用户。
- 打包产物只包含必要资源。
- 发布前重新检查 `.gitignore` 是否覆盖新增本地文件。
