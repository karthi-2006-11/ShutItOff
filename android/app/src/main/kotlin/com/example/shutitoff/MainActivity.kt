package com.example.shutitoff

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val PERMISSIONS_CHANNEL = "com.example.shutitoff/permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryUnrestricted" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                            result.success(isIgnoring)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isOverlayAllowed" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val canDraw = Settings.canDrawOverlays(this)
                            result.success(canDraw)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "requestBatteryUnrestricted" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INTENT_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "requestOverlayAllowed" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INTENT_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "getNextSystemAlarmClock" -> {
                    try {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        val nextAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            alarmManager?.nextAlarmClock
                        } else {
                            null
                        }
                        if (nextAlarm != null) {
                            val triggerTime = nextAlarm.triggerTime
                            val deviceTimeZone = TimeZone.getDefault()
                            val calendar = Calendar.getInstance(deviceTimeZone).apply {
                                timeZone = deviceTimeZone
                                timeInMillis = triggerTime
                            }
                            // Extract exact upcoming alarm hour and minute in 24-hour format
                            val hourOfDay = calendar.get(Calendar.HOUR_OF_DAY)
                            val minute = calendar.get(Calendar.MINUTE)
                            val minuteOfDay = hourOfDay * 60 + minute

                            // Minute-by-minute Morning Timeframe Gatekeeper: 4:00 AM (240m) up to and including 7:00 AM (420m)
                            if (minuteOfDay in (4 * 60)..(7 * 60)) {
                                val sdf = SimpleDateFormat("hh:mm a", Locale.getDefault())
                                sdf.timeZone = deviceTimeZone
                                val formatted = sdf.format(calendar.time)
                                result.success(formatted)
                            } else {
                                // Outside 4:00 AM - 7:00 AM window (e.g., 11:00 PM (23:00) / 07:01 AM) -> IGNORE (Return empty string, no alert)
                                result.success("")
                            }
                        } else {
                            result.success("")
                        }
                    } catch (e: Exception) {
                        result.success("")
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
