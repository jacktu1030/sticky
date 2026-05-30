import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.year,
    this.month,
    this.day,
    this.weekday,
    this.monthlyDay,
    this.yearlyMonth,
    this.yearlyDay,
    this.lunarMonth,
    this.lunarDay,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'hour': hour,
        'minute': minute,
        'last_triggered': lastTriggered,
        'is_lunar': isLunar,
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

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        type: json['type'],
        message: json['message'],
        hour: json['hour'],
        minute: json['minute'],
        lastTriggered: json['last_triggered'],
        isLunar: json['is_lunar'] ?? false,
        year: json['year'],
        month: json['month'],
        day: json['day'],
        weekday: json['weekday'],
        monthlyDay: json['monthly_day'],
        yearlyMonth: json['yearly_month'],
        yearlyDay: json['yearly_day'],
        lunarMonth: json['lunar_month'],
        lunarDay: json['lunar_day'],
      );

  String get displayLabel {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    switch (type) {
      case 'once':
        if (isLunar) {
          return '农历 $year年$month月$day日 $timeStr';
        }
        return '$year年$month月$day日 $timeStr';
      case 'daily':
        return '每天 $timeStr';
      case 'weekly':
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final index = (weekday ?? 0).clamp(0, weekdays.length - 1);
        return '每周${weekdays[index]} $timeStr';
      case 'monthly':
        return '每月${monthlyDay}号 $timeStr';
      case 'yearly':
        return '每年$yearlyMonth月$yearlyDay日 $timeStr';
      case 'lunar_yearly':
        return '每年农历$lunarMonth月$lunarDay日 $timeStr';
      case 'lunar_monthly':
        return '每月农历$lunarDay日 $timeStr';
      default:
        return '$type $timeStr';
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
        code: json['code'] ?? 0,
        minTemp: (json['min_temp'] as num?)?.toDouble(),
        maxTemp: (json['max_temp'] as num?)?.toDouble(),
      );
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
        location: json['location'] ?? '天气加载中',
        display: json['display'] ?? '天气加载中',
        icon: json['icon'] ?? '○',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        code: json['code'],
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
class StorageService {
  static late File _dataFile;
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
    _dataFile = File('$path/sticky_notes.json');
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
  Map<String, List<String>> schedules = {};
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
        schedules = Map<String, List<String>>.from(
          (data['schedules'] as Map).map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v)),
          ),
        );
      }
    });
    // 启动时重新设置原生闹钟（开机重启后需要）
    await _scheduleNativeAlarms();
    await _syncWidgetWeather();
    await _refreshWeather();
  }

  Future<bool> _saveData() async {
    final data = {
      'content': noteContent,
      'color': currentColor,
      'show_calendar': showCalendar,
      'show_clock': showClock,
      'clock_style': clockStyle,
      'weather': weatherInfo.toJson(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'schedules': schedules,
    };
    final result = await StorageService.save(data);
    await _scheduleNativeAlarms();
    await _syncWidgetWeather();
    return result;
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
        onDeleteReminder: (idx) {
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
  final int calYear;
  final int calMonth;
  final ValueChanged<int> onChangeMonth;
  final List<Reminder> reminders;
  final Map<String, List<String>> schedules;
  final ValueChanged<Reminder> onAddReminder;
  final ValueChanged<int> onDeleteReminder;
  final void Function(String, String) onAddSchedule;

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
    required this.calYear,
    required this.calMonth,
    required this.onChangeMonth,
    required this.reminders,
    required this.schedules,
    required this.onAddReminder,
    required this.onDeleteReminder,
    required this.onAddSchedule,
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
            // 标题栏
            Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text('雨然日历',
                      style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onToggleCalendar,
                    child:
                        Text('日历', style: TextStyle(color: fg, fontSize: 14)),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: widget.onCycleColor,
                    child:
                        Text('颜色', style: TextStyle(color: fg, fontSize: 14)),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showClockMenu(context),
                    child:
                        Text('时钟', style: TextStyle(color: fg, fontSize: 14)),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showAddReminderDialog(context),
                    child: Text('[+提醒]',
                        style: TextStyle(color: fg, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showRemindersList(context),
                    child: Text('提醒(${widget.reminders.length})',
                        style: TextStyle(color: fg, fontSize: 14)),
                  ),
                ],
              ),
            ),

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
    final date = DateTime(year, month, day);
    final hits = importantRemindersForDate(widget.reminders, date);
    if (hits.isNotEmpty) {
      _showDateReminders(context, date, hits);
    } else {
      _showDateMenu(context, year, month, day);
    }
  }

  void _showDateReminders(
      BuildContext context, DateTime date, List<Reminder> reminders) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${date.year}年${date.month}月${date.day}日'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reminders
                .map(
                  (r) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      border: Border.all(color: const Color(0xFFF3B7B7)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.displayLabel,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(r.message, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDateMenu(context, date.year, date.month, date.day);
            },
            child: const Text('添加/日程'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
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

  void _showDateMenu(BuildContext context, int year, int month, int day) {
    final dateStr = '$year年$month月$day日';
    final dateKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
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
            if (widget.schedules.containsKey(dateKey) &&
                widget.schedules[dateKey]!.isNotEmpty) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('已有日程',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              ...widget.schedules[dateKey]!.map((item) => ListTile(
                    dense: true,
                    title: Text(item, style: const TextStyle(fontSize: 14)),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog(
      BuildContext context, int year, int month, int day) {
    final contentCtrl = TextEditingController();
    final now = DateTime.now();
    String selectedHour = now.hour.toString().padLeft(2, '0');
    String selectedMinute = now.minute.toString().padLeft(2, '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('$year年$month月$day日'),
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
                widget.onAddSchedule(dateKey, item);
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context,
      {int? prefillYear, int? prefillMonth, int? prefillDay}) {
    final now = DateTime.now();
    final typeItems = ['单次', '每天', '每周', '每月', '每年', '每年农历', '每月农历'];
    String selectedType = '单次';
    final msgCtrl = TextEditingController();
    String selectedYear = (prefillYear ?? now.year).toString();
    String selectedMonth = (prefillMonth ?? now.month).toString();
    String selectedDay = (prefillDay ?? now.day).toString();
    String selectedHour = now.hour.toString().padLeft(2, '0');
    String selectedMinute = now.minute.toString().padLeft(2, '0');

    bool isLunar = false;

    // 每周
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    String selectedWeekday = weekdays[now.weekday - 1];

    // 每月
    String selectedMonthDay = (prefillDay ?? now.day).toString();

    // 每年
    String selectedYearMonth = (prefillMonth ?? now.month).toString();
    String selectedYearDay = (prefillDay ?? now.day).toString();

    // 农历
    int prefillLunarMonth = now.month;
    int prefillLunarDay = now.day;
    if (prefillYear != null && prefillMonth != null && prefillDay != null) {
      final lunar =
          LunarCalendar.solarToLunar(prefillYear, prefillMonth, prefillDay);
      prefillLunarMonth = lunar['month'];
      prefillLunarDay = lunar['day'];
    }
    String selectedLunarMonth = prefillLunarMonth.toString();
    String selectedLunarDay = prefillLunarDay.toString();
    String selectedLunarMonthlyDay = prefillLunarDay.toString();

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
                            items: List.generate(
                                    11, (i) => (now.year - 5 + i).toString())
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
            title: const Text('添加提醒'),
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
                    widget.onAddReminder(reminder);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('确定'),
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
                      title: Text(r.displayLabel,
                          style: const TextStyle(fontSize: 13)),
                      subtitle:
                          Text(r.message, style: const TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () {
                          widget.onDeleteReminder(i);
                          Navigator.pop(ctx);
                          _showRemindersList(context);
                        },
                        child: const Text('删除',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
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
  final Map<String, List<String>> schedules;
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
                      if (hasReminder)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 3, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isToday ? Colors.white : cellBg,
                              width: 1,
                            ),
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
                        color: isLegal ? const Color(0xFFC62828) : holidayColor,
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
                      lunar['day'] == 1 ? lunar['monthText'] : lunar['dayText'],
                      style: TextStyle(color: fg.withAlpha(180), fontSize: 9),
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
