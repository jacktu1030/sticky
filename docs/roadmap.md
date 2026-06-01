# 路线图与已知限制

## 已知限制

- 桌面版代码集中在 `sticky_note.py`，文件较大，后续维护成本高。
- 桌面版和 Flutter 版提醒字段仍有差异；WebDAV 同步会保留未知字段，但部分手机界面暂不展示桌面端全部能力。
- 顶层数据缺少 `schema_version`。
- Flutter 模板测试尚未改造，当前自动化测试不能反映真实功能。
- Android 原生闹钟目前只调度公历单次、每天、每周、每月、每年提醒。
- Android 农历重复提醒未下发原生闹钟。
- Android `AlarmReceiver` 重复调度需要确保 intent 中包含下一次计算所需的 hour/minute/day/month 字段。
- 天气依赖 Open-Meteo 和网络，不保证离线可用。
- 法定节假日和调休数据需要手工维护到未来年份。
- Windows 桌面版已有导入/导出 UI；Windows 和 Android 已实现 WebDAV 加密同步。
- Windows 桌面版 `notes.json` 已使用 DPAPI 加密；Android/Flutter 版本地数据暂未加密。

## 短期修复

优先级 P0：

- 修复或替换 `sticky_android/test/widget_test.dart`，使其引用 `StickyApp` 和真实界面。
- 检查 Android 原生重复提醒 intent 字段，确保触发后能正确安排下一次。
- 为数据文件增加 `schema_version`。

优先级 P1：

- 补充 Python 纯函数单元测试。
- 补充 Flutter 模型序列化测试。
- 整理桌面版提醒匹配逻辑为独立函数。
- 增加天气关闭开关。

优先级 P2：

- 拆分 `sticky_note.py`：
  - `calendar_utils.py`
  - `weather_service.py`
  - `storage.py`
  - `reminders.py`
  - `ui/`
- 增加跨平台数据迁移工具。
- 增加节假日配置文件，减少硬编码。
- 增加用户可配置的提醒声音和静音时段。

## 中期规划

- 统一桌面版和 Flutter 版数据字段。
- 为 Android/Flutter 版增加本地备份和恢复。
- 为 Android/Flutter 版增加可选加密存储。
- 为 Android 小组件增加更多尺寸和主题。
- 支持更多重复规则，例如工作日、每月最后一天、自定义间隔。
- 增加提醒提前量，例如提前 10 分钟、提前 1 天。

## 长期规划

- 多设备冲突合并。
- Android/Flutter 版增加本地备份和恢复。
- Windows 原生通知集成。
- 跨平台共享核心日历和提醒规则。
- 发布安装包和自动更新。

## 决策记录建议

后续遇到以下变化时，建议新增 ADR 或在本文件记录原因：

- 更换天气服务。
- 引入云同步。
- 改变提醒调度策略。
- 改变数据存储格式。
- 引入加密。
- 拆分桌面版架构。
