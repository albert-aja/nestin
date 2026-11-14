package com.nestin.app.widgets

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

class NextAlarmWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "NestinWidgets"
        const val KEY_HAS_ALARM = "next_alarm_has_alarm"
        const val KEY_TIME = "next_alarm_time"
        const val KEY_AMPM = "next_alarm_ampm"
        const val KEY_COUNTDOWN = "next_alarm_countdown"
        const val KEY_LABEL = "next_alarm_label"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val hasAlarm = prefs.getBoolean(KEY_HAS_ALARM, true)
            val time = prefs.getString(KEY_TIME, "07:00") ?: "07:00"
            val ampm = prefs.getString(KEY_AMPM, "AM") ?: "AM"
            val countdown = prefs.getString(KEY_COUNTDOWN, "Active") ?: "Active"
            val label = prefs.getString(KEY_LABEL, "Morning Wake Up • Daily") ?: "Morning Wake Up"

            val views = RemoteViews(context.packageName, R.layout.widget_next_alarm)

            if (hasAlarm) {
                views.setTextViewText(R.id.tv_alarm_time, time)
                views.setTextViewText(R.id.tv_alarm_ampm, ampm)
                views.setTextViewText(R.id.tv_alarm_countdown, countdown)
                views.setTextViewText(R.id.tv_alarm_label, label)
                views.setViewVisibility(R.id.tv_alarm_countdown, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.tv_alarm_time, "--:--")
                views.setTextViewText(R.id.tv_alarm_ampm, "")
                views.setTextViewText(R.id.tv_alarm_countdown, "Off")
                views.setTextViewText(R.id.tv_alarm_label, "No upcoming alarms scheduled")
                views.setViewVisibility(R.id.tv_alarm_countdown, View.VISIBLE)
            }

            // PendingIntent to launch app into alarms screen
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("nestin://alarms")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_alarm_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, NextAlarmWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}

