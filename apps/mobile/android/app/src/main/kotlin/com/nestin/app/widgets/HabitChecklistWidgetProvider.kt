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

class HabitChecklistWidgetProvider : AppWidgetProvider() {

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
        const val KEY_TITLE = "habits_title"
        const val KEY_STREAK = "habits_streak"
        const val KEY_PROGRESS = "habits_progress"
        const val KEY_STEP_PREFIX = "habits_step_"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val title = prefs.getString(KEY_TITLE, "Daily Habits & Routines") ?: "Daily Habits & Routines"
            val streak = prefs.getString(KEY_STREAK, "🔥 3d") ?: "🔥 3d"
            val progress = prefs.getString(KEY_PROGRESS, "0/0") ?: "0/0"

            val views = RemoteViews(context.packageName, R.layout.widget_habit_checklist)
            views.setTextViewText(R.id.tv_habit_title, title)
            views.setTextViewText(R.id.tv_habit_streak, streak)
            views.setTextViewText(R.id.tv_habit_progress, progress)

            val stepLayoutIds = intArrayOf(
                R.id.layout_step_1,
                R.id.layout_step_2,
                R.id.layout_step_3,
                R.id.layout_step_4
            )
            val stepIvIds = intArrayOf(
                R.id.iv_step_1,
                R.id.iv_step_2,
                R.id.iv_step_3,
                R.id.iv_step_4
            )
            val stepTvIds = intArrayOf(
                R.id.tv_step_1,
                R.id.tv_step_2,
                R.id.tv_step_3,
                R.id.tv_step_4
            )

            for (i in 0 until 4) {
                val stepIdx = i + 1
                val stepText = prefs.getString("${KEY_STEP_PREFIX}${stepIdx}_text", null)
                val isDone = prefs.getBoolean("${KEY_STEP_PREFIX}${stepIdx}_done", false)

                if (stepText != null && stepText.isNotEmpty()) {
                    views.setViewVisibility(stepLayoutIds[i], View.VISIBLE)
                    views.setTextViewText(stepTvIds[i], stepText)
                    if (isDone) {
                        views.setImageViewResource(stepIvIds[i], R.drawable.ic_widget_check)
                        views.setTextColor(stepTvIds[i], 0xFF9CA3AF.toInt())
                    } else {
                        views.setImageViewResource(stepIvIds[i], R.drawable.ic_widget_uncheck)
                        views.setTextColor(stepTvIds[i], 0xFFE5E7EB.toInt())
                    }
                } else {
                    views.setViewVisibility(stepLayoutIds[i], View.GONE)
                }
            }

            // Tap whole card to open habits
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("nestin://habits")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                1002,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_habit_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, HabitChecklistWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}

