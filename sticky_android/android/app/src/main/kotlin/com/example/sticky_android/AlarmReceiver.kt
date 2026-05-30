package com.example.sticky_android

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {
    private val CHANNEL_ID = "sticky_note_reminders"

    override fun onReceive(context: Context, intent: Intent) {
        val message = intent.getStringExtra("message") ?: "提醒"
        val requestCode = intent.getIntExtra("request_code", 0)
        val type = intent.getStringExtra("type")

        // 点亮屏幕
        wakeUpScreen(context)

        // 播放系统闹钟声音 + 振动
        playAlarmSoundAndVibrate(context)

        // 发送横幅弹窗通知
        sendHeadsUpNotification(context, message, requestCode)

        // daily/weekly/monthly/yearly 重新设置下一次
        if (type != null && type != "once") {
            rescheduleAlarm(context, intent, type)
        }
    }

    private fun wakeUpScreen(context: Context) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "雨然日历:AlarmWakeLock"
            )
            wakeLock.acquire(10 * 1000L)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playAlarmSoundAndVibrate(context: Context) {
        // 播放默认闹钟声音
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val ringtone = RingtoneManager.getRingtone(context, uri)
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 振动
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            } else {
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(android.os.VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), -1))
            } else {
                vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun sendHeadsUpNotification(context: Context, message: String, requestCode: Int) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 点击打开应用
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, requestCode, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 全屏意图（锁屏时弹出）
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, requestCode, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 默认闹钟声音
        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("雨然日历")
            .setContentText(message)
            .setSubText("提醒时间到了")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setLights(android.graphics.Color.RED, 500, 500)
            .setSound(alarmSound)
            // 横幅弹窗（heads-up）
            .setTicker("雨然日历提醒: $message")
            .build()

        notificationManager.notify(requestCode, notification)
    }

    private fun rescheduleAlarm(context: Context, intent: Intent, type: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val hour = intent.getIntExtra("hour", 0)
        val minute = intent.getIntExtra("minute", 0)
        val message = intent.getStringExtra("message") ?: ""
        val requestCode = intent.getIntExtra("request_code", 0)
        val interval = intent.getLongExtra("interval", 0)

        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
        }

        when (type) {
            "daily" -> {
                cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            "weekly" -> {
                cal.add(java.util.Calendar.DAY_OF_YEAR, 7)
            }
            "monthly" -> {
                val day = intent.getIntExtra("day", 1)
                cal.set(java.util.Calendar.DAY_OF_MONTH, day)
                cal.add(java.util.Calendar.MONTH, 1)
            }
            "yearly" -> {
                val month = intent.getIntExtra("month", 0)
                val day = intent.getIntExtra("day", 1)
                cal.set(java.util.Calendar.MONTH, month)
                cal.set(java.util.Calendar.DAY_OF_MONTH, day)
                cal.add(java.util.Calendar.YEAR, 1)
            }
        }

        val newIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("message", message)
            putExtra("request_code", requestCode)
            putExtra("type", type)
            putExtra("hour", hour)
            putExtra("minute", minute)
            if (interval > 0) putExtra("interval", interval)
            if (type == "monthly" || type == "yearly") {
                putExtra("day", intent.getIntExtra("day", 1))
            }
            if (type == "yearly") {
                putExtra("month", intent.getIntExtra("month", 0))
            }
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, newIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = PendingIntent.getActivity(
            context, requestCode,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmClockInfo = AlarmManager.AlarmClockInfo(cal.timeInMillis, showIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
    }
}
