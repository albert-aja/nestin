package com.nestin.app.widgets

import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.nestin.app.MainActivity
import com.nestin.app.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HydrationWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_ADD_GLASS) {
            logOneGlassFromWidget(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    data class HydrationSnapshot(
        val glasses: Int,
        val goal: Int,
        val lastDate: String,
        val mascotPose: String,
    )

    companion object {
        const val PREFS_NAME = "NestinWidgets"
        const val ACTION_ADD_GLASS = "com.nestin.app.widgets.ACTION_HYDRATION_ADD_GLASS"

        const val KEY_GLASSES = "hydration_glasses"
        const val KEY_GOAL = "hydration_goal"
        const val KEY_LAST_DATE = "hydration_last_date"
        const val KEY_MASCOT_POSE = "hydration_mascot_pose"

        private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        private const val FLUTTER_KEY_HYDRATION = "flutter.nestin_hydration_data_v1"
        private const val BASE_HYDRATION_NOTIFICATION_ID = 7100
        private const val INSTANT_HYDRATION_NOTIFICATION_ID = 7099
        private const val MAX_HYDRATION_SLOTS = 20

        @Volatile
        var onWidgetLoggedGlassListener: (() -> Unit)? = null

        private fun todayKey(): String {
            return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        }

        fun resolveMascotPose(glasses: Int, goal: Int): String {
            val safeGoal = goal.coerceAtLeast(1)
            return when {
                glasses >= safeGoal -> "seren_refreshed"
                glasses * 2 >= safeGoal -> "seren_you_go"
                else -> "seren_hydrate"
            }
        }

        fun resolveMascotDrawable(poseKey: String): Int {
            return when (poseKey) {
                "seren_refreshed" -> R.drawable.mascot_widget_seren_refreshed
                "seren_you_go" -> R.drawable.mascot_widget_seren_you_go
                else -> R.drawable.mascot_widget_seren_hydrate
            }
        }

        private fun buildDefaultFlutterJson(today: String): JSONObject {
            return JSONObject().apply {
                put("glassesConsumed", 0)
                put("dailyGoalGlasses", 8)
                put("remindersEnabled", true)
                put("reminderIntervalMinutes", 90)
                put("startHour", 8)
                put("endHour", 21)
                put("lastLoggedDate", today)
                put("dailyHistory", JSONObject())
            }
        }

        private fun applyDailyRollover(obj: JSONObject, today: String) {
            val prevDate = obj.optString("lastLoggedDate", today).ifBlank { today }
            if (prevDate != today) {
                val prevGlasses = obj.optInt("glassesConsumed", 0).coerceAtLeast(0)
                val history = obj.optJSONObject("dailyHistory") ?: JSONObject()
                history.put(prevDate, prevGlasses)
                if (!history.has(today)) {
                    history.put(today, 0)
                }
                obj.put("glassesConsumed", 0)
                obj.put("lastLoggedDate", today)
                obj.put("dailyHistory", history)
            }
        }

        private fun writeWidgetCache(context: Context, snapshot: HydrationSnapshot) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
                putInt(KEY_GLASSES, snapshot.glasses)
                putInt(KEY_GOAL, snapshot.goal)
                putString(KEY_LAST_DATE, snapshot.lastDate)
                putString(KEY_MASCOT_POSE, snapshot.mascotPose)
                commit()
            }
        }

        private fun dismissActiveHydrationNotifications(context: Context) {
            try {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        ?: return
                manager.cancel(INSTANT_HYDRATION_NOTIFICATION_ID)
                for (i in 0 until MAX_HYDRATION_SLOTS) {
                    manager.cancel(BASE_HYDRATION_NOTIFICATION_ID + i)
                }
            } catch (_: Exception) {
            }
        }

        fun logOneGlassFromWidget(context: Context) {
            val reachedGoalNow: Boolean
            synchronized(this) {
                val today = todayKey()
                val flutterPrefs = context.getSharedPreferences(
                    FLUTTER_PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                val raw = flutterPrefs.getString(FLUTTER_KEY_HYDRATION, null)
                val obj = try {
                    if (raw.isNullOrBlank()) buildDefaultFlutterJson(today) else JSONObject(raw)
                } catch (_: Exception) {
                    buildDefaultFlutterJson(today)
                }

                applyDailyRollover(obj, today)

                val goal = obj.optInt("dailyGoalGlasses", 8).coerceIn(1, 20)
                val current = obj.optInt("glassesConsumed", 0).coerceAtLeast(0)
                val previouslyMet = current >= goal
                val next = current + 1

                val history = obj.optJSONObject("dailyHistory") ?: JSONObject()
                history.put(today, next)
                obj.put("dailyGoalGlasses", goal)
                obj.put("glassesConsumed", next)
                obj.put("lastLoggedDate", today)
                obj.put("dailyHistory", history)

                flutterPrefs.edit().putString(FLUTTER_KEY_HYDRATION, obj.toString()).commit()

                val pose = resolveMascotPose(next, goal)
                writeWidgetCache(context, HydrationSnapshot(next, goal, today, pose))
                reachedGoalNow = !previouslyMet && next >= goal
            }

            if (reachedGoalNow) {
                dismissActiveHydrationNotifications(context)
            }
            updateAll(context)
            onWidgetLoggedGlassListener?.invoke()
        }

        private fun readSnapshot(context: Context): HydrationSnapshot {
            val today = todayKey()
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.contains(KEY_GLASSES) && prefs.contains(KEY_GOAL)) {
                val cachedDate = prefs.getString(KEY_LAST_DATE, today) ?: today
                val goal = prefs.getInt(KEY_GOAL, 8).coerceIn(1, 20)
                val glasses = if (cachedDate == today) {
                    prefs.getInt(KEY_GLASSES, 0).coerceAtLeast(0)
                } else {
                    0
                }
                val pose = resolveMascotPose(glasses, goal)
                if (cachedDate != today) {
                    writeWidgetCache(context, HydrationSnapshot(0, goal, today, pose))
                }
                return HydrationSnapshot(glasses, goal, today, pose)
            }

            // Fallback to Flutter's persisted JSON when widget is placed before first Dart sync
            val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val raw = flutterPrefs.getString(FLUTTER_KEY_HYDRATION, null)
            return try {
                if (raw.isNullOrBlank()) {
                    HydrationSnapshot(0, 8, today, resolveMascotPose(0, 8))
                } else {
                    val obj = JSONObject(raw)
                    val goal = obj.optInt("dailyGoalGlasses", 8).coerceIn(1, 20)
                    val lastDate = obj.optString("lastLoggedDate", today)
                    val glasses = if (lastDate == today) {
                        obj.optInt("glassesConsumed", 0).coerceAtLeast(0)
                    } else {
                        0
                    }
                    HydrationSnapshot(glasses, goal, today, resolveMascotPose(glasses, goal))
                }
            } catch (_: Exception) {
                HydrationSnapshot(0, 8, today, resolveMascotPose(0, 8))
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val snapshot = readSnapshot(context)
            val widgetPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val showMascots = widgetPrefs.getBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, true)

            val glasses = snapshot.glasses
            val goal = snapshot.goal
            val currentMl = glasses * 250
            val targetMl = goal * 250
            val pct = ((glasses.toFloat() / goal.toFloat()) * 100f).toInt().coerceIn(0, 100)
            val isGoalMet = glasses >= goal

            val views = RemoteViews(context.packageName, R.layout.widget_hydration)
            views.setTextViewText(R.id.tv_hydration_glasses, "$glasses/$goal")
            views.setTextViewText(R.id.tv_hydration_ml, "${currentMl}ml / ${targetMl}ml target")

            if (isGoalMet) {
                views.setTextViewText(R.id.tv_hydration_status, "Goal Met")
                views.setTextColor(R.id.tv_hydration_status, 0xFF10B981.toInt())
                views.setInt(
                    R.id.tv_hydration_status,
                    "setBackgroundResource",
                    R.drawable.widget_pill_hydration_done_bg
                )
                views.setViewVisibility(R.id.pb_hydration_progress, View.GONE)
                views.setViewVisibility(R.id.pb_hydration_progress_done, View.VISIBLE)
                views.setProgressBar(R.id.pb_hydration_progress_done, goal, goal, false)
            } else {
                views.setTextViewText(R.id.tv_hydration_status, "$pct%")
                views.setTextColor(R.id.tv_hydration_status, 0xFF38BDF8.toInt())
                views.setInt(
                    R.id.tv_hydration_status,
                    "setBackgroundResource",
                    R.drawable.widget_pill_hydration_bg
                )
                views.setViewVisibility(R.id.pb_hydration_progress, View.VISIBLE)
                views.setViewVisibility(R.id.pb_hydration_progress_done, View.GONE)
                views.setProgressBar(R.id.pb_hydration_progress, goal, glasses.coerceAtMost(goal), false)
            }

            if (showMascots) {
                views.setViewVisibility(R.id.layout_hydration_mascot_badge, View.VISIBLE)
                views.setImageViewResource(
                    R.id.iv_hydration_mascot,
                    resolveMascotDrawable(snapshot.mascotPose)
                )
            } else {
                views.setViewVisibility(R.id.layout_hydration_mascot_badge, View.GONE)
            }

            // Quick +1 Glass Broadcast Action: logs directly without launching MainActivity
            val addGlassIntent = Intent(context, HydrationWidgetProvider::class.java).apply {
                action = ACTION_ADD_GLASS
            }
            val addGlassPendingIntent = PendingIntent.getBroadcast(
                context,
                1003,
                addGlassIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_hydration_add_glass, addGlassPendingIntent)

            // Tap card body to open Hydration settings sheet in Nestin
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("nestin://hydration")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                1004,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_hydration_root, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, HydrationWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}
