package com.nestin.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.view.KeyEvent
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.nestin.app.geofencing.GeofencingPlugin
import com.nestin.app.oem.OemHardeningPlugin
import com.nestin.app.wallpaper.DailyWallpaperPlugin
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
    private var dailyWallpaperPlugin: DailyWallpaperPlugin? = null
    private var audioManager: AudioManager? = null
    private var becomingNoisyReceiver: BroadcastReceiver? = null
    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var lastAudioRouteDisconnectMs: Long = 0L
    private var serenMediaSession: MediaSession? = null
    private var mediaActionReceiver: BroadcastReceiver? = null

    companion object {
        private const val SEREN_MEDIA_CHANNEL_ID = "nestin_seren_media_channel"
        private const val SEREN_MEDIA_NOTIFICATION_ID = 7260
        private const val ACTION_SEREN_MEDIA_PLAY_PAUSE = "com.nestin.app.SEREN_MEDIA_PLAY_PAUSE"
        private const val ACTION_SEREN_MEDIA_STOP = "com.nestin.app.SEREN_MEDIA_STOP"
        private const val ACTION_SEREN_MEDIA_NEXT = "com.nestin.app.SEREN_MEDIA_NEXT"
        private const val ACTION_SEREN_MEDIA_PREV = "com.nestin.app.SEREN_MEDIA_PREV"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAlarmLockScreenMode(isAlarmLaunchIntent(intent))
        intent?.dataString?.let {
            initialUri = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isAlarmLaunchIntent(intent)) {
            setAlarmLockScreenMode(true)
        }
        intent.dataString?.let { uri ->
            initialUri = uri
            methodChannel?.invokeMethod("onDeepLink", uri)
        }
    }

    private fun isAlarmLaunchIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        if (intent.getBooleanExtra("nestin_alarm_fullscreen", false)) return true
        val payload = intent.getStringExtra("payload")
        if (payload != null && payload.startsWith("alarm_")) return true
        val dataHost = intent.data?.host
        return dataHost == "alarm_ring"
    }

    private fun setAlarmLockScreenMode(enabled: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enabled)
                setTurnScreenOn(enabled)
            }
            @Suppress("DEPRECATION")
            val legacyFlags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                    window.addFlags(legacyFlags)
                }
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                    window.clearFlags(legacyFlags)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        oemPlugin = OemHardeningPlugin.register(this, flutterEngine)
        geofencingPlugin = GeofencingPlugin.register(this, flutterEngine)
        deviceControlPlugin = DeviceControlPlugin.register(this, flutterEngine)
        dailyWallpaperPlugin = DailyWallpaperPlugin.register(this, flutterEngine)
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
                    "setAlarmLockScreenMode" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setAlarmLockScreenMode(enabled)
                        result.success(true)
                    }
                    "launchExternalUri" -> {
                        try {
                            val rawUri = call.argument<String>("uri")
                            if (rawUri.isNullOrBlank()) {
                                result.success(false)
                            } else {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(rawUri)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            }
                        } catch (_: Exception) {
                            result.success(false)
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
                    "isExternalAudioConnected" -> {
                        result.success(hasExternalAudioOutputConnected())
                    }
                    "syncMediaSession" -> {
                        val args = call.arguments as? Map<*, *>
                        syncSerenMediaSession(args)
                        result.success(true)
                    }
                    "clearMediaSession" -> {
                        clearSerenMediaSession()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        registerAudioRouteDisconnectListeners()
        registerMediaTransportReceiver()
    }

    private fun isExternalOutputDeviceType(type: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return when (type) {
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_ACCESSORY,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
            AudioDeviceInfo.TYPE_AUX_LINE -> true
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_HEARING_AID -> true
            else -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    type == AudioDeviceInfo.TYPE_BLE_SPEAKER ||
                    type == AudioDeviceInfo.TYPE_BLE_BROADCAST
            } else {
                false
            }
        }
    }

    private fun classifyExternalRouteType(type: Int): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "unknown"
        return when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
            else -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    type == AudioDeviceInfo.TYPE_BLE_SPEAKER ||
                    type == AudioDeviceInfo.TYPE_BLE_BROADCAST)
            ) {
                "bluetooth"
            } else if (isExternalOutputDeviceType(type)) {
                "wired"
            } else {
                "unknown"
            }
        }
    }

    private fun hasExternalAudioOutputConnected(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val am = audioManager ?: (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)
        audioManager = am
        val outputs = am?.getDevices(AudioManager.GET_DEVICES_OUTPUTS) ?: return false
        return outputs.any { it.isSink && isExternalOutputDeviceType(it.type) }
    }

    private fun emitAudioRouteDisconnected(
        reason: String,
        routeType: String,
        deviceName: String? = null
    ) {
        val now = System.currentTimeMillis()
        if (now - lastAudioRouteDisconnectMs < 400L) {
            return
        }
        lastAudioRouteDisconnectMs = now
        runOnUiThread {
            ttsChannel?.invokeMethod(
                "onAudioRouteDisconnected",
                mapOf(
                    "reason" to reason,
                    "routeType" to routeType,
                    "deviceName" to deviceName
                )
            )
        }
    }

    private fun registerAudioRouteDisconnectListeners() {
        unregisterAudioRouteDisconnectListeners()
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        audioManager = am

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                    emitAudioRouteDisconnected(
                        reason = "becoming_noisy",
                        routeType = "unknown",
                        deviceName = null
                    )
                }
            }
        }
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        becomingNoisyReceiver = receiver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val callback = object : AudioDeviceCallback() {
                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    val external = removedDevices?.firstOrNull {
                        it.isSink && isExternalOutputDeviceType(it.type)
                    } ?: return
                    emitAudioRouteDisconnected(
                        reason = "device_removed",
                        routeType = classifyExternalRouteType(external.type),
                        deviceName = external.productName?.toString()
                    )
                }
            }
            am.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
            audioDeviceCallback = callback
        }
    }

    private fun unregisterAudioRouteDisconnectListeners() {
        becomingNoisyReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {}
        }
        becomingNoisyReceiver = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioDeviceCallback?.let { callback ->
                try {
                    audioManager?.unregisterAudioDeviceCallback(callback)
                } catch (_: Exception) {}
            }
        }
        audioDeviceCallback = null
    }

    private fun ensureSerenMediaSession(): MediaSession {
        serenMediaSession?.let { return it }
        val session = MediaSession(applicationContext, "NestinSerenMediaSession")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                emitMediaTransportAction("play")
            }

            override fun onPause() {
                emitMediaTransportAction("pause")
            }

            override fun onStop() {
                emitMediaTransportAction("stop")
            }

            override fun onSkipToNext() {
                emitMediaTransportAction("next")
            }

            override fun onSkipToPrevious() {
                emitMediaTransportAction("previous")
            }

            override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                val keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                }
                if (keyEvent != null && keyEvent.action == KeyEvent.ACTION_DOWN) {
                    when (keyEvent.keyCode) {
                        KeyEvent.KEYCODE_MEDIA_PLAY -> {
                            emitMediaTransportAction("play")
                            return true
                        }
                        KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                            emitMediaTransportAction("pause")
                            return true
                        }
                        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                        KeyEvent.KEYCODE_HEADSETHOOK -> {
                            emitMediaTransportAction("togglePlayPause")
                            return true
                        }
                        KeyEvent.KEYCODE_MEDIA_STOP -> {
                            emitMediaTransportAction("stop")
                            return true
                        }
                        KeyEvent.KEYCODE_MEDIA_NEXT -> {
                            emitMediaTransportAction("next")
                            return true
                        }
                        KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                            emitMediaTransportAction("previous")
                            return true
                        }
                    }
                }
                return super.onMediaButtonEvent(mediaButtonIntent)
            }
        })
        serenMediaSession = session
        return session
    }

    private fun emitMediaTransportAction(action: String) {
        runOnUiThread {
            ttsChannel?.invokeMethod(
                "onMediaTransportAction",
                mapOf("action" to action)
            )
        }
    }

    private fun registerMediaTransportReceiver() {
        unregisterMediaTransportReceiver()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_SEREN_MEDIA_PLAY_PAUSE -> emitMediaTransportAction("togglePlayPause")
                    ACTION_SEREN_MEDIA_STOP -> emitMediaTransportAction("stop")
                    ACTION_SEREN_MEDIA_NEXT -> emitMediaTransportAction("next")
                    ACTION_SEREN_MEDIA_PREV -> emitMediaTransportAction("previous")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_SEREN_MEDIA_PLAY_PAUSE)
            addAction(ACTION_SEREN_MEDIA_STOP)
            addAction(ACTION_SEREN_MEDIA_NEXT)
            addAction(ACTION_SEREN_MEDIA_PREV)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        mediaActionReceiver = receiver
    }

    private fun unregisterMediaTransportReceiver() {
        mediaActionReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {}
        }
        mediaActionReceiver = null
    }

    private fun syncSerenMediaSession(args: Map<*, *>?) {
        val isActive = args?.get("isActive") as? Boolean ?: false
        if (!isActive) {
            clearSerenMediaSession()
            return
        }

        val isPlaying = args?.get("isPlaying") as? Boolean ?: false
        val title = args?.get("title") as? String ?: "Seren Daily Relaxation"
        val subtitle = args?.get("subtitle") as? String ?: "Peaceful Ambient Soundscape"
        val album = args?.get("album") as? String ?: "Nestin • Seren Sanctuary"
        val timerRemainingSeconds = (args?.get("timerRemainingSeconds") as? Number)?.toInt() ?: 0
        val timerTotalSeconds = (args?.get("timerTotalSeconds") as? Number)?.toInt() ?: 0
        val timerBadge = args?.get("timerBadge") as? String ?: ""
        val playLabel = args?.get("playActionLabel") as? String ?: "Play"
        val pauseLabel = args?.get("pauseActionLabel") as? String ?: "Pause"
        val stopLabel = args?.get("stopActionLabel") as? String ?: "Stop"

        val session = ensureSerenMediaSession()
        session.isActive = true

        val artBitmap = BitmapFactory.decodeResource(resources, R.drawable.mascot_widget_seren_you_go)
            ?: BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)

        val metadataBuilder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(
                MediaMetadata.METADATA_KEY_ARTIST,
                if (timerBadge.isNotEmpty()) "$subtitle • $timerBadge" else subtitle
            )
            .putString(MediaMetadata.METADATA_KEY_ALBUM, album)
            .putLong(
                MediaMetadata.METADATA_KEY_DURATION,
                if (timerTotalSeconds > 0) timerTotalSeconds * 1000L else -1L
            )
        if (artBitmap != null) {
            metadataBuilder.putBitmap(MediaMetadata.METADATA_KEY_ART, artBitmap)
            metadataBuilder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, artBitmap)
        }
        session.setMetadata(metadataBuilder.build())

        val elapsedMs = if (timerTotalSeconds > 0) {
            (timerTotalSeconds - timerRemainingSeconds).coerceAtLeast(0) * 1000L
        } else {
            PlaybackState.PLAYBACK_POSITION_UNKNOWN
        }
        val playbackActions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS

        val stateBuilder = PlaybackState.Builder()
            .setActions(playbackActions)
            .setState(
                if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                elapsedMs,
                if (isPlaying) 1.0f else 0.0f
            )
        session.setPlaybackState(stateBuilder.build())

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SEREN_MEDIA_CHANNEL_ID,
                "Seren Relaxation Media Controls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Lock-screen and headphone controls for Seren soundscapes and stories"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(channel)
        }

        val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val contentIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("nestin://seren")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPending = PendingIntent.getActivity(this, 7260, contentIntent, immutableFlag)

        fun actionPending(actionName: String, reqCode: Int): PendingIntent {
            val intent = Intent(actionName).setPackage(packageName)
            return PendingIntent.getBroadcast(this, reqCode, intent, immutableFlag)
        }

        val prevPending = actionPending(ACTION_SEREN_MEDIA_PREV, 7261)
        val playPausePending = actionPending(ACTION_SEREN_MEDIA_PLAY_PAUSE, 7262)
        val stopPending = actionPending(ACTION_SEREN_MEDIA_STOP, 7263)
        val nextPending = actionPending(ACTION_SEREN_MEDIA_NEXT, 7264)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, SEREN_MEDIA_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val subText = if (timerBadge.isNotEmpty()) timerBadge else album
        builder
            .setSmallIcon(R.drawable.ic_widget_water)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setSubText(subText)
            .setContentIntent(contentPending)
            .setDeleteIntent(stopPending)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous,
                    "Prev",
                    prevPending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (isPlaying) pauseLabel else playLabel,
                    playPausePending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    stopLabel,
                    stopPending
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next,
                    "Next",
                    nextPending
                ).build()
            )
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(1, 2)
            )

        if (artBitmap != null) {
            builder.setLargeIcon(artBitmap)
        }

        try {
            nm.notify(SEREN_MEDIA_NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Safely ignored if POST_NOTIFICATIONS permission is not yet granted on Android 13+
        }
    }

    private fun clearSerenMediaSession() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(SEREN_MEDIA_NOTIFICATION_ID)
        } catch (_: Exception) {}
        serenMediaSession?.let { session ->
            try {
                session.isActive = false
            } catch (_: Exception) {}
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
        unregisterAudioRouteDisconnectListeners()
        unregisterMediaTransportReceiver()
        clearSerenMediaSession()
        serenMediaSession?.release()
        serenMediaSession = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        geofencingPlugin?.dispose()
        dailyWallpaperPlugin?.dispose()
        super.onDestroy()
    }
}
