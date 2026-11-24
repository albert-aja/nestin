package com.nestin.app.wallpaper

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Pure-native Android WorkManager [Worker] that applies today's pre-rendered
 * `yyyy-MM-dd.png` lock-screen wallpaper (or falls back to the newest cached PNG)
 * via [android.app.WallpaperManager] with zero Flutter engine startup, then
 * chains the next daily run at the user's configured refresh time.
 */
class DailyWallpaperWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(
            DailyWallpaperPlugin.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val enabled = prefs.getBoolean(DailyWallpaperPlugin.KEY_ENABLED, false)
        if (!enabled) {
            return Result.success()
        }

        val cacheDirPath = prefs.getString(DailyWallpaperPlugin.KEY_CACHE_DIR, null)
        val target = prefs.getString(DailyWallpaperPlugin.KEY_TARGET, "lock") ?: "lock"
        val hour = prefs.getInt(DailyWallpaperPlugin.KEY_HOUR, 5)
        val minute = prefs.getInt(DailyWallpaperPlugin.KEY_MINUTE, 0)

        try {
            val fileToApply = resolveWallpaperFile(cacheDirPath)
            if (fileToApply != null) {
                DailyWallpaperPlugin.applyBitmapFile(
                    applicationContext,
                    fileToApply.absolutePath,
                    target
                )
            }
        } catch (_: Exception) {
            // Never crash background work; still re-chain tomorrow's scheduled run.
        } finally {
            if (prefs.getBoolean(DailyWallpaperPlugin.KEY_ENABLED, false)) {
                DailyWallpaperPlugin.enqueueNextRun(applicationContext, hour, minute)
            }
        }

        return Result.success()
    }

    private fun resolveWallpaperFile(cacheDirPath: String?): File? {
        if (cacheDirPath.isNullOrBlank()) return null
        val dir = File(cacheDirPath)
        if (!dir.exists() || !dir.isDirectory) return null

        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val todayFile = File(dir, "$todayKey.png")
        if (todayFile.exists() && todayFile.isFile && todayFile.length() > 0L) {
            return todayFile
        }

        // Fallback: newest cached PNG by filename/lastModified
        return dir.listFiles { file ->
            file.isFile && file.name.endsWith(".png", ignoreCase = true) && file.length() > 0L
        }?.maxWithOrNull(compareBy<File> { it.name }.thenBy { it.lastModified() })
    }
}
