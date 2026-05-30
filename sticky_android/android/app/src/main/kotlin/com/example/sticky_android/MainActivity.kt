package com.example.sticky_android

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.sticky_android/alarm"
    private val CHANNEL_ID = "sticky_note_reminders"
    private val CHANNEL_NAME = "雨然日历提醒"
    private val NOTIF_PERMISSION_CODE = 1001
    private val LOCATION_PERMISSION_CODE = 1002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        checkAndRequestPermissions()
        // 启动保活前台服务
        startKeepAliveService()
    }

    private fun startKeepAliveService() {
        val serviceIntent = Intent(this, AlarmKeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun checkAndRequestPermissions() {
        // Android 13+ 请求通知权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    NOTIF_PERMISSION_CODE
                )
            }
        }

        val locationPermissions = arrayOf(
            android.Manifest.permission.ACCESS_COARSE_LOCATION,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        )
        val hasLocationPermission = locationPermissions.any {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
        if (!hasLocationPermission) {
            ActivityCompat.requestPermissions(this, locationPermissions, LOCATION_PERMISSION_CODE)
        }

        // Android 12+ 检查精确闹钟权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }

        // 请求忽略电池优化
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "scheduleAlarms" -> {
                    val remindersJson = call.argument<String>("reminders")
                    if (remindersJson != null) {
                        scheduleAlarms(remindersJson)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "reminders is null", null)
                    }
                }
                "cancelAllAlarms" -> {
                    cancelAllAlarms()
                    result.success(true)
                }
                "getAppFilesDir" -> {
                    result.success(filesDir.absolutePath)
                }
                "checkAlarmPermission" -> {
                    result.success(checkAlarmPermission())
                }
                "getLastKnownLocation" -> {
                    result.success(getLastKnownLocationMap())
                }
                "pinClockWidget" -> {
                    val style = call.argument<String>("style") ?: "digital"
                    result.success(requestPinClockWidget(style))
                }
                "syncWidgetWeather" -> {
                    val temperature = call.argument<Number>("temperature")?.toDouble()
                    val code = call.argument<Number>("code")?.toInt()
                    syncWidgetWeather(temperature, code)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun syncWidgetWeather(temperature: Double?, code: Int?) {
        WidgetWeatherStore.save(this, temperature, code)
        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
        val widgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(this, DigitalClockWidgetProvider::class.java)
        )
        if (widgetIds.isNotEmpty()) {
            val intent = Intent(this, DigitalClockWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            }
            sendBroadcast(intent)
        }
    }

    private fun requestPinClockWidget(style: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
            return false
        }

        val provider = ComponentName(
            this,
            if (style == "analog") AnalogClockWidgetProvider::class.java else DigitalClockWidgetProvider::class.java
        )
        return appWidgetManager.requestPinAppWidget(provider, null, null)
    }

    private fun getLastKnownLocationMap(): Map<String, Any?>? {
        val hasPermission =
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    android.Manifest.permission.ACCESS_COARSE_LOCATION,
                    android.Manifest.permission.ACCESS_FINE_LOCATION
                ),
                LOCATION_PERMISSION_CODE
            )
            return null
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )

        var best: Location? = null
        for (provider in providers) {
            try {
                val location = locationManager.getLastKnownLocation(provider) ?: continue
                if (best == null || location.time > best!!.time) {
                    best = location
                }
            } catch (_: Exception) {
            }
        }

        val location = best ?: return null
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "name" to resolveLocationName(location.latitude, location.longitude)
        )
    }

    private fun resolveLocationName(latitude: Double, longitude: Double): String {
        return try {
            val geocoder = Geocoder(this, Locale.CHINA)
            @Suppress("DEPRECATION")
            val address = geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
            listOfNotNull(address?.locality, address?.subAdminArea, address?.adminArea)
                .firstOrNull { it.isNotBlank() } ?: "当前位置"
        } catch (_: Exception) {
            "当前位置"
        }
    }

    private fun checkAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }
        return true
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "雨然日历提醒通知"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setSound(
                    android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM),
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun scheduleAlarms(remindersJson: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val reminders = JSONArray(remindersJson)

        cancelAllAlarms()

        for (i in 0 until reminders.length()) {
            val r = reminders.getJSONObject(i)
            val type = r.getString("type")
            val message = r.getString("message")
            val hour = r.getInt("hour")
            val minute = r.getInt("minute")

            when (type) {
                "once" -> {
                    val year = r.optInt("year", 0)
                    val month = r.optInt("month", 0)
                    val day = r.optInt("day", 0)
                    if (year > 0 && month > 0 && day > 0) {
                        val cal = java.util.Calendar.getInstance().apply {
                            set(year, month - 1, day, hour, minute, 0)
                        }
                        if (cal.timeInMillis > System.currentTimeMillis()) {
                            setAlarmClock(alarmManager, cal.timeInMillis, message, i)
                        }
                    }
                }
                "daily" -> {
                    val cal = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, hour)
                        set(java.util.Calendar.MINUTE, minute)
                        set(java.util.Calendar.SECOND, 0)
                        if (timeInMillis <= System.currentTimeMillis()) {
                            add(java.util.Calendar.DAY_OF_YEAR, 1)
                        }
                    }
                    setAlarmClock(alarmManager, cal.timeInMillis, message, i, type, AlarmManager.INTERVAL_DAY)
                }
                "weekly" -> {
                    val weekday = r.optInt("weekday", 0)
                    val cal = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, hour)
                        set(java.util.Calendar.MINUTE, minute)
                        set(java.util.Calendar.SECOND, 0)
                        val targetDay = if (weekday == 6) java.util.Calendar.SATURDAY else weekday + 2
                        while (get(java.util.Calendar.DAY_OF_WEEK) != targetDay || timeInMillis <= System.currentTimeMillis()) {
                            add(java.util.Calendar.DAY_OF_YEAR, 1)
                        }
                    }
                    setAlarmClock(alarmManager, cal.timeInMillis, message, i, type, AlarmManager.INTERVAL_DAY * 7)
                }
                "monthly" -> {
                    val monthlyDay = r.optInt("monthly_day", 1)
                    val cal = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.DAY_OF_MONTH, monthlyDay)
                        set(java.util.Calendar.HOUR_OF_DAY, hour)
                        set(java.util.Calendar.MINUTE, minute)
                        set(java.util.Calendar.SECOND, 0)
                        if (timeInMillis <= System.currentTimeMillis()) {
                            add(java.util.Calendar.MONTH, 1)
                        }
                    }
                    setAlarmClock(alarmManager, cal.timeInMillis, message, i, type)
                }
                "yearly" -> {
                    val yearlyMonth = r.optInt("yearly_month", 1)
                    val yearlyDay = r.optInt("yearly_day", 1)
                    val cal = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.MONTH, yearlyMonth - 1)
                        set(java.util.Calendar.DAY_OF_MONTH, yearlyDay)
                        set(java.util.Calendar.HOUR_OF_DAY, hour)
                        set(java.util.Calendar.MINUTE, minute)
                        set(java.util.Calendar.SECOND, 0)
                        if (timeInMillis <= System.currentTimeMillis()) {
                            add(java.util.Calendar.YEAR, 1)
                        }
                    }
                    setAlarmClock(alarmManager, cal.timeInMillis, message, i, type)
                }
            }
        }
    }

    private fun setAlarmClock(alarmManager: AlarmManager, timeInMillis: Long, message: String, requestCode: Int, type: String? = null, interval: Long = 0) {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("message", message)
            putExtra("request_code", requestCode)
            if (type != null) putExtra("type", type)
            if (interval > 0) putExtra("interval", interval)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // 使用 setAlarmClock：Android 最可靠的闹钟方式，系统会像原生闹钟一样保护它
        val showIntent = PendingIntent.getActivity(
            this, requestCode,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmClockInfo = AlarmManager.AlarmClockInfo(timeInMillis, showIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
    }

    private fun cancelAllAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..999) {
            val intent = Intent(this, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this, i, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }
}
