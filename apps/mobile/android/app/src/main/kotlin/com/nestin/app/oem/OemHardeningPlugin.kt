package com.nestin.app.oem

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.nestin.app.services.NestinKeepAliveService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class OemHardeningPlugin(private val activity: Activity) {

    companion object {
        const val CHANNEL_NAME = "com.nestin.app/oem_hardening"

        fun register(activity: Activity, flutterEngine: FlutterEngine): OemHardeningPlugin {
            val plugin = OemHardeningPlugin(activity)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceOemInfo" -> {
                        try {
                            val info = plugin.getDeviceOemInfo()
                            result.success(info)
                        } catch (e: Exception) {
                            result.error("OEM_INFO_ERROR", e.message, null)
                        }
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val res = plugin.requestIgnoreBatteryOptimizations()
                            result.success(res)
                        } catch (e: Exception) {
                            result.error("BATTERY_OPT_ERROR", e.message, null)
                        }
                    }
                    "openOemAutostartSettings" -> {
                        try {
                            val res = plugin.openOemAutostartSettings()
                            result.success(res)
                        } catch (e: Exception) {
                            result.error("AUTOSTART_ERROR", e.message, null)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            val res = plugin.openBatterySettings()
                            result.success(res)
                        } catch (e: Exception) {
                            result.error("BATTERY_SETTINGS_ERROR", e.message, null)
                        }
                    }
                    "startKeepAliveService" -> {
                        try {
                            NestinKeepAliveService.startService(activity)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_START_ERROR", e.message, null)
                        }
                    }
                    "stopKeepAliveService" -> {
                        try {
                            NestinKeepAliveService.stopService(activity)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_STOP_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            return plugin
        }
    }

    private fun getDeviceOemInfo(): Map<String, Any> {
        val manufacturer = Build.MANUFACTURER ?: ""
        val brand = Build.BRAND ?: ""
        val model = Build.MODEL ?: ""
        val sdkInt = Build.VERSION.SDK_INT

        var isIgnoringBattery = false
        if (sdkInt >= Build.VERSION_CODES.M) {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as? PowerManager
            isIgnoringBattery = pm?.isIgnoringBatteryOptimizations(activity.packageName) ?: false
        } else {
            isIgnoringBattery = true
        }

        return mapOf(
            "manufacturer" to manufacturer,
            "brand" to brand,
            "model" to model,
            "sdkInt" to sdkInt,
            "isIgnoringBatteryOptimizations" to isIgnoringBattery,
            "isKeepAliveRunning" to NestinKeepAliveService.isRunning
        )
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && !pm.isIgnoringBatteryOptimizations(activity.packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${activity.packageName}")
                    }
                    activity.startActivity(intent)
                    return true
                } catch (e: Exception) {
                    // Fallback to general settings
                    try {
                        val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        activity.startActivity(fallback)
                        return true
                    } catch (e2: Exception) {
                        return openAppDetails()
                    }
                }
            }
        }
        return true
    }

    private fun openOemAutostartSettings(): Boolean {
        val m = Build.MANUFACTURER.lowercase()
        val intents = mutableListOf<Intent>()

        // 1. Xiaomi / Redmi / POCO
        if (m.contains("xiaomi") || m.contains("redmi") || m.contains("poco")) {
            intents.add(Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")))
            intents.add(Intent("miui.intent.action.OP_AUTO_START"))
            intents.add(Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.powerkeeper.ui.PowerHideModeActivity")))
        }

        // 2. Samsung (OneUI / Smart Manager / Device Care)
        if (m.contains("samsung")) {
            intents.add(Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")))
            intents.add(Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")))
            intents.add(Intent().setComponent(ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.battery.BatteryActivity")))
            intents.add(Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity")))
        }

        // 3. Huawei / Honor (EMUI / HarmonyOS)
        if (m.contains("huawei") || m.contains("honor")) {
            intents.add(Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")))
            intents.add(Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.bootstart.BootStartActivity")))
            intents.add(Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")))
        }

        // 4. Oppo / Realme (ColorOS)
        if (m.contains("oppo") || m.contains("realme")) {
            intents.add(Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")))
            intents.add(Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")))
            intents.add(Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")))
        }

        // 5. Vivo / iQOO (FuntouchOS / OriginOS)
        if (m.contains("vivo") || m.contains("iqoo")) {
            intents.add(Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")))
            intents.add(Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")))
            intents.add(Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")))
        }

        // 6. OnePlus (OxygenOS)
        if (m.contains("oneplus")) {
            intents.add(Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")))
        }

        // Try OEM specific intents
        for (intent in intents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {
                // Continue to next candidate
            }
        }

        // Fallback to app details
        return openAppDetails()
    }

    private fun openBatterySettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {}
        }
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {
            return false
        }
    }
}

