package com.nestin.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.tts.TextToSpeech
import com.nestin.app.geofencing.GeofencingPlugin
import com.nestin.app.oem.OemHardeningPlugin
import com.nestin.app.widgets.HabitChecklistWidgetProvider
import com.nestin.app.widgets.HydrationWidgetProvider
import com.nestin.app.widgets.NextAlarmWidgetProvider
import com.nestin.app.widgets.QuickCaptureWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nestin.app/widgets"
    private val TTS_CHANNEL = "com.nestin.app/tts"
    private var initialUri: String? = null
    private var methodChannel: MethodChannel? = null
    private var ttsChannel: MethodChannel? = null
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
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
                                (args?.get("mascotPose") as? String)?.let {
                                    putString(NextAlarmWidgetProvider.KEY_MASCOT_POSE, it)
                                }
                                (args?.get("showMascots") as? Boolean)?.let {
                                    putBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, it)
                                }
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
                            (args?.get("mascotPose") as? String)?.let {
                                editor.putString(HabitChecklistWidgetProvider.KEY_MASCOT_POSE, it)
                            }
                            (args?.get("showMascots") as? Boolean)?.let {
                                editor.putBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, it)
                            }

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
                            val args = call.arguments as? Map<*, *>
                            (args?.get("showMascots") as? Boolean)?.let { show ->
                                val prefs = getSharedPreferences(NextAlarmWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                                prefs.edit().putBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, show).apply()
                            }
                            QuickCaptureWidgetProvider.updateAll(context)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_ERROR", e.message, null)
                        }
                    }
                    "updateHydration" -> {
                        try {
                            val args = call.arguments as? Map<*, *>
                            val prefs = getSharedPreferences(HydrationWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                            val glasses = (args?.get("glassesConsumed") as? Number)?.toInt() ?: 0
                            val goal = ((args?.get("dailyGoalGlasses") as? Number)?.toInt() ?: 8).coerceIn(1, 20)
                            val lastDate = args?.get("lastLoggedDate") as? String ?: ""
                            val mascotPose = args?.get("mascotPose") as? String
                                ?: HydrationWidgetProvider.resolveMascotPose(glasses, goal)
                            prefs.edit().apply {
                                putInt(HydrationWidgetProvider.KEY_GLASSES, glasses)
                                putInt(HydrationWidgetProvider.KEY_GOAL, goal)
                                if (lastDate.isNotEmpty()) {
                                    putString(HydrationWidgetProvider.KEY_LAST_DATE, lastDate)
                                }
                                putString(HydrationWidgetProvider.KEY_MASCOT_POSE, mascotPose)
                                (args?.get("showMascots") as? Boolean)?.let { show ->
                                    putBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, show)
                                }
                                apply()
                            }
                            HydrationWidgetProvider.updateAll(context)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        HydrationWidgetProvider.onWidgetLoggedGlassListener = {
            runOnUiThread {
                methodChannel?.invokeMethod("onHydrationUpdatedFromWidget", null)
            }
        }
        textToSpeech = TextToSpeech(applicationContext) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
        }
        ttsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val args = call.arguments as? Map<*, *>
                        val text = args?.get("text") as? String ?: ""
                        val langTag = args?.get("language") as? String ?: "en-US"
                        val rate = (args?.get("rate") as? Number)?.toFloat() ?: 0.85f
                        val volume = (args?.get("volume") as? Number)?.toFloat() ?: 0.90f
                        val tts = textToSpeech
                        if (tts != null && ttsReady && text.isNotEmpty()) {
                            val locale = Locale.forLanguageTag(langTag)
                            val avail = tts.isLanguageAvailable(locale)
                            val supported = avail >= TextToSpeech.LANG_AVAILABLE
                            if (supported) {
                                tts.language = locale
                            }
                            tts.setSpeechRate(rate.coerceIn(0.5f, 1.5f))
                            val params = Bundle().apply {
                                putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume.coerceIn(0.0f, 1.0f))
                            }
                            tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, "seren_tts_${System.currentTimeMillis()}")
                            result.success(mapOf("started" to true, "languageSupported" to supported))
                        } else {
                            result.success(mapOf("started" to false, "languageSupported" to true))
                        }
                    }
                    "stop" -> {
                        textToSpeech?.stop()
                        result.success(true)
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
        HydrationWidgetProvider.onWidgetLoggedGlassListener = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        geofencingPlugin?.dispose()
        super.onDestroy()
    }
}
