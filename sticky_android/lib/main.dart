import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  runApp(const StickyApp());
}

// ===================== 主题配置 =====================
final Map<String, Map<String, dynamic>> defaultColors = {
  'yellow': {
    'bg': const Color(0xFFFFF9C4),
    'fg': const Color(0xFF212121),
    'today': const Color(0xFFFF9800),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFFFFE0B2),
  },
  'green': {
    'bg': const Color(0xFFC8E6C9),
    'fg': const Color(0xFF1B5E20),
    'today': const Color(0xFF2E7D32),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFFA5D6A7),
  },
  'blue': {
    'bg': const Color(0xFFBBDEFB),
    'fg': const Color(0xFF0D47A1),
    'today': const Color(0xFF1565C0),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFF90CAF9),
  },
  'pink': {
    'bg': const Color(0xFFF8BBD9),
    'fg': const Color(0xFF880E4F),
    'today': const Color(0xFFC2185B),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFFF48FB1),
  },
  'purple': {
    'bg': const Color(0xFFE1BEE7),
    'fg': const Color(0xFF4A148C),
    'today': const Color(0xFF6A1B9A),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFFCE93D8),
  },
  'white': {
    'bg': const Color(0xFFFFFFFF),
    'fg': const Color(0xFF212121),
    'today': const Color(0xFF1976D2),
    'holiday': const Color(0xFFD32F2F),
    'weekend': const Color(0xFFEEEEEE),
  },
  'dark': {
    'bg': const Color(0xFF263238),
    'fg': const Color(0xFFFFFFFF),
    'today': const Color(0xFFFF9800),
    'holiday': const Color(0xFFFF5252),
    'weekend': const Color(0xFF37474F),
  },
};

// ===================== 数据模型 =====================
class Reminder {
  String type;
  String message;
  int hour;
  int minute;
  String? lastTriggered;
  bool isLunar;
  bool enabled;
  bool done;
  int advanceMinutes;
  Map<String, dynamic> extra;

  // once
  int? year;
  int? month;
  int? day;

  // weekly
  int? weekday;

  // monthly
  int? monthlyDay;

  // yearly
  int? yearlyMonth;
  int? yearlyDay;

  // lunar
  int? lunarMonth;
  int? lunarDay;

  Reminder({
    required this.type,
    required this.message,
    required this.hour,
    required this.minute,
    this.lastTriggered,
    this.isLunar = false,
    this.enabled = true,
    this.done = false,
    this.advanceMinutes = 0,
    this.year,
    this.month,
    this.day,
    this.weekday,
    this.monthlyDay,
    this.yearlyMonth,
    this.yearlyDay,
    this.lunarMonth,
    this.lunarDay,
    this.extra = const {},
  });

  Reminder copyWith({
    String? type,
    String? message,
    int? hour,
    int? minute,
    String? lastTriggered,
    bool? isLunar,
    bool? enabled,
    bool? done,
    int? advanceMinutes,
    int? year,
    int? month,
    int? day,
    int? weekday,
    int? monthlyDay,
    int? yearlyMonth,
    int? yearlyDay,
    int? lunarMonth,
    int? lunarDay,
    Map<String, dynamic>? extra,
    bool clearLastTriggered = false,
  }) =>
      Reminder(
        type: type ?? this.type,
        message: message ?? this.message,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        lastTriggered:
            clearLastTriggered ? null : (lastTriggered ?? this.lastTriggered),
        isLunar: isLunar ?? this.isLunar,
        enabled: enabled ?? this.enabled,
        done: done ?? this.done,
        advanceMinutes: advanceMinutes ?? this.advanceMinutes,
        year: year ?? this.year,
        month: month ?? this.month,
        day: day ?? this.day,
        weekday: weekday ?? this.weekday,
        monthlyDay: monthlyDay ?? this.monthlyDay,
        yearlyMonth: yearlyMonth ?? this.yearlyMonth,
        yearlyDay: yearlyDay ?? this.yearlyDay,
        lunarMonth: lunarMonth ?? this.lunarMonth,
        lunarDay: lunarDay ?? this.lunarDay,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'type': type,
        'message': message,
        'hour': hour,
        'minute': minute,
        'last_triggered': lastTriggered,
        'is_lunar': isLunar,
        'enabled': enabled,
        'done': done,
        'advance_minutes': advanceMinutes,
        if (year != null) 'year': year,
        if (month != null) 'month': month,
        if (day != null) 'day': day,
        if (weekday != null) 'weekday': weekday,
        if (monthlyDay != null) 'monthly_day': monthlyDay,
        if (yearlyMonth != null) 'yearly_month': yearlyMonth,
        if (yearlyDay != null) 'yearly_day': yearlyDay,
        if (lunarMonth != null) 'lunar_month': lunarMonth,
        if (lunarDay != null) 'lunar_day': lunarDay,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json);
    for (final key in {
      'type',
      'message',
      'hour',
      'minute',
      'last_triggered',
      'is_lunar',
      'enabled',
      'done',
      'advance_minutes',
      'year',
      'month',
      'day',
      'weekday',
      'monthly_day',
      'yearly_month',
      'yearly_day',
      'lunar_month',
      'lunar_day',
    }) {
      extra.remove(key);
    }

    int? intField(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    final type = (json['type'] ?? 'once').toString();
    final month = intField('month');
    final day = intField('day');
    return Reminder(
      type: type,
      message: (json['message'] ?? '').toString(),
      hour: intField('hour') ?? 0,
      minute: intField('minute') ?? 0,
      lastTriggered: json['last_triggered']?.toString(),
      isLunar: json['is_lunar'] ?? false,
      enabled: json['enabled'] != false,
      done: json['done'] == true,
      advanceMinutes: intField('advance_minutes') ?? 0,
      year: intField('year'),
      month: month,
      day: day,
      weekday: intField('weekday'),
      monthlyDay: intField('monthly_day') ?? (type == 'monthly' ? day : null),
      yearlyMonth:
          intField('yearly_month') ?? (type == 'yearly' ? month : null),
      yearlyDay: intField('yearly_day') ?? (type == 'yearly' ? day : null),
      lunarMonth:
          intField('lunar_month') ?? (type == 'lunar_yearly' ? month : null),
      lunarDay: intField('lunar_day') ??
          (type == 'lunar_yearly' || type == 'lunar_monthly' ? day : null),
      extra: extra,
    );
  }

  String get displayLabel {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final advanceText = advanceMinutes > 0 ? '（提前${advanceMinutes}分钟）' : '';
    final disabledText = enabled ? '' : '（已停用）';
    final doneText = done ? '（已完成）' : '';
    switch (type) {
      case 'once':
        if (isLunar) {
          return '农历 $year年$month月$day日 $timeStr$advanceText$disabledText$doneText';
        }
        return '$year年$month月$day日 $timeStr$advanceText$disabledText$doneText';
      case 'daily':
        return '每天 $timeStr$advanceText$disabledText';
      case 'weekly':
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final index = (weekday ?? 0).clamp(0, weekdays.length - 1);
        return '每周${weekdays[index]} $timeStr$advanceText$disabledText';
      case 'monthly':
        return '每月${monthlyDay}号 $timeStr$advanceText$disabledText';
      case 'yearly':
        return '每年$yearlyMonth月$yearlyDay日 $timeStr$advanceText$disabledText';
      case 'lunar_yearly':
        return '每年农历$lunarMonth月$lunarDay日 $timeStr$advanceText$disabledText';
      case 'lunar_monthly':
        return '每月农历$lunarDay日 $timeStr$advanceText$disabledText';
      default:
        return '$type $timeStr$advanceText$disabledText';
    }
  }
}

// ===================== 天气模型 =====================
class ForecastDay {
  final DateTime date;
  final int code;
  final double? minTemp;
  final double? maxTemp;

  const ForecastDay({
    required this.date,
    required this.code,
    this.minTemp,
    this.maxTemp,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'code': code,
        'min_temp': minTemp,
        'max_temp': maxTemp,
      };

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        code: intValue(json['code'], 0),
        minTemp: doubleValue(json['min_temp'] ?? json['min']),
        maxTemp: doubleValue(json['max_temp'] ?? json['max']),
      );
}

String stringValue(dynamic value, String fallback) {
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is Map) {
    for (final key in ['name', 'display', 'city', 'regionName']) {
      final nested = value[key];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString();
      }
    }
    return fallback;
  }
  final text = value.toString();
  return text.trim().isEmpty ? fallback : text;
}

int intValue(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

dynamic nestedWeatherValue(Map<String, dynamic> json, String key) {
  final direct = json[key];
  if (direct != null) return direct;
  final location = json['location'];
  if (location is Map) return location[key];
  return null;
}

class WeatherInfo {
  final String location;
  final String display;
  final String icon;
  final double? latitude;
  final double? longitude;
  final double? temperature;
  final int? code;
  final DateTime? updatedAt;
  final List<ForecastDay> forecast;

  const WeatherInfo({
    this.location = '天气加载中',
    this.display = '天气加载中',
    this.icon = '○',
    this.latitude,
    this.longitude,
    this.temperature,
    this.code,
    this.updatedAt,
    this.forecast = const [],
  });

  Map<String, dynamic> toJson() => {
        'location': location,
        'display': display,
        'icon': icon,
        'latitude': latitude,
        'longitude': longitude,
        'temperature': temperature,
        'code': code,
        'updated_at': updatedAt?.toIso8601String(),
        'forecast': forecast.map((f) => f.toJson()).toList(),
      };

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
        location: stringValue(json['location'], '天气加载中'),
        display: stringValue(json['display'], '天气加载中'),
        icon: stringValue(json['icon'], '○'),
        latitude: doubleValue(nestedWeatherValue(json, 'latitude')),
        longitude: doubleValue(nestedWeatherValue(json, 'longitude')),
        temperature: doubleValue(json['temperature']),
        code: json['code'] == null ? null : intValue(json['code'], 0),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
        forecast: (json['forecast'] as List? ?? [])
            .whereType<Map>()
            .map((f) => ForecastDay.fromJson(Map<String, dynamic>.from(f)))
            .toList(),
      );

  WeatherInfo copyWith({
    String? location,
    String? display,
    String? icon,
    double? latitude,
    double? longitude,
    double? temperature,
    int? code,
    DateTime? updatedAt,
    List<ForecastDay>? forecast,
  }) =>
      WeatherInfo(
        location: location ?? this.location,
        display: display ?? this.display,
        icon: icon ?? this.icon,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        temperature: temperature ?? this.temperature,
        code: code ?? this.code,
        updatedAt: updatedAt ?? this.updatedAt,
        forecast: forecast ?? this.forecast,
      );
}

// ===================== 存储服务 =====================
const String syncEncryptedMagic = 'yuran_calendar_webdav_sync';
const String syncPayloadMagic = 'yuran_calendar_sync_payload';
const int syncEncryptedVersion = 1;
const String syncEncryptedMethod = 'pbkdf2-sha256+aes-256-gcm';
const int syncKdfIterations = 390000;
const String syncDefaultRemotePath = 'yuran-calendar-sync.json';
const List<int> syncAad = [
  121,
  117,
  114,
  97,
  110,
  45,
  99,
  97,
  108,
  101,
  110,
  100,
  97,
  114,
  45,
  115,
  121,
  110,
  99,
  45,
  118,
  49,
];

String utcNowIso() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(
          now.year, now.month, now.day, now.hour, now.minute, now.second)
      .toIso8601String();
}

DateTime parseSyncTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.tryParse(value)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String scheduleText(dynamic item) {
  if (item is Map) {
    return (item['text'] ?? item['content'] ?? '').toString().trim();
  }
  return item?.toString().trim() ?? '';
}

bool scheduleDone(dynamic item) => item is Map && item['done'] == true;

String scheduleDisplayText(dynamic item) {
  final text = scheduleText(item);
  if (text.isEmpty) return scheduleDone(item) ? '已办 未命名日程' : '未命名日程';
  return scheduleDone(item) ? '已办 $text' : text;
}

DateTime scheduleSortTime(String dateKey, dynamic item) {
  final base = DateTime.tryParse(dateKey) ?? DateTime(9999, 12, 31);
  final text = scheduleText(item);
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (match == null) return base;
  final hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  return DateTime(base.year, base.month, base.day, hour, minute);
}

String scheduleDateLabel(String dateKey) {
  final date = DateTime.tryParse(dateKey);
  if (date == null) return dateKey;
  return '${date.month}月${date.day}日 ${weekdayText(date)}';
}

dynamic scheduleWithDone(dynamic item, bool done) {
  final text = scheduleText(item);
  if (item is Map) {
    return {
      ...Map<String, dynamic>.from(item),
      'text': text,
      'done': done,
    };
  }
  return {
    'text': text,
    'done': done,
  };
}

dynamic scheduleWithText(dynamic item, String text) {
  if (item is Map) {
    return {
      ...Map<String, dynamic>.from(item),
      'text': text.trim(),
      'done': scheduleDone(item),
    };
  }
  return {
    'text': text.trim(),
    'done': false,
  };
}

class ScheduleParts {
  final String hour;
  final String minute;
  final String content;

  const ScheduleParts({
    required this.hour,
    required this.minute,
    required this.content,
  });
}

ScheduleParts parseScheduleParts(dynamic item, DateTime fallback) {
  final text = scheduleText(item);
  final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*(.*)$').firstMatch(text);
  if (match == null) {
    return ScheduleParts(
      hour: fallback.hour.toString().padLeft(2, '0'),
      minute: fallback.minute.toString().padLeft(2, '0'),
      content: text,
    );
  }
  final hour = (int.tryParse(match.group(1) ?? '') ?? fallback.hour)
      .clamp(0, 23)
      .toString()
      .padLeft(2, '0');
  final minute = (int.tryParse(match.group(2) ?? '') ?? fallback.minute)
      .clamp(0, 59)
      .toString()
      .padLeft(2, '0');
  return ScheduleParts(
    hour: hour,
    minute: minute,
    content: (match.group(3) ?? '').trim(),
  );
}

int scheduleItemCount(Map<String, List<dynamic>> schedules) {
  var count = 0;
  for (final items in schedules.values) {
    count += items.length;
  }
  return count;
}

String syncDataSummary(Map<String, dynamic> data) {
  final reminders = data['reminders'];
  final reminderCount = reminders is List ? reminders.length : 0;
  var scheduleCount = 0;
  final schedules = data['schedules'];
  if (schedules is Map) {
    for (final items in schedules.values) {
      if (items is List) scheduleCount += items.length;
    }
  }
  return '提醒 $reminderCount 条，日程 $scheduleCount 条';
}

bool syncDataHasUserContent(Map<String, dynamic> data) {
  if ((data['content'] ?? '').toString().trim().isNotEmpty) return true;
  if (syncDataHasPlanningContent(data)) return true;
  return false;
}

bool syncDataHasPlanningContent(Map<String, dynamic> data) {
  final reminders = data['reminders'];
  if (reminders is List && reminders.isNotEmpty) return true;
  final schedules = data['schedules'];
  if (schedules is Map) {
    for (final items in schedules.values) {
      if (items is List && items.isNotEmpty) return true;
    }
  }
  return false;
}

Map<String, List<dynamic>> parseSchedules(dynamic value) {
  final result = <String, List<dynamic>>{};
  if (value is! Map) return result;
  value.forEach((key, items) {
    if (items is List) {
      result[key.toString()] = items
          .map((item) => item is Map ? Map<String, dynamic>.from(item) : item)
          .toList();
    }
  });
  return result;
}

const Set<String> knownDataKeys = {
  'content',
  'color',
  'show_calendar',
  'show_clock',
  'clock_style',
  'weather',
  'reminders',
  'schedules',
  '_sync_meta',
};

Map<String, dynamic> extraTopLevelData(Map<String, dynamic> data) {
  final extra = Map<String, dynamic>.from(data);
  for (final key in knownDataKeys) {
    extra.remove(key);
  }
  return extra;
}

class SyncConfig {
  final bool enabled;
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final String syncPassword;
  final bool autoSync;
  final String deviceId;
  final String lastSyncAt;
  final String lastSyncedUpdatedAt;

  const SyncConfig({
    this.enabled = false,
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.remotePath = syncDefaultRemotePath,
    this.syncPassword = '',
    this.autoSync = false,
    this.deviceId = '',
    this.lastSyncAt = '',
    this.lastSyncedUpdatedAt = '',
  });

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
        enabled: json['enabled'] == true,
        serverUrl: (json['server_url'] ?? '').toString().trim(),
        username: (json['username'] ?? '').toString().trim(),
        password: (json['password'] ?? '').toString(),
        remotePath:
            (json['remote_path'] ?? syncDefaultRemotePath).toString().trim(),
        syncPassword: (json['sync_password'] ?? '').toString(),
        autoSync: json['auto_sync'] == true,
        deviceId: (json['device_id'] ?? '').toString().trim(),
        lastSyncAt: (json['last_sync_at'] ?? '').toString(),
        lastSyncedUpdatedAt: (json['last_synced_updated_at'] ?? '').toString(),
      ).normalized();

  SyncConfig normalized() => SyncConfig(
        enabled: enabled,
        serverUrl: serverUrl.trim(),
        username: username.trim(),
        password: password,
        remotePath: remotePath.trim().isEmpty
            ? syncDefaultRemotePath
            : remotePath.trim(),
        syncPassword: syncPassword,
        autoSync: autoSync,
        deviceId: deviceId.trim().isEmpty
            ? DateTime.now().microsecondsSinceEpoch.toRadixString(16)
            : deviceId.trim(),
        lastSyncAt: lastSyncAt,
        lastSyncedUpdatedAt: lastSyncedUpdatedAt,
      );

  bool get isReady =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      syncPassword.isNotEmpty &&
      serverUrl.trim().toLowerCase().startsWith(RegExp(r'https?://'));

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'server_url': serverUrl.trim(),
        'username': username.trim(),
        'password': password,
        'remote_path':
            remotePath.trim().isEmpty ? syncDefaultRemotePath : remotePath,
        'sync_password': syncPassword,
        'auto_sync': autoSync,
        'device_id': deviceId,
        'last_sync_at': lastSyncAt,
        'last_synced_updated_at': lastSyncedUpdatedAt,
      };

  SyncConfig copyWith({
    bool? enabled,
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    String? syncPassword,
    bool? autoSync,
    String? deviceId,
    String? lastSyncAt,
    String? lastSyncedUpdatedAt,
  }) =>
      SyncConfig(
        enabled: enabled ?? this.enabled,
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        remotePath: remotePath ?? this.remotePath,
        syncPassword: syncPassword ?? this.syncPassword,
        autoSync: autoSync ?? this.autoSync,
        deviceId: deviceId ?? this.deviceId,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastSyncedUpdatedAt: lastSyncedUpdatedAt ?? this.lastSyncedUpdatedAt,
      ).normalized();
}

class WebDavSyncService {
  static final math.Random _random = math.Random.secure();

  static List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  static void validateConfig(SyncConfig config) {
    if (config.serverUrl.trim().isEmpty) throw Exception('请填写 WebDAV 地址');
    if (!config.serverUrl
        .trim()
        .toLowerCase()
        .startsWith(RegExp(r'https?://'))) {
      throw Exception('WebDAV 地址必须以 http:// 或 https:// 开头');
    }
    if (config.username.trim().isEmpty) throw Exception('请填写 WebDAV 账号');
    if (config.password.isEmpty) throw Exception('请填写 WebDAV 应用密码');
    if (config.syncPassword.isEmpty) throw Exception('请填写同步密码');
  }

  static List<String> _pathSegments(String path) => path
      .replaceAll('\\', '/')
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static Uri fileUri(SyncConfig config, [String? path]) {
    final base = config.serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final segments = _pathSegments(path ?? config.remotePath);
    final encodedPath = segments.isEmpty
        ? syncDefaultRemotePath
        : segments.map(Uri.encodeComponent).join('/');
    return Uri.parse('$base/$encodedPath');
  }

  static String _authHeader(SyncConfig config) {
    final raw = utf8.encode('${config.username}:${config.password}');
    return 'Basic ${base64Encode(raw)}';
  }

  static Future<(int, List<int>)> _request(
    String method,
    Uri uri,
    SyncConfig config, {
    List<int>? body,
    Map<String, String> headers = const {},
    Set<int> allowedStatuses = const {200, 201, 204, 207},
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.openUrl(method, uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'YuranCalendar/1.0');
      req.headers.set(HttpHeaders.authorizationHeader, _authHeader(config));
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(body);
      }
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final bytes = await resp.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      if (!allowedStatuses.contains(resp.statusCode)) {
        throw HttpException('WebDAV 请求失败：HTTP ${resp.statusCode}', uri: uri);
      }
      return (resp.statusCode, bytes);
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> testConnection(SyncConfig config) async {
    validateConfig(config);
    final base = Uri.parse(
        '${config.serverUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/');
    await _request(
      'PROPFIND',
      base,
      config,
      headers: {'Depth': '0'},
      allowedStatuses: {200, 207},
    );
  }

  static Future<void> _ensureParentDirs(SyncConfig config) async {
    final base = config.serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final segments = _pathSegments(config.remotePath);
    var current = base;
    for (final segment in segments.take(math.max(segments.length - 1, 0))) {
      current = '$current/${Uri.encodeComponent(segment)}';
      await _request(
        'MKCOL',
        Uri.parse(current),
        config,
        allowedStatuses: {200, 201, 204, 405},
      );
    }
  }

  static Future<Map<String, dynamic>> encryptPackage(
    Map<String, dynamic> data,
    String password,
    String deviceId,
  ) async {
    final syncData = Map<String, dynamic>.from(data)..remove('sync');
    final meta = syncData['_sync_meta'];
    final updatedAt = meta is Map && meta['updated_at'] != null
        ? meta['updated_at'].toString()
        : utcNowIso();
    final payload = {
      'magic': syncPayloadMagic,
      'version': syncEncryptedVersion,
      'updated_at': updatedAt,
      'device_id': deviceId,
      'data': syncData,
    };
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: syncKdfIterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
      aad: syncAad,
    );
    final encryptedBytes = <int>[...box.cipherText, ...box.mac.bytes];
    return {
      'magic': syncEncryptedMagic,
      'version': syncEncryptedVersion,
      'encrypted': true,
      'method': syncEncryptedMethod,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': syncKdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'AES-256-GCM',
        'nonce': base64Encode(nonce),
      },
      'updated_at': updatedAt,
      'device_id': deviceId,
      'payload': base64Encode(encryptedBytes),
    };
  }

  static Future<Map<String, dynamic>> decryptPackage(
    Map<String, dynamic> envelope,
    String password,
  ) async {
    if (envelope['magic'] != syncEncryptedMagic ||
        envelope['method'] != syncEncryptedMethod) {
      throw Exception('云端文件不是支持的雨然日历同步文件');
    }
    final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);
    final cipher = Map<String, dynamic>.from(envelope['cipher'] as Map);
    final salt = base64Decode(kdf['salt'].toString());
    final nonce = base64Decode(cipher['nonce'].toString());
    final encryptedBytes = base64Decode(envelope['payload'].toString());
    if (encryptedBytes.length <= 16) throw Exception('同步文件内容无效');
    final cipherText = encryptedBytes.sublist(0, encryptedBytes.length - 16);
    final mac = Mac(encryptedBytes.sublist(encryptedBytes.length - 16));
    final iterations = int.tryParse(kdf['iterations'].toString()) ?? 0;
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
      aad: syncAad,
    );
    final payload = jsonDecode(utf8.decode(plain));
    if (payload is! Map || payload['magic'] != syncPayloadMagic) {
      throw Exception('同步文件内容无效');
    }
    return Map<String, dynamic>.from(payload);
  }

  static Future<void> upload(
    SyncConfig config,
    Map<String, dynamic> envelope,
  ) async {
    await _ensureParentDirs(config);
    await _request(
      'PUT',
      fileUri(config),
      config,
      body: utf8.encode(jsonEncode(envelope)),
      allowedStatuses: {200, 201, 204},
    );
  }

  static Future<Map<String, dynamic>?> download(SyncConfig config) async {
    final (status, bytes) = await _request(
      'GET',
      fileUri(config),
      config,
      allowedStatuses: {200, 404},
    );
    if (status == 404) return null;
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }
}

class StorageService {
  static late File _dataFile;
  static late File _syncConfigFile;
  static late Directory _appDir;
  static const MethodChannel _channel =
      MethodChannel('com.example.sticky_android/alarm');

  static Future<void> init() async {
    String path;
    if (Platform.isAndroid) {
      try {
        final dir = await _channel.invokeMethod<String>('getAppFilesDir');
        path = dir ?? Directory.systemTemp.path;
      } catch (e) {
        path = Directory.systemTemp.path;
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      path = '$home/Library/Application Support/雨然日历';
      Directory(path).createSync(recursive: true);
    } else {
      path = Directory.systemTemp.path;
    }
    _appDir = Directory(path);
    _appDir.createSync(recursive: true);
    _dataFile = File('$path/sticky_notes.json');
    _syncConfigFile = File('$path/sync_config.json');
  }

  static Future<Map<String, dynamic>> load() async {
    try {
      if (await _dataFile.exists()) {
        final content = await _dataFile.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      debugPrint('Load error: $e');
    }
    return {};
  }

  static Future<bool> save(Map<String, dynamic> data) async {
    try {
      await _dataFile.writeAsString(jsonEncode(data), flush: true);
      return true;
    } catch (e) {
      debugPrint('Save error: $e');
      return false;
    }
  }

  static Future<SyncConfig> loadSyncConfig() async {
    try {
      if (await _syncConfigFile.exists()) {
        final content = await _syncConfigFile.readAsString();
        return SyncConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(content) as Map),
        );
      }
    } catch (e) {
      debugPrint('Load sync config error: $e');
    }
    return const SyncConfig().normalized();
  }

  static Future<bool> saveSyncConfig(SyncConfig config) async {
    try {
      await _syncConfigFile.writeAsString(
        jsonEncode(config.normalized().toJson()),
        flush: true,
      );
      return true;
    } catch (e) {
      debugPrint('Save sync config error: $e');
      return false;
    }
  }

  static Future<String> writeConflictBackup(
    String source,
    Map<String, dynamic> data,
  ) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '-');
    final path = '${_appDir.path}/sync-conflict-$source-$stamp.json';
    final file = File(path);
    await file.writeAsString(jsonEncode(data), flush: true);
    return path;
  }
}

// ===================== 日期与天气工具 =====================
String dateKeyOf(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

String getConstellation(int month, int day) {
  const boundaries = [
    [1, 20, '水瓶座'],
    [2, 19, '双鱼座'],
    [3, 21, '白羊座'],
    [4, 20, '金牛座'],
    [5, 21, '双子座'],
    [6, 22, '巨蟹座'],
    [7, 23, '狮子座'],
    [8, 23, '处女座'],
    [9, 23, '天秤座'],
    [10, 24, '天蝎座'],
    [11, 23, '射手座'],
    [12, 22, '摩羯座'],
  ];
  var result = '摩羯座';
  for (final b in boundaries) {
    final startMonth = b[0] as int;
    final startDay = b[1] as int;
    if (month > startMonth || (month == startMonth && day >= startDay)) {
      result = b[2] as String;
    } else {
      break;
    }
  }
  return result;
}

int dayOfYear(DateTime dt) => dt.difference(DateTime(dt.year, 1, 1)).inDays + 1;

int isoWeekNumber(DateTime dt) {
  final thursday = dt.add(Duration(days: 4 - dt.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4)
      .add(Duration(days: 4 - DateTime(thursday.year, 1, 4).weekday));
  return 1 + thursday.difference(firstThursday).inDays ~/ 7;
}

String weekdayText(DateTime dt) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][dt.weekday - 1];

String formatTemp(num? value) =>
    value == null ? '--' : value.round().toString();

String shortLocationName(String value) {
  final name = value.trim().isEmpty ? '当前位置' : value.trim();
  final limit = RegExp(r'^[\x00-\x7F]+$').hasMatch(name) ? 10 : 6;
  return name.length <= limit ? name : name.substring(0, limit);
}

const Map<int, String> weatherCodeText = {
  0: '晴',
  1: '晴间多云',
  2: '多云',
  3: '阴',
  45: '雾',
  48: '雾凇',
  51: '小毛雨',
  53: '毛毛雨',
  55: '大毛雨',
  56: '冻毛雨',
  57: '强冻毛雨',
  61: '小雨',
  63: '中雨',
  65: '大雨',
  66: '冻雨',
  67: '强冻雨',
  71: '小雪',
  73: '中雪',
  75: '大雪',
  77: '雪粒',
  80: '阵雨',
  81: '强阵雨',
  82: '暴阵雨',
  85: '阵雪',
  86: '强阵雪',
  95: '雷雨',
  96: '雷暴冰雹',
  99: '强雷暴冰雹',
};

String weatherText(int? code) => weatherCodeText[code ?? -1] ?? '未知';

String weatherIcon(int? code) {
  if (code == null) return '○';
  if (code == 0) return '☀';
  if (code == 1 || code == 2) return '◐';
  if (code == 3) return '☁';
  if (code == 45 || code == 48) return '≋';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return '☂';
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return '❄';
  if (code >= 95) return '⚡';
  return '○';
}

Color weatherIconColor(String icon, Map<String, dynamic> theme) {
  switch (icon) {
    case '☀':
    case '◐':
      return const Color(0xFFF9A825);
    case '☂':
      return const Color(0xFF1976D2);
    case '❄':
      return const Color(0xFF00ACC1);
    case '⚡':
      return const Color(0xFFF57C00);
    case '≋':
      return const Color(0xFF78909C);
    case '☁':
      return const Color(0xFF607D8B);
    default:
      return theme['fg'] as Color;
  }
}

class WeatherService {
  static Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'YuranCalendar/1.0');
      final response =
          await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static Future<WeatherInfo> fetchByLocationName(String name) async {
    final geo = await _fetchJson(Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': name,
        'count': '1',
        'language': 'zh',
        'format': 'json',
      },
    ));
    final results = geo['results'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('未找到位置');
    }
    final first = results.first as Map<String, dynamic>;
    final locationName =
        '${first['name'] ?? name}${first['admin1'] != null ? ' ${first['admin1']}' : ''}';
    return fetchByCoordinates(
      (first['latitude'] as num).toDouble(),
      (first['longitude'] as num).toDouble(),
      locationName.trim(),
    );
  }

  static Future<WeatherInfo> fetchByCoordinates(
    double latitude,
    double longitude,
    String location,
  ) async {
    final data = await _fetchJson(Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current_weather': 'true',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
      },
    ));

    final current = data['current_weather'] as Map<String, dynamic>? ?? {};
    final currentCode =
        (current['weathercode'] as num? ?? current['weather_code'] as num?)
            ?.toInt();
    final temp = (current['temperature'] as num?)?.toDouble();
    final daily = data['daily'] as Map<String, dynamic>? ?? {};
    final times = (daily['time'] as List? ?? []).cast<String>();
    final codes =
        (daily['weather_code'] as List? ?? daily['weathercode'] as List? ?? []);
    final maxTemps = daily['temperature_2m_max'] as List? ?? [];
    final minTemps = daily['temperature_2m_min'] as List? ?? [];

    final forecast = <ForecastDay>[];
    for (var i = 0; i < math.min(times.length, 7); i++) {
      forecast.add(ForecastDay(
        date: DateTime.tryParse(times[i]) ?? DateTime.now(),
        code: (codes[i] as num).toInt(),
        maxTemp: (maxTemps[i] as num?)?.toDouble(),
        minTemp: (minTemps[i] as num?)?.toDouble(),
      ));
    }

    final icon = weatherIcon(currentCode);
    final display =
        '${shortLocationName(location)} ${formatTemp(temp)}° ${weatherText(currentCode)}';
    return WeatherInfo(
      location: location,
      display: display,
      icon: icon,
      latitude: latitude,
      longitude: longitude,
      temperature: temp,
      code: currentCode,
      updatedAt: DateTime.now(),
      forecast: forecast,
    );
  }
}

// ===================== 日历计算 =====================
class LunarCalendar {
  // 简化版农历计算 - 使用查表法
  static final List<int> lunarInfo = [
    0x04bd8,
    0x04ae0,
    0x0a570,
    0x054d5,
    0x0d260,
    0x0d950,
    0x16554,
    0x056a0,
    0x09ad0,
    0x055d2,
    0x04ae0,
    0x0a5b6,
    0x0a4d0,
    0x0d250,
    0x1d255,
    0x0b540,
    0x0d6a0,
    0x0ada2,
    0x095b0,
    0x14977,
    0x04970,
    0x0a4b0,
    0x0b4b5,
    0x06a50,
    0x06d40,
    0x1ab54,
    0x02b60,
    0x09570,
    0x052f2,
    0x04970,
    0x06566,
    0x0d4a0,
    0x0ea50,
    0x06e95,
    0x05ad0,
    0x02b60,
    0x186e3,
    0x092e0,
    0x1c8d7,
    0x0c950,
    0x0d4a0,
    0x1d8a6,
    0x0b550,
    0x056a0,
    0x1a5b4,
    0x025d0,
    0x092d0,
    0x0d2b2,
    0x0a950,
    0x0b557,
    0x06ca0,
    0x0b550,
    0x15355,
    0x04da0,
    0x0a5d0,
    0x14573,
    0x052d0,
    0x0a9a8,
    0x0e950,
    0x06aa0,
    0x0aea6,
    0x0ab50,
    0x04b60,
    0x0aae4,
    0x0a570,
    0x05260,
    0x0f263,
    0x0d950,
    0x05b57,
    0x056a0,
    0x096d0,
    0x04dd5,
    0x04ad0,
    0x0a4d0,
    0x0d4d4,
    0x0d250,
    0x0d558,
    0x0b540,
    0x0b5a0,
    0x195a6,
    0x095b0,
    0x049b0,
    0x0a974,
    0x0a4b0,
    0x0b27a,
    0x06a50,
    0x06d40,
    0x0af46,
    0x0ab60,
    0x09570,
    0x04af5,
    0x04970,
    0x064b0,
    0x074a3,
    0x0ea50,
    0x06b58,
    0x055c0,
    0x0ab60,
    0x096d5,
    0x092e0,
    0x0c960,
    0x0d954,
    0x0d4a0,
    0x0da50,
    0x07552,
    0x056a0,
    0x0abb7,
    0x025d0,
    0x092d0,
    0x0cab5,
    0x0a950,
    0x0b4a0,
    0x0baa4,
    0x0ad50,
    0x055d9,
    0x04ba0,
    0x0a5b0,
    0x15176,
    0x052b0,
    0x0a930,
    0x07954,
    0x06aa0,
    0x0ad50,
    0x05b52,
    0x04b60,
    0x0a6e6,
    0x0a4e0,
    0x0d260,
    0x0ea65,
    0x0d530,
    0x05aa0,
    0x076a3,
    0x096d0,
    0x04bd7,
    0x04ad0,
    0x0a4d0,
    0x1d0b6,
    0x0d250,
    0x0d520,
    0x0dd45,
    0x0b5a0,
    0x056d0,
    0x055b2,
    0x049b0,
    0x0a577,
    0x0a4b0,
    0x0aa50,
    0x1b255,
    0x06d20,
    0x0ada0,
  ];

  static final List<String> gan = [
    '甲',
    '乙',
    '丙',
    '丁',
    '戊',
    '己',
    '庚',
    '辛',
    '壬',
    '癸'
  ];
  static final List<String> zhi = [
    '子',
    '丑',
    '寅',
    '卯',
    '辰',
    '巳',
    '午',
    '未',
    '申',
    '酉',
    '戌',
    '亥'
  ];
  static final List<String> lunarMonths = [
    '正',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '冬',
    '腊'
  ];
  static final List<String> lunarDays = [
    '初一',
    '初二',
    '初三',
    '初四',
    '初五',
    '初六',
    '初七',
    '初八',
    '初九',
    '初十',
    '十一',
    '十二',
    '十三',
    '十四',
    '十五',
    '十六',
    '十七',
    '十八',
    '十九',
    '二十',
    '廿一',
    '廿二',
    '廿三',
    '廿四',
    '廿五',
    '廿六',
    '廿七',
    '廿八',
    '廿九',
    '三十',
  ];

  static int _lunarDaysInMonth(int year, int month, bool isLeap) {
    final leap = _leapMonth(year);
    if (isLeap && month != leap) return 0;
    if (month == leap && isLeap) {
      return (_lunarInfo(year) & 0x10000) != 0 ? 30 : 29;
    }
    return (_lunarInfo(year) & (0x10000 >> month)) != 0 ? 30 : 29;
  }

  static int _lunarInfo(int year) => lunarInfo[year - 1900];

  static int _leapMonth(int year) {
    final leap = _lunarInfo(year) & 0xf;
    return leap == 0 ? 0 : leap;
  }

  static int _lunarYearDays(int year) {
    int sum = 0;
    for (int i = 0x8000; i > 0x8; i >>= 1) {
      sum += (_lunarInfo(year) & i) != 0 ? 30 : 29;
    }
    return sum + _leapDays(year);
  }

  static int _leapDays(int year) {
    if (_leapMonth(year) == 0) return 0;
    return (_lunarInfo(year) & 0x10000) != 0 ? 30 : 29;
  }

  static Map<String, dynamic> solarToLunar(int year, int month, int day) {
    final baseDate = DateTime(1900, 1, 31);
    final targetDate = DateTime(year, month, day);
    int offset = targetDate.difference(baseDate).inDays;

    int lunarYear = 1900;
    int daysInYear = _lunarYearDays(lunarYear);
    while (offset >= daysInYear) {
      offset -= daysInYear;
      lunarYear++;
      daysInYear = _lunarYearDays(lunarYear);
    }

    int lunarMonth = 1;
    int leapMonth = _leapMonth(lunarYear);
    bool isLeap = false;
    int daysInMonth = _lunarDaysInMonth(lunarYear, lunarMonth, false);

    while (offset >= daysInMonth) {
      offset -= daysInMonth;
      lunarMonth++;
      if (lunarMonth == leapMonth + 1 && !isLeap) {
        lunarMonth--;
        isLeap = true;
        daysInMonth = _leapDays(lunarYear);
      } else {
        isLeap = false;
        daysInMonth = _lunarDaysInMonth(lunarYear, lunarMonth, false);
      }
    }

    int lunarDay = offset + 1;

    return {
      'year': lunarYear,
      'month': lunarMonth,
      'day': lunarDay,
      'isLeap': isLeap,
      'monthText': lunarMonths[lunarMonth - 1] + '月',
      'dayText': lunarDays[lunarDay - 1],
      'ganZhi': gan[(lunarYear - 4) % 10] + zhi[(lunarYear - 4) % 12] + '年',
    };
  }
}

// ===================== 节假日 =====================
final Map<String, String> solarHolidays = {
  '1-1': '元旦',
  '2-14': '情人节',
  '3-5': '学雷锋',
  '3-8': '妇女节',
  '3-12': '植树节',
  '4-1': '愚人节',
  '5-1': '劳动节',
  '5-4': '青年节',
  '6-1': '儿童节',
  '7-1': '建党节',
  '8-1': '建军节',
  '9-10': '教师节',
  '10-1': '国庆节',
  '10-24': '程序员节',
  '11-11': '光棍节',
  '12-24': '平安夜',
  '12-25': '圣诞节',
};

final Map<String, String> lunarHolidays = {
  '1-1': '春节',
  '1-15': '元宵节',
  '2-2': '龙抬头',
  '5-5': '端午节',
  '7-7': '七夕节',
  '7-15': '中元节',
  '8-15': '中秋节',
  '9-9': '重阳节',
  '12-8': '腊八节',
  '12-23': '小年',
  '12-30': '除夕',
};

final Set<String> legalHolidayNames = {
  '元旦',
  '春节',
  '清明',
  '劳动节',
  '端午节',
  '中秋节',
  '国庆',
};

// 调休上班日：本来是非工作日（周末），但调为工作日 -> 显示"班"
final Set<String> makeupWorkdays = {
  // 2025
  '2025-01-26', '2025-02-08', // 春节
  '2025-04-27', // 五一
  '2025-05-09', // 调休
  '2025-09-28', '2025-10-11', // 国庆
  // 2026
  '2026-01-04', // 元旦
  '2026-02-14', '2026-02-28', // 春节
  '2026-05-09', // 调休
  '2026-09-20', '2026-10-10', // 国庆
};

// 法定节假日额外放假（非周末的工作日放假）-> 显示"休"
final Set<String> extraRestDays = {
  // 2025 春节
  '2025-01-28', '2025-01-29', '2025-01-30', '2025-01-31',
  '2025-02-01', '2025-02-02', '2025-02-03', '2025-02-04',
  // 2025 清明
  '2025-04-04', '2025-04-05', '2025-04-06',
  // 2025 五一
  '2025-05-01', '2025-05-02', '2025-05-03', '2025-05-04', '2025-05-05',
  // 2025 端午
  '2025-05-31', '2025-06-01', '2025-06-02',
  // 2025 国庆
  '2025-10-01', '2025-10-02', '2025-10-03', '2025-10-04',
  '2025-10-05', '2025-10-06', '2025-10-07', '2025-10-08',
  // 2026 元旦
  '2026-01-01', '2026-01-02', '2026-01-03',
  // 2026 春节
  '2026-02-15', '2026-02-16', '2026-02-17', '2026-02-18', '2026-02-19',
  '2026-02-20', '2026-02-21', '2026-02-22', '2026-02-23',
  // 2026 清明
  '2026-04-04', '2026-04-05', '2026-04-06',
  // 2026 五一
  '2026-05-01', '2026-05-02', '2026-05-03', '2026-05-04', '2026-05-05',
  // 2026 端午
  '2026-06-19', '2026-06-20', '2026-06-21',
  // 2026 中秋
  '2026-09-25', '2026-09-26', '2026-09-27',
  // 2026 国庆
  '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04',
  '2026-10-05', '2026-10-06', '2026-10-07',
};

List<Reminder> importantRemindersForDate(
  List<Reminder> reminders,
  DateTime date,
) {
  final lunar = LunarCalendar.solarToLunar(date.year, date.month, date.day);
  return reminders.where((r) {
    if (!r.enabled) return false;
    if (r.type == 'once' && r.done) return false;
    switch (r.type) {
      case 'once':
        if (r.isLunar) {
          return r.year == lunar['year'] &&
              r.month == lunar['month'] &&
              r.day == lunar['day'];
        }
        return r.year == date.year &&
            r.month == date.month &&
            r.day == date.day;
      case 'daily':
        return true;
      case 'weekly':
        return r.weekday == date.weekday - 1;
      case 'monthly':
        return r.monthlyDay == date.day;
      case 'yearly':
        return r.yearlyMonth == date.month && r.yearlyDay == date.day;
      case 'lunar_yearly':
        return r.lunarMonth == lunar['month'] && r.lunarDay == lunar['day'];
      case 'lunar_monthly':
        return r.lunarDay == lunar['day'];
      default:
        return false;
    }
  }).toList();
}

// ===================== 应用入口 =====================
class StickyApp extends StatefulWidget {
  const StickyApp({super.key});

  @override
  State<StickyApp> createState() => _StickyAppState();
}

class _StickyAppState extends State<StickyApp> {
  String currentColor = 'yellow';
  String noteContent = '';
  bool showCalendar = true;
  bool showClock = false;
  String clockStyle = 'analog';
  WeatherInfo weatherInfo = const WeatherInfo();
  bool weatherRefreshing = false;
  List<Reminder> reminders = [];
  Map<String, List<dynamic>> schedules = {};
  Map<String, dynamic> extraData = {};
  Map<String, dynamic> syncMeta = {};
  SyncConfig syncConfig = const SyncConfig();
  bool syncBusy = false;
  int calYear = DateTime.now().year;
  int calMonth = DateTime.now().month;
  Timer? _reminderTimer;
  Timer? _weatherTimer;
  final Set<String> _triggeredToday = {};

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.sticky_android/alarm');

  @override
  void initState() {
    super.initState();
    _loadData();
    _startReminderTimer();
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _refreshWeather(),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _weatherTimer?.cancel();
    super.dispose();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkReminders();
    });
    // also check immediately on start
    Future.delayed(const Duration(seconds: 2), _checkReminders);
  }

  void _checkReminders() {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    for (final r in reminders) {
      if (!r.enabled) continue;
      if (r.type == 'once' && r.done) continue;
      if (r.hour != now.hour || r.minute != now.minute) continue;

      final triggerKey = '${r.type}_${r.displayLabel}_$todayKey';
      if (_triggeredToday.contains(triggerKey)) continue;

      bool shouldTrigger = false;
      switch (r.type) {
        case 'once':
          if (r.year == now.year && r.month == now.month && r.day == now.day) {
            shouldTrigger = true;
          }
          break;
        case 'daily':
          shouldTrigger = true;
          break;
        case 'weekly':
          if (r.weekday == now.weekday - 1) shouldTrigger = true;
          break;
        case 'monthly':
          if (r.monthlyDay == now.day) shouldTrigger = true;
          break;
        case 'yearly':
          if (r.yearlyMonth == now.month && r.yearlyDay == now.day) {
            shouldTrigger = true;
          }
          break;
        case 'lunar_yearly':
          final lunar =
              LunarCalendar.solarToLunar(now.year, now.month, now.day);
          if (r.lunarMonth == lunar['month'] && r.lunarDay == lunar['day']) {
            shouldTrigger = true;
          }
          break;
        case 'lunar_monthly':
          final lunar =
              LunarCalendar.solarToLunar(now.year, now.month, now.day);
          if (r.lunarDay == lunar['day']) shouldTrigger = true;
          break;
      }

      if (shouldTrigger) {
        _triggeredToday.add(triggerKey);
        _showReminderPopup(r);
      }
    }
  }

  void _showReminderPopup(Reminder r) {
    if (!mounted) return;
    final accentColor =
        r.isLunar ? const Color(0xFFD32F2F) : (theme['today'] as Color);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部彩色条
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 图标
              Icon(
                Icons.notifications_active,
                size: 40,
                color: accentColor,
              ),
              const SizedBox(height: 12),
              // 标题
              Text(
                r.isLunar ? '农历提醒' : '提醒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              // 时间
              Text(
                r.displayLabel,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              // 分隔线
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 12),
              // 消息
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  r.message,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // 按钮
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('知道了', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    await StorageService.init();
    final data = await StorageService.load();
    final loadedSyncConfig = await StorageService.loadSyncConfig();
    setState(() {
      noteContent = data['content'] ?? '';
      currentColor = data['color'] ?? 'yellow';
      showCalendar = data['show_calendar'] ?? true;
      showClock = data['show_clock'] ?? false;
      clockStyle = data['clock_style'] == 'digital' ? 'digital' : 'analog';
      if (data['weather'] is Map) {
        weatherInfo = WeatherInfo.fromJson(
          Map<String, dynamic>.from(data['weather'] as Map),
        );
      }
      if (data['reminders'] != null) {
        reminders = (data['reminders'] as List)
            .map((r) => Reminder.fromJson(r))
            .toList();
      }
      if (data['schedules'] != null) {
        schedules = parseSchedules(data['schedules']);
      }
      syncMeta = data['_sync_meta'] is Map
          ? Map<String, dynamic>.from(data['_sync_meta'] as Map)
          : {};
      extraData = extraTopLevelData(Map<String, dynamic>.from(data));
      syncConfig = loadedSyncConfig;
    });
    // 启动时重新设置原生闹钟（开机重启后需要）
    await _scheduleNativeAlarms();
    await _syncWidgetWeather();
    await _refreshWeather();
    if (syncConfig.autoSync && syncConfig.isReady) {
      Future.delayed(
        const Duration(seconds: 2),
        () => _syncNow(showSuccess: false),
      );
    }
  }

  void _touchSyncMeta() {
    syncMeta = {
      ...syncMeta,
      'updated_at': utcNowIso(),
      'device_id': syncConfig.deviceId,
    };
  }

  Map<String, dynamic> _currentData({bool touchSyncMeta = false}) {
    if (touchSyncMeta) _touchSyncMeta();
    return {
      ...extraData,
      'content': noteContent,
      'color': currentColor,
      'show_calendar': showCalendar,
      'show_clock': showClock,
      'clock_style': clockStyle,
      'weather': weatherInfo.toJson(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'schedules': schedules,
      '_sync_meta': syncMeta,
    };
  }

  Future<bool> _saveData({bool touchSyncMeta = true}) async {
    final data = _currentData(touchSyncMeta: touchSyncMeta);
    final result = await StorageService.save(data);
    await _scheduleNativeAlarms();
    await _syncWidgetWeather();
    return result;
  }

  void _applyLoadedData(Map<String, dynamic> data) {
    setState(() {
      noteContent = data['content'] ?? '';
      currentColor = data['color'] ?? 'yellow';
      showCalendar = data['show_calendar'] ?? true;
      showClock = data['show_clock'] ?? false;
      clockStyle = data['clock_style'] == 'digital' ? 'digital' : 'analog';
      weatherInfo = data['weather'] is Map
          ? WeatherInfo.fromJson(Map<String, dynamic>.from(data['weather']))
          : const WeatherInfo();
      reminders = (data['reminders'] as List? ?? [])
          .whereType<Map>()
          .map((r) => Reminder.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      schedules = parseSchedules(data['schedules']);
      syncMeta = data['_sync_meta'] is Map
          ? Map<String, dynamic>.from(data['_sync_meta'] as Map)
          : {};
      extraData = extraTopLevelData(data);
    });
  }

  Future<void> _syncWidgetWeather() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('syncWidgetWeather', {
        'temperature': weatherInfo.temperature,
        'code': weatherInfo.code,
      });
    } catch (e) {
      debugPrint('Sync widget weather error: $e');
    }
  }

  Future<void> _scheduleNativeAlarms() async {
    try {
      // 过滤出 Android 原生侧支持的提醒类型
      final supportedReminders = reminders
          .where((r) =>
              r.enabled &&
              !(r.type == 'once' && r.done) &&
              ['once', 'daily', 'weekly', 'monthly', 'yearly'].contains(r.type))
          .toList();
      final jsonData =
          jsonEncode(supportedReminders.map((r) => r.toJson()).toList());
      await _alarmChannel
          .invokeMethod('scheduleAlarms', {'reminders': jsonData});
    } catch (e) {
      debugPrint('Schedule alarm error: $e');
    }
  }

  Map<String, dynamic> get theme => defaultColors[currentColor]!;

  void _cycleColor() {
    final colors = defaultColors.keys.toList();
    final idx = colors.indexOf(currentColor);
    setState(() {
      currentColor = colors[(idx + 1) % colors.length];
    });
    _saveData();
  }

  Future<void> _refreshWeather({bool forceLocate = false}) async {
    if (weatherRefreshing) return;
    setState(() => weatherRefreshing = true);
    try {
      WeatherInfo next;
      if (!forceLocate &&
          weatherInfo.latitude != null &&
          weatherInfo.longitude != null) {
        next = await WeatherService.fetchByCoordinates(
          weatherInfo.latitude!,
          weatherInfo.longitude!,
          weatherInfo.location,
        );
      } else {
        final location = await _alarmChannel
            .invokeMethod<Map<dynamic, dynamic>>('getLastKnownLocation');
        if (location == null ||
            location['latitude'] == null ||
            location['longitude'] == null) {
          throw Exception('无法获取系统定位');
        }
        next = await WeatherService.fetchByCoordinates(
          (location['latitude'] as num).toDouble(),
          (location['longitude'] as num).toDouble(),
          (location['name']?.toString().trim().isNotEmpty ?? false)
              ? location['name'].toString()
              : '当前位置',
        );
      }
      if (!mounted) return;
      setState(() => weatherInfo = next);
      _saveData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        weatherInfo = weatherInfo.copyWith(
          display: weatherInfo.latitude == null ? '设置天气' : '天气查询失败',
          icon: '○',
        );
      });
    } finally {
      if (mounted) setState(() => weatherRefreshing = false);
    }
  }

  Future<bool> _setWeatherLocation(String location) async {
    try {
      final next = await WeatherService.fetchByLocationName(location);
      if (!mounted) return false;
      setState(() => weatherInfo = next);
      await _saveData();
      return true;
    } catch (e) {
      debugPrint('Weather location error: $e');
      return false;
    }
  }

  void _selectClockStyle(String style) {
    setState(() {
      if (style == 'off') {
        showClock = false;
      } else {
        clockStyle = style == 'digital' ? 'digital' : 'analog';
        showClock = true;
      }
    });
    _saveData();
  }

  Future<bool> _pinClockWidget(String style) async {
    try {
      final result = await _alarmChannel.invokeMethod<bool>(
        'pinClockWidget',
        {'style': style},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Pin clock widget error: $e');
      return false;
    }
  }

  Future<bool> _saveSyncConfig(SyncConfig config) async {
    final normalized = config.normalized();
    final ok = await StorageService.saveSyncConfig(normalized);
    if (ok && mounted) setState(() => syncConfig = normalized);
    return ok;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String> _uploadSnapshot(
    Map<String, dynamic> snapshot,
    SyncConfig config,
  ) async {
    final envelope = await WebDavSyncService.encryptPackage(
      snapshot,
      config.syncPassword,
      config.deviceId,
    );
    await WebDavSyncService.upload(config, envelope);
    return envelope['updated_at'].toString();
  }

  Future<void> _markSyncSuccess(SyncConfig config, String? updatedAt) async {
    final next = config.copyWith(
      enabled: true,
      lastSyncAt: utcNowIso(),
      lastSyncedUpdatedAt: updatedAt ?? '',
    );
    await _saveSyncConfig(next);
  }

  Future<String> _testConnectionForDialog(SyncConfig config) async {
    WebDavSyncService.validateConfig(config);
    final saved = await _saveSyncConfig(config);
    if (!saved) throw Exception('配置保存失败');
    await WebDavSyncService.testConnection(config);
    await _saveSyncConfig(config.copyWith(enabled: true));
    return 'WebDAV 连接测试成功，配置已保存';
  }

  Future<String> _syncForDialog(SyncConfig config) async {
    WebDavSyncService.validateConfig(config);
    final saved = await _saveSyncConfig(config);
    if (!saved) throw Exception('配置保存失败');

    final snapshot = _currentData(touchSyncMeta: false);
    await StorageService.save(snapshot);
    final remoteEnvelope = await WebDavSyncService.download(config);
    final localUpdated =
        (snapshot['_sync_meta'] as Map?)?['updated_at']?.toString() ?? '';

    if (remoteEnvelope == null) {
      final uploadedAt = await _uploadSnapshot(snapshot, config);
      await _markSyncSuccess(config, uploadedAt);
      return '云端无数据，已上传本机数据';
    }

    final remotePayload = await WebDavSyncService.decryptPackage(
      remoteEnvelope,
      config.syncPassword,
    );
    final remoteData = Map<String, dynamic>.from(remotePayload['data'] as Map);
    final remoteUpdated = remotePayload['updated_at']?.toString() ??
        ((remoteData['_sync_meta'] as Map?)?['updated_at']?.toString() ?? '');
    final localTime = parseSyncTime(localUpdated);
    final remoteTime = parseSyncTime(remoteUpdated);
    final lastTime = parseSyncTime(config.lastSyncedUpdatedAt);
    final localHasUserContent = syncDataHasUserContent(snapshot);
    final remoteHasUserContent = syncDataHasUserContent(remoteData);
    final localHasPlanningContent = syncDataHasPlanningContent(snapshot);
    final remoteHasPlanningContent = syncDataHasPlanningContent(remoteData);

    if (config.lastSyncedUpdatedAt.trim().isEmpty ||
        (!localHasUserContent && remoteHasUserContent) ||
        (!localHasPlanningContent && remoteHasPlanningContent)) {
      await StorageService.writeConflictBackup('local', snapshot);
      _applyLoadedData(remoteData);
      await _saveData(touchSyncMeta: false);
      await _markSyncSuccess(config, remoteUpdated);
      final summary = syncDataSummary(remoteData);
      if (config.lastSyncedUpdatedAt.trim().isEmpty) {
        return '首次同步已下载云端数据，本机旧数据已备份（$summary）';
      }
      return !localHasPlanningContent && remoteHasPlanningContent
          ? '本机暂无提醒/日程，已下载云端数据并备份本机旧数据（$summary）'
          : '本机暂无便签/提醒/日程，已下载云端数据并备份本机旧数据（$summary）';
    }

    if (localUpdated == remoteUpdated) {
      await _markSyncSuccess(config, localUpdated);
      return '本机和云端已经一致';
    }

    if (lastTime.millisecondsSinceEpoch > 0 &&
        localTime.isAfter(lastTime) &&
        remoteTime.isAfter(lastTime)) {
      await StorageService.writeConflictBackup('local', snapshot);
      await StorageService.writeConflictBackup('cloud', remoteData);
      return '检测到同步冲突，已备份本机和云端数据。请手动选择“上传本机”或“下载云端”。';
    }

    if (remoteTime.isAfter(localTime)) {
      await StorageService.writeConflictBackup('local', snapshot);
      _applyLoadedData(remoteData);
      await _saveData(touchSyncMeta: false);
      await _markSyncSuccess(config, remoteUpdated);
      return '云端数据较新，已下载云端数据并备份本机旧数据（${syncDataSummary(remoteData)}）';
    }

    final uploadedAt = await _uploadSnapshot(snapshot, config);
    await _markSyncSuccess(config, uploadedAt);
    return '本机数据较新，已上传到云端';
  }

  Future<String> _uploadForDialog(SyncConfig config) async {
    WebDavSyncService.validateConfig(config);
    final saved = await _saveSyncConfig(config);
    if (!saved) throw Exception('配置保存失败');

    final snapshot = _currentData(touchSyncMeta: true);
    await StorageService.save(snapshot);
    final remoteEnvelope = await WebDavSyncService.download(config);
    if (remoteEnvelope != null) {
      final remotePayload = await WebDavSyncService.decryptPackage(
        remoteEnvelope,
        config.syncPassword,
      );
      await StorageService.writeConflictBackup(
        'cloud',
        Map<String, dynamic>.from(remotePayload['data'] as Map),
      );
    }
    final uploadedAt = await _uploadSnapshot(snapshot, config);
    await _markSyncSuccess(config, uploadedAt);
    return '已上传本机数据到云端';
  }

  Future<String> _downloadForDialog(SyncConfig config) async {
    WebDavSyncService.validateConfig(config);
    final saved = await _saveSyncConfig(config);
    if (!saved) throw Exception('配置保存失败');

    final snapshot = _currentData(touchSyncMeta: false);
    final remoteEnvelope = await WebDavSyncService.download(config);
    if (remoteEnvelope == null) throw Exception('云端还没有同步文件');
    final remotePayload = await WebDavSyncService.decryptPackage(
      remoteEnvelope,
      config.syncPassword,
    );
    await StorageService.writeConflictBackup('local', snapshot);
    final remoteData = Map<String, dynamic>.from(remotePayload['data'] as Map);
    _applyLoadedData(remoteData);
    await _saveData(touchSyncMeta: false);
    await _markSyncSuccess(config, remotePayload['updated_at']?.toString());
    return '已下载云端数据，本机旧数据已备份（${syncDataSummary(remoteData)}）';
  }

  Future<void> _syncNow({bool showSuccess = true}) async {
    final config = syncConfig.normalized();
    if (!config.isReady) {
      if (showSuccess) _showSnack('请先配置 WebDAV 云同步');
      return;
    }
    setState(() => syncBusy = true);
    try {
      final snapshot = _currentData(touchSyncMeta: false);
      await StorageService.save(snapshot);
      final remoteEnvelope = await WebDavSyncService.download(config);
      final localUpdated =
          (snapshot['_sync_meta'] as Map?)?['updated_at']?.toString() ?? '';

      if (remoteEnvelope == null) {
        final uploadedAt = await _uploadSnapshot(snapshot, config);
        await _markSyncSuccess(config, uploadedAt);
        if (showSuccess) _showSnack('云端无数据，已上传本机数据');
        return;
      }

      final remotePayload = await WebDavSyncService.decryptPackage(
        remoteEnvelope,
        config.syncPassword,
      );
      final remoteData =
          Map<String, dynamic>.from(remotePayload['data'] as Map);
      final remoteUpdated = remotePayload['updated_at']?.toString() ??
          ((remoteData['_sync_meta'] as Map?)?['updated_at']?.toString() ?? '');
      final localTime = parseSyncTime(localUpdated);
      final remoteTime = parseSyncTime(remoteUpdated);
      final lastTime = parseSyncTime(config.lastSyncedUpdatedAt);
      final localHasUserContent = syncDataHasUserContent(snapshot);
      final remoteHasUserContent = syncDataHasUserContent(remoteData);
      final localHasPlanningContent = syncDataHasPlanningContent(snapshot);
      final remoteHasPlanningContent = syncDataHasPlanningContent(remoteData);

      if (config.lastSyncedUpdatedAt.trim().isEmpty ||
          (!localHasUserContent && remoteHasUserContent) ||
          (!localHasPlanningContent && remoteHasPlanningContent)) {
        await StorageService.writeConflictBackup('local', snapshot);
        _applyLoadedData(remoteData);
        await _saveData(touchSyncMeta: false);
        await _markSyncSuccess(config, remoteUpdated);
        if (showSuccess) {
          final summary = syncDataSummary(remoteData);
          if (config.lastSyncedUpdatedAt.trim().isEmpty) {
            _showSnack('首次同步已下载云端数据（$summary）');
          } else if (!localHasPlanningContent && remoteHasPlanningContent) {
            _showSnack('本机暂无提醒/日程，已下载云端数据（$summary）');
          } else {
            _showSnack('本机暂无便签/提醒/日程，已下载云端数据（$summary）');
          }
        }
        return;
      }

      if (localUpdated == remoteUpdated) {
        await _markSyncSuccess(config, localUpdated);
        if (showSuccess) _showSnack('本机和云端已经一致');
        return;
      }

      if (lastTime.millisecondsSinceEpoch > 0 &&
          localTime.isAfter(lastTime) &&
          remoteTime.isAfter(lastTime)) {
        if (!mounted) return;
        final downloadCloud = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('同步冲突'),
            content: const Text(
              '检测到本机和云端都修改过。\n\n选择“下载云端”会先备份本机；选择“上传本机”会先备份云端。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('上传本机'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('下载云端'),
              ),
            ],
          ),
        );
        if (downloadCloud == true) {
          await StorageService.writeConflictBackup('local', snapshot);
          _applyLoadedData(remoteData);
          await _saveData(touchSyncMeta: false);
          await _markSyncSuccess(config, remoteUpdated);
          _showSnack('已下载云端数据，本机旧数据已备份（${syncDataSummary(remoteData)}）');
        } else if (downloadCloud == false) {
          await StorageService.writeConflictBackup('cloud', remoteData);
          final uploadedAt = await _uploadSnapshot(snapshot, config);
          await _markSyncSuccess(config, uploadedAt);
          _showSnack('已上传本机数据，云端旧数据已备份');
        }
        return;
      }

      if (remoteTime.isAfter(localTime)) {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('云端数据较新'),
            content: const Text('是否先备份本机数据，然后下载云端数据覆盖本机？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('下载云端'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await StorageService.writeConflictBackup('local', snapshot);
          _applyLoadedData(remoteData);
          await _saveData(touchSyncMeta: false);
          await _markSyncSuccess(config, remoteUpdated);
          _showSnack('已下载云端数据，本机旧数据已备份（${syncDataSummary(remoteData)}）');
        }
        return;
      }

      final uploadedAt = await _uploadSnapshot(snapshot, config);
      await _markSyncSuccess(config, uploadedAt);
      if (showSuccess) _showSnack('本机数据较新，已上传到云端');
    } catch (e) {
      if (showSuccess) _showSnack('同步失败：$e');
    } finally {
      if (mounted) setState(() => syncBusy = false);
    }
  }

  Future<void> _showSyncDialog(BuildContext pageContext) async {
    final serverCtrl = TextEditingController(text: syncConfig.serverUrl);
    final userCtrl = TextEditingController(text: syncConfig.username);
    final passCtrl = TextEditingController(text: syncConfig.password);
    final remoteCtrl = TextEditingController(text: syncConfig.remotePath);
    final syncPassCtrl = TextEditingController(text: syncConfig.syncPassword);
    var enabled = syncConfig.enabled;
    var autoSync = syncConfig.autoSync;
    var dialogBusy = false;
    var statusText = syncConfig.isReady ? '当前：已配置' : '当前：未配置';

    SyncConfig gather() => syncConfig.copyWith(
          enabled: enabled,
          serverUrl: serverCtrl.text.trim(),
          username: userCtrl.text.trim(),
          password: passCtrl.text,
          remotePath: remoteCtrl.text.trim().isEmpty
              ? syncDefaultRemotePath
              : remoteCtrl.text.trim(),
          syncPassword: syncPassCtrl.text,
          autoSync: autoSync,
        );

    Future<void> runDialogOperation(
      void Function(void Function()) setDialogState,
      String runningText,
      Future<String> Function(SyncConfig) operation,
    ) async {
      FocusScope.of(pageContext).unfocus();
      setDialogState(() {
        dialogBusy = true;
        statusText = runningText;
      });
      try {
        final result = await operation(gather());
        statusText = result;
      } catch (e) {
        statusText = e.toString().replaceFirst('Exception: ', '');
      } finally {
        dialogBusy = false;
        if (mounted) {
          setDialogState(() {});
        }
      }
    }

    await showDialog<void>(
      context: pageContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('WebDAV 云同步'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: serverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 地址',
                    hintText: 'https://example.com/dav/',
                  ),
                ),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: '账号'),
                ),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '应用密码'),
                ),
                TextField(
                  controller: remoteCtrl,
                  decoration: const InputDecoration(
                    labelText: '远程文件',
                    hintText: syncDefaultRemotePath,
                  ),
                ),
                TextField(
                  controller: syncPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '同步密码'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用云同步'),
                  onChanged: (v) => setDialogState(() => enabled = v ?? false),
                ),
                CheckboxListTile(
                  value: autoSync,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启动时自动同步'),
                  onChanged: (v) => setDialogState(() => autoSync = v ?? false),
                ),
                const Text(
                  '同步密码用于跨设备解密，忘记后无法恢复云端数据。Android 配置保存在应用私有目录。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusText.contains('失败') ||
                              statusText.contains('请填写')
                          ? Colors.red
                          : Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (syncBusy || dialogBusy)
                        ? null
                        : () async {
                            setDialogState(() {
                              dialogBusy = true;
                              statusText = '正在保存配置...';
                            });
                            try {
                              final next = gather();
                              final ok = await _saveSyncConfig(next);
                              statusText = ok ? '配置已保存' : '保存失败';
                            } catch (e) {
                              statusText = e
                                  .toString()
                                  .replaceFirst('Exception: ', '保存失败：');
                            } finally {
                              dialogBusy = false;
                              if (ctx.mounted) setDialogState(() {});
                            }
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存配置'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (syncBusy || dialogBusy)
                        ? null
                        : () async {
                            await runDialogOperation(
                              setDialogState,
                              '正在测试连接...',
                              _testConnectionForDialog,
                            );
                          },
                    icon: const Icon(Icons.network_check),
                    label: const Text('测试连接'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (syncBusy || dialogBusy)
                        ? null
                        : () async {
                            await runDialogOperation(
                              setDialogState,
                              '正在同步...',
                              _syncForDialog,
                            );
                          },
                    icon: const Icon(Icons.cloud_sync),
                    label: Text((syncBusy || dialogBusy) ? '处理中' : '立即同步'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (syncBusy || dialogBusy)
                            ? null
                            : () async {
                                await runDialogOperation(
                                  setDialogState,
                                  '正在上传本机数据...',
                                  _uploadForDialog,
                                );
                              },
                        icon: const Icon(Icons.upload),
                        label: const Text('上传本机'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (syncBusy || dialogBusy)
                            ? null
                            : () async {
                                await runDialogOperation(
                                  setDialogState,
                                  '正在下载云端数据...',
                                  _downloadForDialog,
                                );
                              },
                        icon: const Icon(Icons.download),
                        label: const Text('下载云端'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  (syncBusy || dialogBusy) ? null : () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return MaterialApp(
      title: '雨然日历',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: t['today'],
          brightness:
              currentColor == 'dark' ? Brightness.dark : Brightness.light,
        ),
      ),
      home: HomeScreen(
        noteContent: noteContent,
        onContentChanged: (value) {
          setState(() => noteContent = value);
          _saveData();
        },
        currentColor: currentColor,
        theme: t,
        showCalendar: showCalendar,
        showClock: showClock,
        clockStyle: clockStyle,
        weatherInfo: weatherInfo,
        weatherRefreshing: weatherRefreshing,
        onToggleCalendar: () {
          setState(() => showCalendar = !showCalendar);
          _saveData();
        },
        onCycleColor: _cycleColor,
        onRefreshWeather: () => _refreshWeather(forceLocate: true),
        onSetWeatherLocation: _setWeatherLocation,
        onSelectClockStyle: _selectClockStyle,
        onPinClockWidget: _pinClockWidget,
        onOpenSyncSettings: _showSyncDialog,
        syncBusy: syncBusy,
        syncReady: syncConfig.isReady,
        calYear: calYear,
        calMonth: calMonth,
        onChangeMonth: (delta) {
          setState(() {
            calMonth += delta;
            if (calMonth > 12) {
              calMonth = 1;
              calYear++;
            } else if (calMonth < 1) {
              calMonth = 12;
              calYear--;
            }
          });
        },
        reminders: reminders,
        schedules: schedules,
        onAddReminder: (r) {
          setState(() => reminders.add(r));
          _saveData();
        },
        onUpdateReminder: (idx, r) {
          if (idx < 0 || idx >= reminders.length) return;
          setState(() => reminders[idx] = r);
          _saveData();
        },
        onDeleteReminder: (idx) {
          if (idx < 0 || idx >= reminders.length) return;
          setState(() => reminders.removeAt(idx));
          _saveData();
        },
        onAddSchedule: (dateKey, item) {
          setState(() {
            schedules.putIfAbsent(dateKey, () => []);
            schedules[dateKey]!.add(item);
          });
          _saveData();
        },
        onUpdateSchedule: (dateKey, index, item) {
          final items = schedules[dateKey];
          if (items == null || index < 0 || index >= items.length) return;
          setState(() => items[index] = item);
          _saveData();
        },
        onDeleteSchedule: (dateKey, index) {
          final items = schedules[dateKey];
          if (items == null || index < 0 || index >= items.length) return;
          setState(() {
            items.removeAt(index);
            if (items.isEmpty) schedules.remove(dateKey);
          });
          _saveData();
        },
      ),
    );
  }
}

// ===================== 主页面 =====================
class HomeScreen extends StatefulWidget {
  final String noteContent;
  final ValueChanged<String> onContentChanged;
  final String currentColor;
  final Map<String, dynamic> theme;
  final bool showCalendar;
  final bool showClock;
  final String clockStyle;
  final WeatherInfo weatherInfo;
  final bool weatherRefreshing;
  final VoidCallback onToggleCalendar;
  final VoidCallback onCycleColor;
  final Future<void> Function() onRefreshWeather;
  final Future<bool> Function(String) onSetWeatherLocation;
  final ValueChanged<String> onSelectClockStyle;
  final Future<bool> Function(String) onPinClockWidget;
  final Future<void> Function(BuildContext) onOpenSyncSettings;
  final bool syncBusy;
  final bool syncReady;
  final int calYear;
  final int calMonth;
  final ValueChanged<int> onChangeMonth;
  final List<Reminder> reminders;
  final Map<String, List<dynamic>> schedules;
  final ValueChanged<Reminder> onAddReminder;
  final void Function(int, Reminder) onUpdateReminder;
  final ValueChanged<int> onDeleteReminder;
  final void Function(String, dynamic) onAddSchedule;
  final void Function(String, int, dynamic) onUpdateSchedule;
  final void Function(String, int) onDeleteSchedule;

  const HomeScreen({
    super.key,
    required this.noteContent,
    required this.onContentChanged,
    required this.currentColor,
    required this.theme,
    required this.showCalendar,
    required this.showClock,
    required this.clockStyle,
    required this.weatherInfo,
    required this.weatherRefreshing,
    required this.onToggleCalendar,
    required this.onCycleColor,
    required this.onRefreshWeather,
    required this.onSetWeatherLocation,
    required this.onSelectClockStyle,
    required this.onPinClockWidget,
    required this.onOpenSyncSettings,
    required this.syncBusy,
    required this.syncReady,
    required this.calYear,
    required this.calMonth,
    required this.onChangeMonth,
    required this.reminders,
    required this.schedules,
    required this.onAddReminder,
    required this.onUpdateReminder,
    required this.onDeleteReminder,
    required this.onAddSchedule,
    required this.onUpdateSchedule,
    required this.onDeleteSchedule,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.noteContent);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.noteContent) {
      _controller.text = widget.noteContent;
    }
  }

  Future<bool> _confirmAction(
    BuildContext context,
    String title,
    String content,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _toolbarButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double extent = 30,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: extent, minHeight: extent),
      color: color,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }

  Widget _reminderListButton(Color fg, double extent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _toolbarButton(
          tooltip: '提醒列表',
          icon: Icons.notifications_outlined,
          color: fg,
          extent: extent,
          onPressed: () => _showRemindersList(context),
        ),
        if (widget.reminders.isNotEmpty)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                widget.reminders.length > 99
                    ? '99+'
                    : widget.reminders.length.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _scheduleListButton(Color fg, double extent) {
    final count = scheduleItemCount(widget.schedules);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _toolbarButton(
          tooltip: '日程列表',
          icon: Icons.event_note_outlined,
          color: fg,
          extent: extent,
          onPressed: () => _showSchedulesList(context),
        ),
        if (count > 0)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(Color bg, Color fg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final extent = compact ? 28.0 : 30.0;
          final tools = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolbarButton(
                tooltip: '日历',
                icon: Icons.calendar_month,
                color: fg,
                extent: extent,
                onPressed: widget.onToggleCalendar,
              ),
              _toolbarButton(
                tooltip: '颜色',
                icon: Icons.palette_outlined,
                color: fg,
                extent: extent,
                onPressed: widget.onCycleColor,
              ),
              _toolbarButton(
                tooltip: '时钟',
                icon: Icons.schedule,
                color: fg,
                extent: extent,
                onPressed: () => _showClockMenu(context),
              ),
              _toolbarButton(
                tooltip: '云同步',
                icon: widget.syncBusy ? Icons.cloud_sync : Icons.cloud_outlined,
                color: widget.syncReady
                    ? const Color(0xFF1976D2)
                    : fg.withAlpha(170),
                extent: compact ? 27 : 28,
                onPressed: widget.syncBusy
                    ? null
                    : () => widget.onOpenSyncSettings(context),
              ),
              _toolbarButton(
                tooltip: '添加提醒',
                icon: Icons.add_alert_outlined,
                color: fg,
                extent: extent,
                onPressed: () => _showAddReminderDialog(context),
              ),
              _scheduleListButton(fg, extent),
              _reminderListButton(fg, extent),
            ],
          );

          return Row(
            children: [
              Image.asset('assets/images/logo.png', width: 24, height: 24),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  '雨然日历',
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: tools,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final bg = t['bg'] as Color;
    final fg = t['fg'] as Color;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(bg, fg),

            _buildInfoWeatherBar(context, bg, fg),

            if (widget.showClock)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: ClockPanel(
                  style: widget.clockStyle,
                  accent: t['today'] as Color,
                ),
              ),

            // 日历区域
            if (widget.showCalendar)
              CalendarWidget(
                year: widget.calYear,
                month: widget.calMonth,
                theme: t,
                reminders: widget.reminders,
                schedules: widget.schedules,
                onChangeMonth: widget.onChangeMonth,
                onDateTap: (y, m, d) => _handleDateTap(context, y, m, d),
              ),

            // 文本编辑区
            Expanded(
              child: Container(
                color: bg,
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(color: fg, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '写点什么...',
                    hintStyle: TextStyle(color: fg.withAlpha(100)),
                  ),
                  onChanged: widget.onContentChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoWeatherBar(BuildContext context, Color bg, Color fg) {
    final today = DateTime.now();
    final accent = widget.theme['today'] as Color;
    final iconColor = weatherIconColor(widget.weatherInfo.icon, widget.theme);
    final info =
        '第${dayOfYear(today)}天 · 第${isoWeekNumber(today)}周 · ${weekdayText(today)} · ${getConstellation(today.month, today.day)}';

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              info,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _showWeatherForecast(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.weatherRefreshing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  else
                    Text(
                      widget.weatherInfo.icon,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Text(
                      widget.weatherInfo.display,
                      style: TextStyle(color: fg, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: const Color(0xFF1976D2),
            onPressed: () => _showWeatherLocationDialog(context),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  void _handleDateTap(BuildContext context, int year, int month, int day) {
    _showDateMenu(context, year, month, day);
  }

  void _showWeatherForecast(BuildContext context) {
    final forecast = widget.weatherInfo.forecast;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    widget.weatherInfo.location,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onRefreshWeather();
                    },
                    icon: const Icon(Icons.my_location),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showWeatherLocationDialog(context);
                    },
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              if (forecast.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无天气预报，请先设置位置或稍后重试'),
                )
              else
                ...forecast.map(
                  (day) => ListTile(
                    dense: true,
                    leading: Text(weatherIcon(day.code),
                        style: const TextStyle(fontSize: 22)),
                    title: Text(
                      '${day.date.month}月${day.date.day}日 ${weekdayText(day.date)}',
                    ),
                    subtitle: Text(weatherText(day.code)),
                    trailing: Text(
                      '${formatTemp(day.minTemp)}° / ${formatTemp(day.maxTemp)}°',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWeatherLocationDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: widget.weatherInfo.location == '当前位置'
          ? ''
          : widget.weatherInfo.location,
    );
    var saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('天气地址'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: '城市或地址',
                  hintText: '例如：深圳市',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: const TextStyle(color: Color(0xFFD32F2F))),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await widget.onRefreshWeather();
                    },
              child: const Text('自动定位'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final value = ctrl.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() => error = '请输入地址');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final ok = await widget.onSetWeatherLocation(value);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = '天气查询失败，请换个地址再试';
                        });
                      }
                    },
              child: Text(saving ? '查询中' : '确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClockMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('圆形时钟'),
              trailing: widget.showClock && widget.clockStyle == 'analog'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.onSelectClockStyle('analog');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('数字时钟'),
              trailing: widget.showClock && widget.clockStyle == 'digital'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.onSelectClockStyle('digital');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('关闭时钟'),
              onTap: () {
                widget.onSelectClockStyle('off');
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('添加数字时钟到桌面'),
              subtitle: const Text('适合华为桌面找不到小组件入口时使用'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await widget.onPinClockWidget('digital');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '已请求添加数字时钟到桌面，请按系统提示确认'
                        : '当前桌面不支持自动添加，请在桌面小组件列表中查找雨然日历'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('添加圆形时钟到桌面'),
              subtitle: const Text('添加为手机桌面小组件'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await widget.onPinClockWidget('analog');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '已请求添加圆形时钟到桌面，请按系统提示确认'
                        : '当前桌面不支持自动添加，请在桌面小组件列表中查找雨然日历'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedulesList(BuildContext context) {
    final entries = <({String dateKey, int index, dynamic item})>[];
    widget.schedules.forEach((dateKey, items) {
      for (var index = 0; index < items.length; index++) {
        entries.add((dateKey: dateKey, index: index, item: items[index]));
      }
    });
    final now = DateTime.now();
    entries.sort((a, b) {
      final aTime = scheduleSortTime(a.dateKey, a.item);
      final bTime = scheduleSortTime(b.dateKey, b.item);
      final aBucket = scheduleDone(a.item)
          ? 2
          : aTime.isBefore(now)
              ? 1
              : 0;
      final bBucket = scheduleDone(b.item)
          ? 2
          : bTime.isBefore(now)
              ? 1
              : 0;
      if (aBucket != bBucket) return aBucket.compareTo(bBucket);
      return aBucket == 0 ? aTime.compareTo(bTime) : bTime.compareTo(aTime);
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('日程列表 (${entries.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: entries.isEmpty
              ? const Text('暂无日程', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final done = scheduleDone(entry.item);
                    return ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: done,
                        onChanged: (value) {
                          widget.onUpdateSchedule(
                            entry.dateKey,
                            entry.index,
                            scheduleWithDone(entry.item, value ?? false),
                          );
                          Navigator.pop(ctx);
                          _showSchedulesList(context);
                        },
                      ),
                      title: Text(
                        scheduleDisplayText(entry.item),
                        style: TextStyle(
                          fontSize: 13,
                          color: done ? Colors.grey : null,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(scheduleDateLabel(entry.dateKey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              final date = DateTime.tryParse(entry.dateKey);
                              if (date == null) return;
                              Navigator.pop(ctx);
                              _showAddScheduleDialog(
                                context,
                                date.year,
                                date.month,
                                date.day,
                                editIndex: entry.index,
                                initialItem: entry.item,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () async {
                              final ok = await _confirmAction(
                                context,
                                '删除日程',
                                scheduleDisplayText(entry.item),
                              );
                              if (!ok || !ctx.mounted) return;
                              widget.onDeleteSchedule(
                                entry.dateKey,
                                entry.index,
                              );
                              Navigator.pop(ctx);
                              _showSchedulesList(context);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        final date = DateTime.tryParse(entry.dateKey);
                        if (date == null) return;
                        Navigator.pop(ctx);
                        _showDateMenu(context, date.year, date.month, date.day);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final today = DateTime.now();
              Navigator.pop(ctx);
              _showAddScheduleDialog(
                context,
                today.year,
                today.month,
                today.day,
              );
            },
            child: const Text('添加今日日程'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showDateMenu(BuildContext context, int year, int month, int day) {
    final dateStr = '$year年$month月$day日';
    final dateKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final date = DateTime(year, month, day);
    final reminders = importantRemindersForDate(widget.reminders, date);
    final daySchedules = widget.schedules[dateKey] ?? [];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(dateStr,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('添加提醒'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddReminderDialog(context,
                      prefillYear: year, prefillMonth: month, prefillDay: day);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('添加日程'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddScheduleDialog(context, year, month, day);
                },
              ),
              if (reminders.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('已有提醒',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                ...reminders.map((r) {
                  final reminderIndex = widget.reminders.indexOf(r);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      r.enabled
                          ? Icons.notifications_outlined
                          : Icons.notifications_off_outlined,
                      color: r.enabled ? const Color(0xFFE53935) : Colors.grey,
                    ),
                    title: Text(
                      r.message.isEmpty ? '未命名提醒' : r.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: r.enabled ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Text(r.displayLabel),
                    trailing: reminderIndex < 0
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (action) async {
                              Navigator.pop(ctx);
                              if (action == 'toggle') {
                                widget.onUpdateReminder(
                                  reminderIndex,
                                  r.copyWith(
                                    enabled: !r.enabled,
                                    clearLastTriggered: true,
                                  ),
                                );
                              } else if (action == 'edit') {
                                _showAddReminderDialog(
                                  context,
                                  editIndex: reminderIndex,
                                  initialReminder: r,
                                );
                              } else if (action == 'delete') {
                                final ok = await _confirmAction(
                                  context,
                                  '删除提醒',
                                  r.message.isEmpty
                                      ? r.displayLabel
                                      : r.message,
                                );
                                if (ok) widget.onDeleteReminder(reminderIndex);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('编辑'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(r.enabled ? '停用' : '启用'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                            ],
                          ),
                  );
                }),
              ],
              if (daySchedules.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('已有日程',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                ...daySchedules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final done = scheduleDone(item);
                  return ListTile(
                    dense: true,
                    leading: Checkbox(
                      value: done,
                      onChanged: (value) {
                        widget.onUpdateSchedule(
                          dateKey,
                          index,
                          scheduleWithDone(item, value ?? false),
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                    title: Text(
                      scheduleDisplayText(item),
                      style: TextStyle(
                        fontSize: 14,
                        color: done ? Colors.grey : null,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        Navigator.pop(ctx);
                        if (action == 'edit') {
                          _showAddScheduleDialog(
                            context,
                            year,
                            month,
                            day,
                            editIndex: index,
                            initialItem: item,
                          );
                        } else if (action == 'delete') {
                          final ok = await _confirmAction(
                            context,
                            '删除日程',
                            scheduleDisplayText(item),
                          );
                          if (ok) widget.onDeleteSchedule(dateKey, index);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddScheduleDialog(
    BuildContext context,
    int year,
    int month,
    int day, {
    int? editIndex,
    dynamic initialItem,
  }) {
    final now = DateTime.now();
    final isEditing = editIndex != null;
    final parts = parseScheduleParts(initialItem, now);
    final contentCtrl =
        TextEditingController(text: isEditing ? parts.content : '');
    String selectedHour =
        isEditing ? parts.hour : now.hour.toString().padLeft(2, '0');
    String selectedMinute =
        isEditing ? parts.minute : now.minute.toString().padLeft(2, '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑日程' : '$year年$month月$day日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedHour,
                      decoration: const InputDecoration(labelText: '时'),
                      items: List.generate(
                              24, (i) => i.toString().padLeft(2, '0'))
                          .map((h) =>
                              DropdownMenuItem(value: h, child: Text('$h时')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedHour = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedMinute,
                      decoration: const InputDecoration(labelText: '分'),
                      items: List.generate(
                              60, (i) => i.toString().padLeft(2, '0'))
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text('$m分')))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedMinute = v!),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(labelText: '日程内容'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                final content = contentCtrl.text.trim();
                if (content.isEmpty) return;
                final h = selectedHour;
                final m = selectedMinute;
                final item =
                    (h.isNotEmpty && m.isNotEmpty) ? '$h:$m $content' : content;
                final dateKey =
                    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                if (isEditing) {
                  widget.onUpdateSchedule(
                    dateKey,
                    editIndex,
                    scheduleWithText(initialItem, item),
                  );
                } else {
                  widget.onAddSchedule(dateKey, item);
                }
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? '保存' : '确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderDialog(
    BuildContext context, {
    int? prefillYear,
    int? prefillMonth,
    int? prefillDay,
    int? editIndex,
    Reminder? initialReminder,
  }) {
    final now = DateTime.now();
    final typeItems = ['单次', '每天', '每周', '每月', '每年', '每年农历', '每月农历'];
    const typeLabels = {
      'once': '单次',
      'daily': '每天',
      'weekly': '每周',
      'monthly': '每月',
      'yearly': '每年',
      'lunar_yearly': '每年农历',
      'lunar_monthly': '每月农历',
    };
    final isEditing = editIndex != null && initialReminder != null;
    String selectedType = typeLabels[initialReminder?.type] ?? '单次';
    final msgCtrl = TextEditingController(text: initialReminder?.message ?? '');
    final initialYear = initialReminder?.year ?? prefillYear ?? now.year;
    final initialMonth = initialReminder?.month ?? prefillMonth ?? now.month;
    final initialDay = initialReminder?.day ?? prefillDay ?? now.day;
    String selectedYear = initialYear.toString();
    String selectedMonth = initialMonth.toString();
    String selectedDay = initialDay.toString();
    String selectedHour =
        (initialReminder?.hour ?? now.hour).toString().padLeft(2, '0');
    String selectedMinute =
        (initialReminder?.minute ?? now.minute).toString().padLeft(2, '0');

    bool isLunar = initialReminder?.isLunar ?? false;

    // 每周
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final initialWeekday =
        (initialReminder?.weekday ?? (now.weekday - 1)).clamp(0, 6);
    String selectedWeekday = weekdays[initialWeekday];

    // 每月
    String selectedMonthDay =
        (initialReminder?.monthlyDay ?? initialReminder?.day ?? initialDay)
            .toString();

    // 每年
    String selectedYearMonth =
        (initialReminder?.yearlyMonth ?? initialReminder?.month ?? initialMonth)
            .toString();
    String selectedYearDay =
        (initialReminder?.yearlyDay ?? initialReminder?.day ?? initialDay)
            .toString();

    // 农历
    int prefillLunarMonth = now.month;
    int prefillLunarDay = now.day;
    if (initialReminder?.lunarMonth != null) {
      prefillLunarMonth = initialReminder!.lunarMonth!;
    }
    if (initialReminder?.lunarDay != null) {
      prefillLunarDay = initialReminder!.lunarDay!;
    } else if (initialReminder?.isLunar == true &&
        initialReminder?.month != null) {
      prefillLunarMonth = initialReminder!.month!;
      prefillLunarDay = initialReminder.day ?? prefillLunarDay;
    } else if (prefillYear != null &&
        prefillMonth != null &&
        prefillDay != null) {
      final lunar =
          LunarCalendar.solarToLunar(prefillYear, prefillMonth, prefillDay);
      prefillLunarMonth = lunar['month'];
      prefillLunarDay = lunar['day'];
    }
    String selectedLunarMonth = prefillLunarMonth.toString();
    String selectedLunarDay = prefillLunarDay.toString();
    String selectedLunarMonthlyDay = prefillLunarDay.toString();
    final firstYear = math.min(now.year - 10, initialYear);
    final yearCount = math.max(21, (initialYear - now.year).abs() + 11).toInt();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget buildDynamicInput() {
            switch (selectedType) {
              case '单次':
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedYear,
                            decoration: const InputDecoration(labelText: '年'),
                            items: List.generate(yearCount,
                                    (i) => (firstYear + i).toString())
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text('$y年')))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedYear = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedMonth,
                            decoration: const InputDecoration(labelText: '月'),
                            items: List.generate(12, (i) => (i + 1).toString())
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text('$m月')))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedMonth = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDay,
                            decoration: const InputDecoration(labelText: '日'),
                            items: List.generate(31, (i) => (i + 1).toString())
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text('$d日')))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedDay = v!),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text('农历'),
                      value: isLunar,
                      onChanged: (v) => setDialogState(() => isLunar = v!),
                    ),
                  ],
                );
              case '每周':
                return DropdownButtonFormField<String>(
                  value: selectedWeekday,
                  decoration: const InputDecoration(labelText: '选择星期'),
                  items: weekdays
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedWeekday = v!),
                );
              case '每月':
                return DropdownButtonFormField<String>(
                  value: selectedMonthDay,
                  decoration: const InputDecoration(labelText: '选择日期'),
                  items: List.generate(31, (i) => (i + 1).toString())
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text('${d}号')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMonthDay = v!),
                );
              case '每年':
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedYearMonth,
                        decoration: const InputDecoration(labelText: '月'),
                        items: List.generate(12, (i) => (i + 1).toString())
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('${d}月')))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedYearMonth = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedYearDay,
                        decoration: const InputDecoration(labelText: '日'),
                        items: List.generate(31, (i) => (i + 1).toString())
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('${d}日')))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedYearDay = v!),
                      ),
                    ),
                  ],
                );
              case '每年农历':
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedLunarMonth,
                        decoration: const InputDecoration(labelText: '农历月'),
                        items: List.generate(12, (i) => (i + 1).toString())
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('${d}月')))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedLunarMonth = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedLunarDay,
                        decoration: const InputDecoration(labelText: '农历日'),
                        items: List.generate(30, (i) => (i + 1).toString())
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('${d}日')))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedLunarDay = v!),
                      ),
                    ),
                  ],
                );
              case '每月农历':
                return DropdownButtonFormField<String>(
                  value: selectedLunarMonthlyDay,
                  decoration: const InputDecoration(labelText: '农历日'),
                  items: List.generate(30, (i) => (i + 1).toString())
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text('${d}日')))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedLunarMonthlyDay = v!),
                );
              default:
                return const SizedBox.shrink();
            }
          }

          return AlertDialog(
            title: Text(isEditing ? '编辑提醒' : '添加提醒'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: '类型'),
                    items: typeItems
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  buildDynamicInput(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedHour,
                          decoration: const InputDecoration(labelText: '时'),
                          items: List.generate(
                                  24, (i) => i.toString().padLeft(2, '0'))
                              .map((h) => DropdownMenuItem(
                                  value: h, child: Text('$h时')))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedHour = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMinute,
                          decoration: const InputDecoration(labelText: '分'),
                          items: List.generate(
                                  60, (i) => i.toString().padLeft(2, '0'))
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text('$m分')))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedMinute = v!),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(labelText: '提醒内容'),
                    maxLines: 3,
                    minLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  final msg = msgCtrl.text.trim();
                  if (msg.isEmpty) return;
                  final h = int.tryParse(selectedHour) ?? 0;
                  final m = int.tryParse(selectedMinute) ?? 0;

                  Reminder? reminder;
                  switch (selectedType) {
                    case '单次':
                      reminder = Reminder(
                        type: 'once',
                        message: msg,
                        hour: h,
                        minute: m,
                        year: int.tryParse(selectedYear),
                        month: int.tryParse(selectedMonth),
                        day: int.tryParse(selectedDay),
                        isLunar: isLunar,
                      );
                    case '每天':
                      reminder = Reminder(
                          type: 'daily', message: msg, hour: h, minute: m);
                    case '每周':
                      reminder = Reminder(
                        type: 'weekly',
                        message: msg,
                        hour: h,
                        minute: m,
                        weekday: weekdays.indexOf(selectedWeekday),
                      );
                    case '每月':
                      reminder = Reminder(
                        type: 'monthly',
                        message: msg,
                        hour: h,
                        minute: m,
                        monthlyDay: int.tryParse(selectedMonthDay),
                      );
                    case '每年':
                      reminder = Reminder(
                        type: 'yearly',
                        message: msg,
                        hour: h,
                        minute: m,
                        yearlyMonth: int.tryParse(selectedYearMonth),
                        yearlyDay: int.tryParse(selectedYearDay),
                      );
                    case '每年农历':
                      reminder = Reminder(
                        type: 'lunar_yearly',
                        message: msg,
                        hour: h,
                        minute: m,
                        lunarMonth: int.tryParse(selectedLunarMonth),
                        lunarDay: int.tryParse(selectedLunarDay),
                        isLunar: true,
                      );
                    case '每月农历':
                      reminder = Reminder(
                        type: 'lunar_monthly',
                        message: msg,
                        hour: h,
                        minute: m,
                        lunarDay: int.tryParse(selectedLunarMonthlyDay),
                        isLunar: true,
                      );
                  }

                  if (reminder != null) {
                    if (isEditing) {
                      final original = initialReminder;
                      widget.onUpdateReminder(
                        editIndex,
                        reminder.copyWith(
                          enabled: original.enabled,
                          done: false,
                          extra: original.extra,
                          clearLastTriggered: true,
                        ),
                      );
                    } else {
                      widget.onAddReminder(reminder);
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: Text(isEditing ? '保存' : '确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRemindersList(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('提醒列表 (${widget.reminders.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: widget.reminders.isEmpty
              ? const Text('暂无提醒', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.reminders.length,
                  itemBuilder: (context, i) {
                    final r = widget.reminders[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        r.enabled
                            ? Icons.notifications_outlined
                            : Icons.notifications_off_outlined,
                        color:
                            r.enabled ? const Color(0xFFE53935) : Colors.grey,
                      ),
                      title: Text(r.displayLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: r.enabled ? null : Colors.grey,
                          )),
                      subtitle: Text(
                        r.message.isEmpty ? '未命名提醒' : r.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: r.enabled ? null : Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAddReminderDialog(
                                context,
                                editIndex: i,
                                initialReminder: r,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: r.enabled ? '停用' : '启用',
                            icon: Icon(r.enabled
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline),
                            onPressed: () {
                              widget.onUpdateReminder(
                                i,
                                r.copyWith(
                                  enabled: !r.enabled,
                                  clearLastTriggered: true,
                                ),
                              );
                              Navigator.pop(ctx);
                              _showRemindersList(context);
                            },
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () async {
                              final ok = await _confirmAction(
                                context,
                                '删除提醒',
                                r.message.isEmpty ? r.displayLabel : r.message,
                              );
                              if (!ok || !ctx.mounted) return;
                              widget.onDeleteReminder(i);
                              Navigator.pop(ctx);
                              _showRemindersList(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}

// ===================== 时钟组件 =====================
class ClockPanel extends StatefulWidget {
  final String style;
  final Color accent;

  const ClockPanel({
    super.key,
    required this.style,
    required this.accent,
  });

  @override
  State<ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends State<ClockPanel> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == 'digital') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xDD121C27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF263241)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_now.year}.${_now.month.toString().padLeft(2, '0')}.${_now.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: Center(
        child: CustomPaint(
          size: const Size(184, 184),
          painter: AnalogClockPainter(_now, widget.accent),
        ),
      ),
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  final DateTime now;
  final Color accent;

  AnalogClockPainter(this.now, this.accent);

  Offset _point(Offset center, double degrees, double length) {
    final angle = (degrees - 90) * math.pi / 180;
    return Offset(
      center.dx + math.cos(angle) * length,
      center.dy + math.sin(angle) * length,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final shadow = Paint()
      ..color = Colors.black.withAlpha(70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final face = Paint()..color = const Color(0xEE121C27);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF2A3A4C);

    canvas.drawCircle(center.translate(2, 4), radius, shadow);
    canvas.drawCircle(center, radius, face);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(
      center,
      radius - 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF1E2C3A),
    );

    for (var i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      final outer = radius - 10;
      final inner = outer - (isHour ? 10 : 5);
      canvas.drawLine(
        _point(center, i * 6, inner),
        _point(center, i * 6, outer),
        Paint()
          ..color = isHour ? const Color(0xFFD8E2EA) : const Color(0xFF526273)
          ..strokeWidth = isHour ? 3 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final item in const [
      ['12', 0.0],
      ['3', 90.0],
      ['6', 180.0],
      ['9', 270.0],
    ]) {
      final label = item[0] as String;
      final degrees = item[1] as double;
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF8EA0AF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final p = _point(center, degrees, radius - 32);
      textPainter.paint(
        canvas,
        p - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    final hourDegrees = ((now.hour % 12) + now.minute / 60) * 30;
    final minuteDegrees = (now.minute + now.second / 60) * 6;
    final secondDegrees = now.second * 6.0;

    canvas.drawLine(
      center,
      _point(center, hourDegrees, radius * 0.42),
      Paint()
        ..color = const Color(0xFFF5F8FB)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      _point(center, minuteDegrees, radius * 0.62),
      Paint()
        ..color = const Color(0xFFC9D4DF)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      _point(center, secondDegrees + 180, radius * 0.14),
      _point(center, secondDegrees, radius * 0.72),
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 86, height: 48),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      badge,
      Paint()..color = const Color(0xFF172332),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF314256),
    );

    final dateText =
        '${now.month.toString().padLeft(2, '0')}月${now.day.toString().padLeft(2, '0')}日';
    textPainter.text = TextSpan(
      text: dateText,
      style: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(center.dx - textPainter.width / 2, center.dy - 18));

    textPainter.text = TextSpan(
      text: weekdayText(now),
      style: TextStyle(
        color: accent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(center.dx - textPainter.width / 2, center.dy + 4));

    canvas.drawCircle(center, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) =>
      oldDelegate.now.second != now.second || oldDelegate.accent != accent;
}

// ===================== 日历组件 =====================
class CalendarWidget extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, dynamic> theme;
  final List<Reminder> reminders;
  final Map<String, List<dynamic>> schedules;
  final ValueChanged<int> onChangeMonth;
  final void Function(int, int, int) onDateTap;

  const CalendarWidget({
    super.key,
    required this.year,
    required this.month,
    required this.theme,
    required this.reminders,
    required this.schedules,
    required this.onChangeMonth,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = theme['bg'] as Color;
    final fg = theme['fg'] as Color;
    final todayColor = theme['today'] as Color;
    final holidayColor = theme['holiday'] as Color;
    final weekendColor = theme['weekend'] as Color;
    final today = DateTime.now();

    final firstDay = DateTime(year, month, 1);
    final weekday = firstDay.weekday % 7; // 0=周日
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // 年月导航
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: fg),
                onPressed: () => onChangeMonth(-1),
              ),
              Expanded(
                child: Text(
                  '$year年$month月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: fg, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: fg),
                onPressed: () => onChangeMonth(1),
              ),
            ],
          ),

          // 星期标题
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六'].map((d) {
              final isWeekend = d == '日' || d == '六';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      color: isWeekend ? holidayColor : fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 4),

          // 日期网格
          ..._buildWeekRows(
            weekday,
            daysInMonth,
            today,
            bg,
            fg,
            todayColor,
            holidayColor,
            weekendColor,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekRows(
    int startWeekday,
    int daysInMonth,
    DateTime today,
    Color bg,
    Color fg,
    Color todayColor,
    Color holidayColor,
    Color weekendColor,
  ) {
    final rows = <Widget>[];
    var currentRow = <Widget>[];
    var dayCount = 0;

    // 空白
    for (int i = 0; i < startWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dt = DateTime(year, month, day);
      final isToday = dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
      final isWeekend =
          dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;

      final lunar = LunarCalendar.solarToLunar(year, month, day);
      final lunarKey = '${lunar['month']}-${lunar['day']}';
      final solarKey = '$month-$day';
      final holidayText = lunarHolidays[lunarKey] ?? solarHolidays[solarKey];
      final isLegal = holidayText != null &&
          legalHolidayNames.any((n) => holidayText.contains(n));

      final dateKey =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final hasSchedule =
          schedules.containsKey(dateKey) && schedules[dateKey]!.isNotEmpty;
      final dateReminders = importantRemindersForDate(reminders, dt);
      final hasReminder = dateReminders.isNotEmpty;

      // 调休/休息标记
      String? dayTag;
      if (makeupWorkdays.contains(dateKey)) {
        dayTag = '班';
      } else if (isWeekend || extraRestDays.contains(dateKey)) {
        dayTag = '休';
      }

      final cellBg = isToday
          ? todayColor
          : isWeekend
              ? weekendColor
              : bg;
      final dayFg = isToday ? Colors.white : fg;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: () => onDateTap(year, month, day),
            child: Container(
              height: 54,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cellBg,
                borderRadius: BorderRadius.circular(6),
                border: isToday
                    ? Border.all(color: todayColor.withAlpha(180), width: 2)
                    : null,
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: todayColor.withAlpha(60),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  if (hasReminder)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isToday ? Colors.white : cellBg,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                color: dayFg,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (dayTag != null)
                              Container(
                                margin: const EdgeInsets.only(left: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 0),
                                decoration: BoxDecoration(
                                  color: dayTag == '班'
                                      ? const Color(0xFFD32F2F)
                                      : const Color(0xFF2E7D32),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  dayTag,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (holidayText != null)
                          Text(
                            holidayText,
                            style: TextStyle(
                              color: isLegal
                                  ? const Color(0xFFC62828)
                                  : holidayColor,
                              fontSize: 9,
                              fontWeight:
                                  isLegal ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (hasSchedule)
                          Text(
                            '·日程',
                            style: TextStyle(
                                color: todayColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          )
                        else
                          Text(
                            lunar['day'] == 1
                                ? lunar['monthText']
                                : lunar['dayText'],
                            style: TextStyle(
                                color: fg.withAlpha(180), fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      dayCount++;
      if ((startWeekday + dayCount) % 7 == 0) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: currentRow));
    }

    return rows;
  }
}
