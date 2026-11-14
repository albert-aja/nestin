package com.nestin.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.nestin.app.geofencing.GeofencingPlugin
import com.nestin.app.oem.OemHardeningPlugin
import com.nestin.app.widgets.HabitChecklistWidgetProvider
import com.nestin.app.widgets.NextAlarmWidgetProvider
import com.nestin.app.widgets.QuickCaptureWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nestin.app/widgets"
    private var initialUri: String? = null
    private var methodChannel: MethodChannel? = null
    private var oemPlugin: OemHardeningPlugin? = null
    private var geofencingPlugin: GeofencingPlugin? = null
    private var deviceControlPlugin: DeviceControlPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.dataString?.let {
            initialUri = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { uri ->
            initialUri = uri
            methodChannel?.invokeMethod("onDeepLink", uri)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        oemPlugin = OemHardeningPlugin.register(this, flutterEngine)
        geofencingPlugin = GeofencingPlugin.register(this, flutterEngine)
        deviceControlPlugin = DeviceControlPlugin.register(this, flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUri" -> {
                        val uri = initialUri
                        initialUri = null
                        result.success(uri)
                    }
                    "updateNextAlarm" -> {
                        try {
                            val args = call.arguments as? Map<*, *>
                            val prefs = getSharedPreferences(NextAlarmWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                            prefs.edit().apply {
                                putBoolean(NextAlarmWidgetProvider.KEY_HAS_ALARM, args?.get("hasAlarm") as? Boolean ?: false)
                                putString(NextAlarmWidgetProvider.KEY_TIME, args?.get("time") as? String ?: "--:--")
                                putString(NextAlarmWidgetProvider.KEY_AMPM, args?.get("ampm") as? String ?: "")
                                putString(NextAlarmWidgetProvider.KEY_COUNTDOWN, args?.get("countdown") as? String ?: "")
                                putString(NextAlarmWidgetProvider.KEY_LABEL, args?.get("label") as? String ?: "")
                                apply()
                            }
                            NextAlarmWidgetProvider.updateAll(context)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_ERROR", e.message, null)
                        }
                    }
                    "updateHabits" -> {
                        try {
                            val args = call.arguments as? Map<*, *>
                            val prefs = getSharedPreferences(HabitChecklistWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                            val editor = prefs.edit()
                            editor.putString(HabitChecklistWidgetProvider.KEY_TITLE, args?.get("title") as? String ?: "Daily Habits")
                            editor.putString(HabitChecklistWidgetProvider.KEY_STREAK, args?.get("streak") as? String ?: "")
                            editor.putString(HabitChecklistWidgetProvider.KEY_PROGRESS, args?.get("progress") as? String ?: "")

                            val steps = args?.get("steps") as? List<*>
                            for (i in 0 until 4) {
                                val stepIdx = i + 1
                                if (steps != null && i < steps.size) {
                                    val stepMap = steps[i] as? Map<*, *>
                                    editor.putString("${HabitChecklistWidgetProvider.KEY_STEP_PREFIX}${stepIdx}_text", stepMap?.get("text") as? String ?: "")
                                    editor.putBoolean("${HabitChecklistWidgetProvider.KEY_STEP_PREFIX}${stepIdx}_done", stepMap?.get("isDone") as? Boolean ?: false)
                                } else {
                                    editor.remove("${HabitChecklistWidgetProvider.KEY_STEP_PREFIX}${stepIdx}_text")
                                    editor.remove("${HabitChecklistWidgetProvider.KEY_STEP_PREFIX}${stepIdx}_done")
                                }
                            }
                            editor.apply()
                            HabitChecklistWidgetProvider.updateAll(context)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_ERROR", e.message, null)
                        }
                    }
                    "updateQuickCapture" -> {
                        try {
                            QuickCaptureWidgetProvider.updateAll(context)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (geofencingPlugin?.onRequestPermissionsResult(requestCode, permissions, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        geofencingPlugin?.dispose()
        super.onDestroy()
    }
}
