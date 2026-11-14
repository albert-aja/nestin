package com.nestin.app

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import kotlin.math.roundToInt

/**
 * Native Android MethodChannel handler for Scout Digital Wellbeing, Phone Modes,
 * System Settings Safe State Restoration, and Centralized Permission Center.
 * Reports missing permissions or OS refusals honestly without faking success.
 */
class DeviceControlPlugin(
    private val activity: Activity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nestin.app/device_control"

        fun register(activity: Activity, flutterEngine: FlutterEngine): DeviceControlPlugin {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = DeviceControlPlugin(activity, channel)
            channel.setMethodCallHandler(plugin)
            return plugin
        }
    }

    private val context: Context
        get() = activity.applicationContext

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspectCapabilities" -> result.success(buildCapabilitiesMap())
            "readSystemState" -> result.success(buildSystemStateMap())
            "getAppUsageToday" -> {
                @Suppress("UNCHECKED_CAST")
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                result.success(queryAppUsageToday(packages))
            }
            "setDndEnabled" -> {
                val enable = call.argument<Boolean>("enable") ?: false
                result.success(setDndFilter(if (enable) NotificationManager.INTERRUPTION_FILTER_PRIORITY else NotificationManager.INTERRUPTION_FILTER_ALL))
            }
            "restoreDndFilter" -> {
                val filter = call.argument<Int>("filter") ?: NotificationManager.INTERRUPTION_FILTER_ALL
                result.success(setDndFilter(filter))
            }
            "setScreenBrightness" -> {
                val percent = call.argument<Int>("percent") ?: 50
                val clamped = percent.coerceIn(1, 100)
                val raw = ((clamped / 100.0) * 255.0).roundToInt().coerceIn(1, 255)
                result.success(writeBrightnessRaw(raw, "$clamped%"))
            }
            "restoreBrightness" -> {
                val raw = (call.argument<Int>("brightnessRaw") ?: 128).coerceIn(1, 255)
                result.success(writeBrightnessRaw(raw, "raw:$raw"))
            }
            "setScreenTimeoutSeconds" -> {
                val seconds = (call.argument<Int>("seconds") ?: 30).coerceIn(15, 1800)
                result.success(writeScreenTimeoutMs(seconds * 1000))
            }
            "restoreScreenTimeoutMs" -> {
                val timeoutMs = (call.argument<Int>("timeoutMs") ?: 30000).coerceIn(15000, 1800000)
                result.success(writeScreenTimeoutMs(timeoutMs))
            }
            "openPermissionSettings" -> {
                val kind = call.argument<String>("permission") ?: ""
                result.success(openSettingsForPermission(kind))
            }
            "openSystemModesOrWellbeing" -> {
                result.success(openSystemModesOrWellbeing())
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsageStatsAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasDndAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        return nm.isNotificationPolicyAccessGranted
    }

    private fun canWriteSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(context)
        } else {
            true
        }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        return am.canScheduleExactAlarms()
    }

    private fun hasNotificationsPermission(): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        val enabledInSystem = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            nm.areNotificationsEnabled()
        } else {
            true
        }
        val runtimeGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return enabledInSystem && runtimeGranted
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun hasAccessibilityServiceEnabled(): Boolean {
        return try {
            val enabled = Settings.Secure.getInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
            if (enabled != 1) return false
            val services = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
            services.contains(context.packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasBackgroundLocationPermission(): Boolean {
        if (!hasLocationPermission()) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun currentDndFilter(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 1
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return 1
        return nm.currentInterruptionFilter
    }

    private fun currentBrightnessRaw(): Int {
        return try {
            Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128)
        } catch (_: Exception) {
            128
        }
    }

    private fun currentScreenTimeoutMs(): Int {
        return try {
            Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, 30000)
        } catch (_: Exception) {
            30000
        }
    }

    private fun buildSystemStateMap(): Map<String, Any> {
        return mapOf(
            "dndFilter" to currentDndFilter(),
            "brightnessRaw" to currentBrightnessRaw(),
            "screenTimeoutMs" to currentScreenTimeoutMs(),
            "hasUsageStats" to hasUsageStatsAccess(),
            "hasDndAccess" to hasDndAccess(),
            "canWriteSettings" to canWriteSettings(),
            "hasOverlayPermission" to hasOverlayPermission(),
            "hasAccessibilityService" to hasAccessibilityServiceEnabled(),
            "hasExactAlarm" to hasExactAlarmPermission(),
            "hasNotifications" to hasNotificationsPermission(),
            "isBatteryOptimizationExempt" to isBatteryOptimizationExempt(),
            "hasFamilyControlsEntitlement" to false
        )
    }

    private fun buildCapabilitiesMap(): Map<String, Any> {
        return buildSystemStateMap() + mapOf(
            "platform" to "android",
            "manufacturer" to (Build.MANUFACTURER ?: "unknown"),
            "brand" to (Build.BRAND ?: "unknown"),
            "model" to (Build.MODEL ?: "unknown"),
            "osVersion" to (Build.VERSION.RELEASE ?: "unknown"),
            "sdkInt" to Build.VERSION.SDK_INT,
            "hasLocation" to hasLocationPermission(),
            "hasBackgroundLocation" to hasBackgroundLocationPermission()
        )
    }

    private fun queryAppUsageToday(targetPackages: List<String>): Map<String, Any> {
        if (!hasUsageStatsAccess()) {
            return mapOf(
                "permissionGranted" to false,
                "boundaryMessage" to "Usage Access permission is not granted. Enable it in Permission Center for real Android app screen time.",
                "records" to emptyList<Map<String, Any>>()
            )
        }

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf(
                "permissionGranted" to false,
                "boundaryMessage" to "UsageStatsManager service is unavailable on this device.",
                "records" to emptyList<Map<String, Any>>()
            )

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startMs = cal.timeInMillis
        val endMs = System.currentTimeMillis()
        val aggregated = usm.queryAndAggregateUsageStats(startMs, endMs) ?: emptyMap()

        val launchCounts = mutableMapOf<String, Int>()
        try {
            val events = usm.queryEvents(startMs, endMs)
            val event = UsageEvents.Event()
            val resumeEventType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == resumeEventType) {
                    val pkg = event.packageName
                    if (targetPackages.isEmpty() || targetPackages.contains(pkg)) {
                        launchCounts[pkg] = (launchCounts[pkg] ?: 0) + 1
                    }
                }
            }
        } catch (_: Exception) {
            // UsageEvents may be empty under OEM restrictions; keep foreground stats intact.
        }

        val pm = context.packageManager
        val packagesToReport = if (targetPackages.isNotEmpty()) targetPackages else aggregated.keys.toList()
        val records = packagesToReport.mapNotNull { pkg ->
            val stat = aggregated[pkg]
            val usedMinutes = if (stat != null) (stat.totalTimeInForeground / 60000L).toInt() else 0
            val launches = launchCounts[pkg] ?: 0
            val appName = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (_: Exception) {
                pkg
            }
            mapOf(
                "packageName" to pkg,
                "appName" to appName,
                "usedMinutesToday" to usedMinutes,
                "launchCountToday" to launches,
                "lastTimeUsedMs" to (stat?.lastTimeUsed ?: 0L)
            )
        }

        return mapOf(
            "permissionGranted" to true,
            "boundaryMessage" to "",
            "records" to records
        )
    }

    private fun setDndFilter(targetFilter: Int): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return mapOf(
                "support" to "unsupported",
                "succeeded" to false,
                "message" to "Do Not Disturb policy control requires Android 6.0+."
            )
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return mapOf(
                "support" to "unsupported",
                "succeeded" to false,
                "message" to "NotificationManager unavailable."
            )
        if (!nm.isNotificationPolicyAccessGranted) {
            return mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "Do Not Disturb Access permission has not been granted."
            )
        }
        val prev = nm.currentInterruptionFilter
        return try {
            nm.setInterruptionFilter(targetFilter)
            val actual = nm.currentInterruptionFilter
            mapOf(
                "support" to "directlySupported",
                "succeeded" to true,
                "message" to if (targetFilter == NotificationManager.INTERRUPTION_FILTER_ALL) "Do Not Disturb disabled." else "Do Not Disturb enabled.",
                "previousRawValue" to prev,
                "appliedRawValue" to actual
            )
        } catch (e: SecurityException) {
            mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "OS rejected Do Not Disturb change: ${e.message}"
            )
        }
    }

    private fun writeBrightnessRaw(targetRaw: Int, label: String): Map<String, Any?> {
        if (!canWriteSettings()) {
            return mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "Modify System Settings (WRITE_SETTINGS) permission is missing."
            )
        }
        return try {
            val prev = currentBrightnessRaw()
            Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            )
            val wrote = Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                targetRaw
            )
            val actual = currentBrightnessRaw()
            mapOf(
                "support" to "directlySupported",
                "succeeded" to wrote,
                "message" to if (wrote) "Screen brightness set to $label." else "OS declined brightness write.",
                "previousRawValue" to prev,
                "appliedRawValue" to actual
            )
        } catch (e: Exception) {
            mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "Could not modify screen brightness: ${e.message}"
            )
        }
    }

    private fun writeScreenTimeoutMs(timeoutMs: Int): Map<String, Any?> {
        if (!canWriteSettings()) {
            return mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "Modify System Settings (WRITE_SETTINGS) permission is missing."
            )
        }
        return try {
            val prev = currentScreenTimeoutMs()
            val wrote = Settings.System.putInt(
                context.contentResolver,
                Settings.System.SCREEN_OFF_TIMEOUT,
                timeoutMs
            )
            val actual = currentScreenTimeoutMs()
            mapOf(
                "support" to "directlySupported",
                "succeeded" to wrote,
                "message" to if (wrote) "Screen timeout set to ${timeoutMs / 1000}s." else "OS declined screen timeout write.",
                "previousRawValue" to prev,
                "appliedRawValue" to actual
            )
        } catch (e: Exception) {
            mapOf(
                "support" to "permissionRequired",
                "succeeded" to false,
                "message" to "Could not modify screen timeout: ${e.message}"
            )
        }
    }

    private fun openSettingsForPermission(kind: String): Boolean {
        val pkgUri = Uri.parse("package:${context.packageName}")
        val intent: Intent = when (kind) {
            "usageStats" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "notificationPolicy" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            }
            "writeSettings" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, pkgUri)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            }
            "systemAlertWindow" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkgUri)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            }
            "exactAlarm" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkgUri)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            }
            "notifications" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
            }
            "batteryOptimizationExempt" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            } else {
                Intent(Settings.ACTION_SETTINGS)
            }
            "accessibilityService" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
        }
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri)
                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun openSystemModesOrWellbeing(): Boolean {
        val pm = context.packageManager
        val candidates = listOf(
            "com.samsung.android.app.routines",
            "com.samsung.android.forest",
            "com.google.android.apps.wellbeing"
        )
        for (pkg in candidates) {
            val launch = pm.getLaunchIntentForPackage(pkg)
            if (launch != null) {
                return try {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(launch)
                    true
                } catch (_: Exception) {
                    false
                }
            }
        }
        return try {
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
