package com.nestin.app.wallpaper

import android.app.WallpaperManager
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Build
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Native Android bridge for Nestin's opt-in Daily Affirmation Lock-Screen Wallpaper.
 *
 * Exposes MethodChannel `com.nestin.app/wallpaper`:
 * - `applyWallpaperNow(filePath: String, target: String)` -> Boolean
 * - `scheduleDailyWallpaper(hour: Int, minute: Int, target: String, cacheDir: String)` -> Boolean
 * - `cancelDailyWallpaper()` -> Boolean
 *
 * Zero Flutter engine spin-up in background: scheduled updates run strictly inside
 * [DailyWallpaperWorker] reading pre-rendered 9:16 PNG files from `cacheDir`.
 */
class DailyWallpaperPlugin private constructor(
    private val context: Context,
    private val channel: MethodChannel
) {
    companion object {
        const val CHANNEL_NAME = "com.nestin.app/wallpaper"
        const val PREFS_NAME = "nestin_daily_wallpaper_prefs"
        const val KEY_ENABLED = "enabled"
        const val KEY_HOUR = "hour"
        const val KEY_MINUTE = "minute"
        const val KEY_TARGET = "target"
        const val KEY_CACHE_DIR = "cache_dir"
        const val UNIQUE_WORK_NAME = "nestin_daily_wallpaper_work"

        fun register(context: Context, flutterEngine: FlutterEngine): DailyWallpaperPlugin {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = DailyWallpaperPlugin(context.applicationContext, channel)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "applyWallpaperNow" -> {
                        val filePath = call.argument<String>("filePath")
                        val target = call.argument<String>("target") ?: "lock"
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "filePath is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val ok = applyBitmapFile(context.applicationContext, filePath, target)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("WALLPAPER_ERROR", e.message, null)
                        }
                    }
                    "scheduleDailyWallpaper" -> {
                        val hour = (call.argument<Number>("hour")?.toInt() ?: 5).coerceIn(0, 23)
                        val minute = (call.argument<Number>("minute")?.toInt() ?: 0).coerceIn(0, 59)
                        val target = call.argument<String>("target") ?: "lock"
                        val cacheDir = call.argument<String>("cacheDir")
                        if (cacheDir.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "cacheDir is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            persistAndScheduleNext(
                                context = context.applicationContext,
                                hour = hour,
                                minute = minute,
                                target = target,
                                cacheDir = cacheDir
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }
                    "cancelDailyWallpaper" -> {
                        try {
                            cancelScheduled(context.applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            return plugin
        }

        fun applyBitmapFile(context: Context, filePath: String, target: String): Boolean {
            val file = File(filePath)
            if (!file.exists() || !file.isFile) {
                return false
            }
            val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return false
            return try {
                val wm = WallpaperManager.getInstance(context)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val flags = if (target == "both") {
                        WallpaperManager.FLAG_LOCK or WallpaperManager.FLAG_SYSTEM
                    } else {
                        WallpaperManager.FLAG_LOCK
                    }
                    wm.setBitmap(bitmap, null, true, flags)
                } else {
                    wm.setBitmap(bitmap)
                }
                true
            } finally {
                bitmap.recycle()
            }
        }

        fun persistAndScheduleNext(
            context: Context,
            hour: Int,
            minute: Int,
            target: String,
            cacheDir: String
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_ENABLED, true)
                .putInt(KEY_HOUR, hour)
                .putInt(KEY_MINUTE, minute)
                .putString(KEY_TARGET, target)
                .putString(KEY_CACHE_DIR, cacheDir)
                .apply()

            enqueueNextRun(context, hour, minute)
        }

        fun enqueueNextRun(context: Context, hour: Int, minute: Int) {
            val delayMs = computeDelayUntilNextMillis(hour, minute)
            val request = OneTimeWorkRequestBuilder<DailyWallpaperWorker>()
                .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request
            )
        }

        fun cancelScheduled(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_ENABLED, false).apply()
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
        }

        private fun computeDelayUntilNextMillis(hour: Int, minute: Int): Long {
            val now = Calendar.getInstance()
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
                set(Calendar.MINUTE, minute.coerceIn(0, 59))
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (!next.after(now)) {
                next.add(Calendar.DAY_OF_YEAR, 1)
            }
            return (next.timeInMillis - now.timeInMillis).coerceAtLeast(60_000L)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
