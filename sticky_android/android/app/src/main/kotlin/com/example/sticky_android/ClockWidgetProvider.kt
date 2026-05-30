package com.example.sticky_android

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

class DigitalClockWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (ClockWidgetUpdater.shouldRefreshDigital(intent.action)) {
            ClockWidgetUpdater.updateAll(context, ClockWidgetStyle.DIGITAL)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        ClockWidgetUpdater.update(context, appWidgetManager, appWidgetIds, ClockWidgetStyle.DIGITAL)
    }

    override fun onEnabled(context: Context) {
        ClockWidgetUpdater.updateAll(context, ClockWidgetStyle.DIGITAL)
    }

    override fun onDisabled(context: Context) {
        ClockWidgetUpdater.cancelTick(context, ClockWidgetStyle.DIGITAL)
    }
}

class AnalogClockWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (ClockWidgetUpdater.shouldRefreshAnalog(intent.action)) {
            ClockWidgetUpdater.updateAll(context, ClockWidgetStyle.ANALOG)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        ClockWidgetUpdater.update(context, appWidgetManager, appWidgetIds, ClockWidgetStyle.ANALOG)
    }

    override fun onEnabled(context: Context) {
        ClockWidgetUpdater.scheduleNextTick(context, ClockWidgetStyle.ANALOG)
    }

    override fun onDisabled(context: Context) {
        ClockWidgetUpdater.cancelTick(context, ClockWidgetStyle.ANALOG)
    }
}

private enum class ClockWidgetStyle(
    val layoutId: Int,
    val receiverClass: Class<out AppWidgetProvider>,
    val tickAction: String,
    val requestCode: Int
) {
    DIGITAL(
        R.layout.yuran_clock_widget_digital,
        DigitalClockWidgetProvider::class.java,
        "com.example.sticky_android.action.DIGITAL_CLOCK_TICK",
        46101
    ),
    ANALOG(
        R.layout.yuran_clock_widget_analog,
        AnalogClockWidgetProvider::class.java,
        "com.example.sticky_android.action.ANALOG_CLOCK_TICK",
        46102
    )
}

private object ClockWidgetUpdater {
    private const val ONE_MINUTE_MS = 60_000L

    fun shouldRefreshDigital(action: String?): Boolean = action in setOf(
        ClockWidgetStyle.DIGITAL.tickAction,
        Intent.ACTION_TIME_CHANGED,
        Intent.ACTION_TIMEZONE_CHANGED,
        Intent.ACTION_DATE_CHANGED,
        Intent.ACTION_BOOT_COMPLETED,
        Intent.ACTION_MY_PACKAGE_REPLACED
    )

    fun shouldRefreshAnalog(action: String?): Boolean = action in setOf(
        ClockWidgetStyle.ANALOG.tickAction,
        Intent.ACTION_TIME_CHANGED,
        Intent.ACTION_TIMEZONE_CHANGED,
        Intent.ACTION_DATE_CHANGED,
        Intent.ACTION_BOOT_COMPLETED,
        Intent.ACTION_MY_PACKAGE_REPLACED
    )

    fun updateAll(context: Context, style: ClockWidgetStyle) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, style.receiverClass))
        update(context, appWidgetManager, widgetIds, style)
    }

    fun update(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        style: ClockWidgetStyle
    ) {
        if (appWidgetIds.isEmpty()) {
            cancelTick(context, style)
            return
        }

        val openAppIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            style.requestCode,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = Calendar.getInstance(Locale.CHINA)
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, style.layoutId)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            if (style == ClockWidgetStyle.ANALOG) {
                views.setImageViewBitmap(R.id.widget_clock_image, ClockBitmapRenderer.drawAnalog(calendar))
            } else {
                val weather = WidgetWeatherStore.load(context)
                views.setTextViewText(
                    R.id.widget_time,
                    SimpleDateFormat("HH:mm", Locale.CHINA).format(calendar.time)
                )
                views.setTextViewText(
                    R.id.widget_date,
                    "${SimpleDateFormat("M月d日", Locale.CHINA).format(calendar.time)} ${weekdayName(calendar)}"
                )
                views.setTextViewText(R.id.widget_day_info, "第${calendar.get(Calendar.DAY_OF_YEAR)}天")
                views.setTextViewText(R.id.widget_week_info, "第${isoWeek(calendar)}周")
                views.setImageViewResource(R.id.widget_weather_icon, weather.iconResId)
                views.setTextViewText(R.id.widget_weather_temp, weather.temperatureText)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        scheduleNextTick(context, style)
    }

    fun scheduleNextTick(context: Context, style: ClockWidgetStyle) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, style.receiverClass))
        if (widgetIds.isEmpty()) {
            cancelTick(context, style)
            return
        }

        val now = System.currentTimeMillis()
        val nextMinute = now + (ONE_MINUTE_MS - now % ONE_MINUTE_MS) + 350L
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = tickPendingIntent(context, style, PendingIntent.FLAG_UPDATE_CURRENT) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC, nextMinute, pendingIntent)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, nextMinute, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC, nextMinute, pendingIntent)
        }
    }

    fun cancelTick(context: Context, style: ClockWidgetStyle) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = tickPendingIntent(context, style, PendingIntent.FLAG_NO_CREATE)
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun tickPendingIntent(
        context: Context,
        style: ClockWidgetStyle,
        extraFlag: Int
    ): PendingIntent? {
        val intent = Intent(context, style.receiverClass).apply {
            action = style.tickAction
        }
        return PendingIntent.getBroadcast(
            context,
            style.requestCode,
            intent,
            extraFlag or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun isoWeek(calendar: Calendar): Int {
        val clone = calendar.clone() as Calendar
        clone.firstDayOfWeek = Calendar.MONDAY
        clone.minimalDaysInFirstWeek = 4
        return clone.get(Calendar.WEEK_OF_YEAR)
    }

    private fun weekdayName(calendar: Calendar): String {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "周一"
            Calendar.TUESDAY -> "周二"
            Calendar.WEDNESDAY -> "周三"
            Calendar.THURSDAY -> "周四"
            Calendar.FRIDAY -> "周五"
            Calendar.SATURDAY -> "周六"
            else -> "周日"
        }
    }
}

data class WidgetWeatherSnapshot(
    val temperatureText: String,
    val iconResId: Int
)

object WidgetWeatherStore {
    private const val PREFS_NAME = "yuran_clock_widget"
    private const val KEY_HAS_WEATHER = "has_weather"
    private const val KEY_TEMPERATURE = "temperature"
    private const val KEY_CODE = "code"

    fun save(context: Context, temperature: Double?, code: Int?) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            if (temperature == null) {
                putBoolean(KEY_HAS_WEATHER, false)
                remove(KEY_TEMPERATURE)
            } else {
                putBoolean(KEY_HAS_WEATHER, true)
                putFloat(KEY_TEMPERATURE, temperature.toFloat())
            }
            if (code == null) {
                remove(KEY_CODE)
            } else {
                putInt(KEY_CODE, code)
            }
        }.apply()
    }

    fun load(context: Context): WidgetWeatherSnapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val hasWeather = prefs.getBoolean(KEY_HAS_WEATHER, false)
        val code = if (prefs.contains(KEY_CODE)) prefs.getInt(KEY_CODE, -1) else null
        val temperature = if (hasWeather) prefs.getFloat(KEY_TEMPERATURE, 0f).toDouble() else null
        if (temperature == null) {
            val fileSnapshot = loadFromStickyData(context)
            if (fileSnapshot != null) {
                return fileSnapshot
            }
        }

        val tempText = if (temperature != null) {
            "${temperature.roundToInt()}°"
        } else {
            "--°"
        }
        return WidgetWeatherSnapshot(tempText, iconForCode(code))
    }

    private fun loadFromStickyData(context: Context): WidgetWeatherSnapshot? {
        return try {
            val file = java.io.File(context.filesDir, "sticky_notes.json")
            if (!file.exists()) return null
            val root = JSONObject(file.readText())
            val weather = root.optJSONObject("weather") ?: return null
            val temperature = if (weather.has("temperature") && !weather.isNull("temperature")) {
                weather.optDouble("temperature")
            } else {
                null
            }
            val code = if (weather.has("code") && !weather.isNull("code")) {
                weather.optInt("code")
            } else {
                null
            }
            if (temperature == null) {
                null
            } else {
                WidgetWeatherSnapshot("${temperature.roundToInt()}°", iconForCode(code))
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun iconForCode(code: Int?): Int {
        return when {
            code == 0 -> R.drawable.widget_weather_sunny
            code == 1 || code == 2 -> R.drawable.widget_weather_partly
            code == 3 -> R.drawable.widget_weather_cloudy
            code == 45 || code == 48 -> R.drawable.widget_weather_fog
            code != null && ((code in 51..67) || (code in 80..82)) -> R.drawable.widget_weather_rain
            code != null && ((code in 71..77) || (code in 85..86)) -> R.drawable.widget_weather_snow
            code != null && code >= 95 -> R.drawable.widget_weather_thunder
            else -> R.drawable.widget_weather_unknown
        }
    }
}

private object ClockBitmapRenderer {
    private const val DIGITAL_WIDTH = 620
    private const val DIGITAL_HEIGHT = 288
    private const val ANALOG_SIZE = 430

    private val locale = Locale.CHINA

    fun drawDigital(calendar: Calendar): Bitmap {
        val bitmap = Bitmap.createBitmap(DIGITAL_WIDTH, DIGITAL_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val bounds = RectF(18f, 18f, DIGITAL_WIDTH - 18f, DIGITAL_HEIGHT - 18f)

        drawGlassPanel(canvas, bounds, 36f, Color.rgb(13, 18, 26), Color.rgb(29, 38, 48))
        drawDigitalAccent(canvas, bounds)

        val dateText = SimpleDateFormat("MM月dd日", locale).format(calendar.time)
        val weekdayText = weekdayName(calendar)
        val timeText = SimpleDateFormat("HH:mm", locale).format(calendar.time)
        val infoText = "第${calendar.get(Calendar.DAY_OF_YEAR)}天  ·  第${isoWeek(calendar)}周"

        val datePaint = textPaint(34f, Color.rgb(222, 230, 238), "sans-serif-medium")
        val weekdayPaint = textPaint(27f, Color.rgb(126, 201, 167), "sans-serif")
        val timePaint = textPaint(116f, Color.WHITE, "sans-serif-condensed", Typeface.BOLD)
        val infoPaint = textPaint(27f, Color.rgb(177, 189, 201), "sans-serif")
        val brandPaint = textPaint(24f, Color.rgb(111, 157, 255), "sans-serif-medium")

        canvas.drawText("雨然时钟", bounds.left + 38f, bounds.top + 48f, brandPaint)
        drawPill(canvas, bounds.right - 148f, bounds.top + 24f, bounds.right - 38f, bounds.top + 58f, weekdayText, weekdayPaint)

        canvas.drawText(dateText, bounds.left + 38f, bounds.top + 92f, datePaint)
        canvas.drawText(timeText, bounds.left + 34f, bounds.top + 198f, timePaint)
        canvas.drawText(infoText, bounds.left + 42f, bounds.bottom - 32f, infoPaint)

        drawSoftDots(canvas, bounds)
        return bitmap
    }

    fun drawAnalog(calendar: Calendar): Bitmap {
        val bitmap = Bitmap.createBitmap(ANALOG_SIZE, ANALOG_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = ANALOG_SIZE / 2f
        val radius = center - 30f

        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(52, 80, 161, 255)
            setShadowLayer(20f, 0f, 10f, Color.argb(90, 0, 0, 0))
        }
        canvas.drawCircle(center, center + 4f, radius + 16f, haloPaint)

        val facePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = SweepGradient(
                center,
                center,
                intArrayOf(
                    Color.rgb(18, 26, 35),
                    Color.rgb(34, 43, 53),
                    Color.rgb(18, 26, 35)
                ),
                floatArrayOf(0f, 0.52f, 1f)
            )
        }
        canvas.drawCircle(center, center, radius, facePaint)

        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 5f
            shader = LinearGradient(
                center - radius,
                center - radius,
                center + radius,
                center + radius,
                Color.rgb(95, 180, 255),
                Color.rgb(126, 201, 167),
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawCircle(center, center, radius - 3f, ringPaint)

        drawAnalogTicks(canvas, center, radius)
        drawAnalogNumbers(canvas, center, radius)
        drawAnalogCenterDate(canvas, calendar, center)
        drawClockHands(canvas, calendar, center, radius)

        val capPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(center, center, 10f, capPaint)
        capPaint.color = Color.rgb(88, 171, 255)
        canvas.drawCircle(center, center, 5f, capPaint)
        return bitmap
    }

    private fun drawGlassPanel(canvas: Canvas, rect: RectF, radius: Float, startColor: Int, endColor: Int) {
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(120, 0, 0, 0)
            setShadowLayer(18f, 0f, 10f, Color.argb(95, 0, 0, 0))
        }
        canvas.drawRoundRect(rect, radius, radius, shadowPaint)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                rect.left,
                rect.top,
                rect.right,
                rect.bottom,
                startColor,
                endColor,
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawRoundRect(rect, radius, radius, bgPaint)

        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2.5f
            color = Color.argb(160, 109, 128, 148)
        }
        canvas.drawRoundRect(rect.insetCopy(1.5f), radius, radius, borderPaint)
    }

    private fun drawDigitalAccent(canvas: Canvas, rect: RectF) {
        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                rect.left,
                rect.top,
                rect.left,
                rect.bottom,
                Color.rgb(88, 171, 255),
                Color.rgb(126, 201, 167),
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawRoundRect(
            RectF(rect.left + 18f, rect.top + 22f, rect.left + 25f, rect.bottom - 22f),
            4f,
            4f,
            accentPaint
        )
    }

    private fun drawSoftDots(canvas: Canvas, rect: RectF) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.argb(28, 255, 255, 255)
        canvas.drawCircle(rect.right - 56f, rect.bottom - 52f, 18f, paint)
        paint.color = Color.argb(24, 126, 201, 167)
        canvas.drawCircle(rect.right - 86f, rect.bottom - 90f, 9f, paint)
        paint.color = Color.argb(34, 88, 171, 255)
        canvas.drawCircle(rect.right - 38f, rect.top + 88f, 8f, paint)
    }

    private fun drawPill(
        canvas: Canvas,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
        text: String,
        paint: Paint
    ) {
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(38, 126, 201, 167)
            style = Paint.Style.FILL
        }
        val rect = RectF(left, top, right, bottom)
        canvas.drawRoundRect(rect, 17f, 17f, bgPaint)

        val textWidth = paint.measureText(text)
        val baseline = rect.centerY() - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(text, rect.centerX() - textWidth / 2f, baseline, paint)
    }

    private fun drawAnalogTicks(canvas: Canvas, center: Float, radius: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            strokeCap = Paint.Cap.ROUND
        }
        for (i in 0 until 60) {
            val angle = Math.toRadians((i * 6 - 90).toDouble())
            val major = i % 5 == 0
            val outer = radius - 18f
            val inner = if (major) radius - 38f else radius - 28f
            paint.strokeWidth = if (major) 5.2f else 2.2f
            paint.color = if (major) Color.argb(210, 231, 238, 245) else Color.argb(92, 184, 196, 208)
            canvas.drawLine(
                center + cos(angle).toFloat() * inner,
                center + sin(angle).toFloat() * inner,
                center + cos(angle).toFloat() * outer,
                center + sin(angle).toFloat() * outer,
                paint
            )
        }
    }

    private fun drawAnalogNumbers(canvas: Canvas, center: Float, radius: Float) {
        val paint = textPaint(30f, Color.argb(220, 236, 242, 248), "sans-serif-medium")
        val labels = arrayOf("12", "3", "6", "9")
        val degrees = intArrayOf(-90, 0, 90, 180)
        for (i in labels.indices) {
            val angle = Math.toRadians(degrees[i].toDouble())
            val x = center + cos(angle).toFloat() * (radius - 68f)
            val y = center + sin(angle).toFloat() * (radius - 68f)
            drawCenteredText(canvas, labels[i], x, y, paint)
        }
    }

    private fun drawAnalogCenterDate(canvas: Canvas, calendar: Calendar, center: Float) {
        val dateText = SimpleDateFormat("M月d日", locale).format(calendar.time)
        val weekdayText = weekdayName(calendar)
        val datePaint = textPaint(28f, Color.rgb(230, 238, 246), "sans-serif-medium")
        val weekPaint = textPaint(23f, Color.rgb(126, 201, 167), "sans-serif")

        val chipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(56, 5, 10, 16)
            style = Paint.Style.FILL
        }
        canvas.drawRoundRect(RectF(center - 78f, center - 40f, center + 78f, center + 39f), 24f, 24f, chipPaint)
        drawCenteredText(canvas, dateText, center, center - 10f, datePaint)
        drawCenteredText(canvas, weekdayText, center, center + 21f, weekPaint)
    }

    private fun drawClockHands(canvas: Canvas, calendar: Calendar, center: Float, radius: Float) {
        val hour = calendar.get(Calendar.HOUR)
        val minute = calendar.get(Calendar.MINUTE)
        val second = calendar.get(Calendar.SECOND)
        val hourDegrees = (hour + minute / 60f) * 30f - 90f
        val minuteDegrees = (minute + second / 60f) * 6f - 90f

        val hourPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(245, 249, 252)
            style = Paint.Style.FILL
        }
        canvas.drawPath(handPath(center, radius * 0.43f, 15f, hourDegrees), hourPaint)

        val minutePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(88, 171, 255)
            style = Paint.Style.FILL
        }
        canvas.drawPath(handPath(center, radius * 0.62f, 10f, minuteDegrees), minutePaint)
    }

    private fun handPath(center: Float, length: Float, halfWidth: Float, degrees: Float): Path {
        val angle = Math.toRadians(degrees.toDouble())
        val side = angle + Math.PI / 2
        val tailLength = min(length * 0.2f, 34f)
        val tipX = center + cos(angle).toFloat() * length
        val tipY = center + sin(angle).toFloat() * length
        val tailX = center - cos(angle).toFloat() * tailLength
        val tailY = center - sin(angle).toFloat() * tailLength

        return Path().apply {
            moveTo(tipX, tipY)
            lineTo(
                center + cos(side).toFloat() * halfWidth,
                center + sin(side).toFloat() * halfWidth
            )
            lineTo(tailX, tailY)
            lineTo(
                center - cos(side).toFloat() * halfWidth,
                center - sin(side).toFloat() * halfWidth
            )
            close()
        }
    }

    private fun drawCenteredText(canvas: Canvas, text: String, x: Float, y: Float, paint: Paint) {
        val textWidth = paint.measureText(text)
        val baseline = y - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(text, x - textWidth / 2f, baseline, paint)
    }

    private fun textPaint(
        size: Float,
        color: Int,
        family: String,
        style: Int = Typeface.NORMAL
    ): Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        textSize = size
        typeface = Typeface.create(family, style)
        isSubpixelText = true
    }

    private fun weekdayName(calendar: Calendar): String {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "周一"
            Calendar.TUESDAY -> "周二"
            Calendar.WEDNESDAY -> "周三"
            Calendar.THURSDAY -> "周四"
            Calendar.FRIDAY -> "周五"
            Calendar.SATURDAY -> "周六"
            else -> "周日"
        }
    }

    private fun isoWeek(calendar: Calendar): Int {
        val clone = calendar.clone() as Calendar
        clone.firstDayOfWeek = Calendar.MONDAY
        clone.minimalDaysInFirstWeek = 4
        return clone.get(Calendar.WEEK_OF_YEAR)
    }

    private fun RectF.insetCopy(amount: Float): RectF {
        return RectF(left + amount, top + amount, right - amount, bottom - amount)
    }
}
