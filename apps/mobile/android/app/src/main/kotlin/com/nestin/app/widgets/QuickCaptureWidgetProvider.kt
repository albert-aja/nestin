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

class QuickCaptureWidgetProvider : AppWidgetProvider() {

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
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                NextAlarmWidgetProvider.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val showMascots = prefs.getBoolean(NextAlarmWidgetProvider.KEY_SHOW_MASCOTS, true)

            val views = RemoteViews(context.packageName, R.layout.widget_quick_capture)

            val mascotContainers = intArrayOf(
                R.id.layout_qc_note_mascot,
                R.id.layout_qc_task_mascot,
                R.id.layout_qc_alarm_mascot,
                R.id.layout_qc_journal_mascot
            )
            val classicIcons = intArrayOf(
                R.id.iv_qc_note_classic,
                R.id.iv_qc_task_classic,
                R.id.iv_qc_alarm_classic,
                R.id.iv_qc_journal_classic
            )

            views.setViewVisibility(
                R.id.btn_qc_scout,
                if (showMascots) View.VISIBLE else View.GONE
            )
            for (containerId in mascotContainers) {
                views.setViewVisibility(containerId, if (showMascots) View.VISIBLE else View.GONE)
            }
            for (iconId in classicIcons) {
                views.setViewVisibility(iconId, if (showMascots) View.GONE else View.VISIBLE)
            }

            fun makePendingIntent(requestCode: Int, uriString: String): PendingIntent {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse(uriString)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                return PendingIntent.getActivity(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }

            views.setOnClickPendingIntent(
                R.id.btn_qc_scout,
                makePendingIntent(2000, "nestin://quick_capture?type=note")
            )
            views.setOnClickPendingIntent(
                R.id.btn_qc_note,
                makePendingIntent(2001, "nestin://quick_capture?type=note")
            )
            views.setOnClickPendingIntent(
                R.id.btn_qc_task,
                makePendingIntent(2002, "nestin://quick_capture?type=task")
            )
            views.setOnClickPendingIntent(
                R.id.btn_qc_alarm,
                makePendingIntent(2003, "nestin://new_alarm")
            )
            views.setOnClickPendingIntent(
                R.id.btn_qc_journal,
                makePendingIntent(2004, "nestin://quick_capture?type=journal")
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, QuickCaptureWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}
