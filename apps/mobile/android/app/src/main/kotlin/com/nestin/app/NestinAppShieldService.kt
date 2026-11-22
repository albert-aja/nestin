package com.nestin.app

import android.accessibilityservice.AccessibilityService
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Play-policy transparent AccessibilityService for Shared Device Integration
 * (enforcing both Roo Digital Discipline policies and Seren's Break the Cycle — Mindful App Pause).
 *
 * Strictly listens only to foreground window transitions (`TYPE_WINDOW_STATE_CHANGED`)
 * with `canRetrieveWindowContent="false"` — never inspects screen text, passwords,
 * URLs, or keystrokes. Always preserves emergency calling, dialers, system UI, and Nestin.
 */
class NestinAppShieldService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "nestin_restriction_policy"
        const val KEY_POLICIES_JSON = "policies_json"
        const val KEY_FOCUS_EXPIRES_AT_MS = "focus_expires_at_ms"
        const val KEY_GRACE_PREFIX = "grace_"
        const val REMINDER_GRACE_MS = 5 * 60 * 1000L

        const val KEY_BTC_MINDFUL_PAUSE_JSON = "btc_mindful_pause_json"
        const val KEY_BTC_GRACE_PREFIX = "btc_grace_"
        const val KEY_BTC_SNOOZED_UNTIL_MS = "btc_snoozed_until_ms"
        const val KEY_BTC_STEP_BACK_COUNT = "btc_step_back_count"

        private const val SHIELD_NOTIF_CHANNEL_ID = "nestin_app_shield_alert_channel"
        private const val SHIELD_NOTIF_ID = 9410

        @Volatile
        private var lastHandledPackage: String? = null

        @Volatile
        private var lastHandledAtMs: Long = 0L

        private val ESSENTIAL_PACKAGES = setOf(
            "com.android.dialer",
            "com.google.android.dialer",
            "com.samsung.android.dialer",
            "com.android.server.telecom",
            "com.android.phone",
            "com.android.emergency",
            "com.android.incallui",
            "com.android.settings",
            "com.android.systemui",
            "com.android.permissioncontroller",
            "com.google.android.permissioncontroller"
        )

        fun isEssentialPackage(pkg: String, hostPkg: String): Boolean {
            val lower = pkg.lowercase()
            if (lower.isBlank()) return true
            if (lower == hostPkg.lowercase()) return true
            if (ESSENTIAL_PACKAGES.contains(lower)) return true
            if (lower.contains("emergency") || lower.contains("telecom") || lower.endsWith(".dialer")) {
                return true
            }
            if (lower.contains("inputmethod") || lower.endsWith("launcher") || lower.contains(".launcher")) {
                return true
            }
            return false
        }

        /**
         * Shared real-time interceptor invoked by both [NestinAppShieldService] (Accessibility)
         * and [DeviceControlPlugin]'s background UsageStats foreground watcher.
         */
        fun interceptPackageIfNeeded(
            context: Context,
            pkg: String,
            fromAccessibility: Boolean = false
        ): Boolean {
            val appCtx = context.applicationContext
            if (isEssentialPackage(pkg, appCtx.packageName)) return false

            val now = System.currentTimeMillis()
            if (pkg == lastHandledPackage && (now - lastHandledAtMs) < 1200L) {
                return false
            }

            val prefs = appCtx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val matched = findActiveInterventionForPackage(appCtx, prefs, pkg, now) ?: return false

            lastHandledPackage = pkg
            lastHandledAtMs = now

            val canContinue = matched.optBoolean("canContinue", true)
            val appName = matched.optString("appName", pkg)
            val interventionKind = matched.optString("interventionKind", "roo_discipline")
            val sourceLabel = matched.optString("sourceLabel", "Roo Digital Discipline")
            val title = matched.optString("title", "App Paused")
            val reason = matched.optString("reason", "Mindful pause is active for this app.")
            val motivation = matched.optString("motivation", "")
            val pauseSeconds = matched.optInt("pauseDurationSeconds", 0)
            val graceMinutes = matched.optInt("cooldownGraceMinutes", 5)

            val intent = Intent(appCtx, NestinShieldActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra(NestinShieldActivity.EXTRA_PACKAGE_NAME, pkg)
                putExtra(NestinShieldActivity.EXTRA_APP_NAME, appName)
                putExtra(NestinShieldActivity.EXTRA_INTERVENTION_KIND, interventionKind)
                putExtra(NestinShieldActivity.EXTRA_SOURCE_LABEL, sourceLabel)
                putExtra(NestinShieldActivity.EXTRA_TITLE, title)
                putExtra(NestinShieldActivity.EXTRA_REASON, reason)
                putExtra(NestinShieldActivity.EXTRA_MOTIVATION, motivation)
                putExtra(NestinShieldActivity.EXTRA_CAN_CONTINUE, canContinue)
                putExtra(NestinShieldActivity.EXTRA_PAUSE_SECONDS, pauseSeconds)
                putExtra(NestinShieldActivity.EXTRA_GRACE_MINUTES, graceMinutes)
            }

            try {
                appCtx.startActivity(intent)
            } catch (_: Exception) {
                // Handled by full-screen notification fallback below
            }

            val canDrawOverlays = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(appCtx)
            } else {
                true
            }
            if (!fromAccessibility && !canDrawOverlays) {
                postHeadsUpShieldNotification(appCtx, intent, appName, title, reason, motivation)
            }
            return true
        }

        private fun findActiveInterventionForPackage(
            context: Context,
            prefs: android.content.SharedPreferences,
            pkg: String,
            nowMs: Long
        ): JSONObject? {
            val rooRaw = prefs.getString(KEY_POLICIES_JSON, null)
            val rooMatch = if (!rooRaw.isNullOrBlank()) {
                findActiveRooPolicy(rooRaw, prefs, pkg, nowMs)
            } else {
                null
            }

            // If Roo has a strict non-bypassable policy, Roo strict takes highest precedence
            if (rooMatch != null && !rooMatch.optBoolean("canContinue", true)) {
                return rooMatch
            }

            val btcRaw = prefs.getString(KEY_BTC_MINDFUL_PAUSE_JSON, null)
            val btcMatch = if (!btcRaw.isNullOrBlank()) {
                findActiveBtcMindfulPause(context, btcRaw, prefs, pkg, nowMs)
            } else {
                null
            }

            if (btcMatch != null) {
                return btcMatch
            }
            return rooMatch
        }

        private fun findActiveRooPolicy(
            rawJson: String,
            prefs: android.content.SharedPreferences,
            pkg: String,
            nowMs: Long
        ): JSONObject? {
            return try {
                val arr = JSONArray(rawJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    if (obj.optString("packageName") != pkg) continue
                    val expiresAtMs = obj.optLong("expiresAtMs", 0L)
                    if (expiresAtMs > 0L && nowMs >= expiresAtMs) {
                        continue
                    }
                    val canContinue = obj.optBoolean("canContinue", true)
                    if (canContinue) {
                        val graceUntil = prefs.getLong("$KEY_GRACE_PREFIX$pkg", 0L)
                        if (nowMs < graceUntil) {
                            continue
                        }
                    }
                    return JSONObject(obj.toString()).apply {
                        put("interventionKind", "roo_discipline")
                        put("pauseDurationSeconds", 0)
                        put("cooldownGraceMinutes", 5)
                    }
                }
                null
            } catch (_: Exception) {
                null
            }
        }

        private fun findActiveBtcMindfulPause(
            context: Context,
            rawJson: String,
            prefs: android.content.SharedPreferences,
            pkg: String,
            nowMs: Long
        ): JSONObject? {
            return try {
                val cfg = JSONObject(rawJson)
                if (!cfg.optBoolean("isEnabled", false)) return null

                val pkgsArr = cfg.optJSONArray("monitoredPackages") ?: return null
                var isMonitored = false
                for (i in 0 until pkgsArr.length()) {
                    if (pkgsArr.optString(i) == pkg) {
                        isMonitored = true
                        break
                    }
                }
                if (!isMonitored) return null

                val configSnooze = cfg.optLong("snoozedUntilMs", 0L)
                val nativeSnooze = prefs.getLong(KEY_BTC_SNOOZED_UNTIL_MS, 0L)
                val effectiveSnooze = maxOf(configSnooze, nativeSnooze)
                if (effectiveSnooze > 0L && nowMs < effectiveSnooze) {
                    return null
                }

                if (cfg.optBoolean("vulnerableHoursOnly", false)) {
                    val startHour = cfg.optInt("vulnerableStartHour", 22).coerceIn(0, 23)
                    val endHour = cfg.optInt("vulnerableEndHour", 6).coerceIn(0, 23)
                    val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                    val withinWindow = if (startHour == endHour) {
                        true
                    } else if (startHour > endHour) {
                        currentHour >= startHour || currentHour < endHour
                    } else {
                        currentHour in startHour until endHour
                    }
                    if (!withinWindow) return null
                }

                val strictBlockMode = cfg.optBoolean("strictBlockMode", false)
                if (!strictBlockMode) {
                    val graceUntil = prefs.getLong("$KEY_BTC_GRACE_PREFIX$pkg", 0L)
                    if (nowMs < graceUntil) {
                        return null
                    }
                }

                val namesObj = cfg.optJSONObject("monitoredAppNames")
                val resolvedName = namesObj?.optString(pkg)?.takeIf { it.isNotBlank() }
                    ?: resolvePackageLabel(context, pkg)
                val pauseSecs = cfg.optInt("pauseDurationSeconds", 4).coerceIn(3, 5)
                val graceMins = cfg.optInt("cooldownGraceMinutes", 15).coerceIn(1, 180)
                val myWhy = cfg.optString(
                    "myWhy",
                    "You chose to pause and check in with yourself before opening this app."
                )

                JSONObject().apply {
                    put("packageName", pkg)
                    put("appName", resolvedName)
                    put("interventionKind", "btc_mindful_pause")
                    put("sourceLabel", "Break the Cycle • Mindful App Pause")
                    put(
                        "title",
                        if (strictBlockMode) "Strict App Pause Active" else "Mindful Pause Check-In"
                    )
                    put(
                        "reason",
                        "Take one gentle breath before stepping in. Does opening this right now support how you want to feel?"
                    )
                    put("motivation", myWhy)
                    put("canContinue", !strictBlockMode)
                    put("pauseDurationSeconds", if (strictBlockMode) 0 else pauseSecs)
                    put("cooldownGraceMinutes", graceMins)
                }
            } catch (_: Exception) {
                null
            }
        }

        private fun resolvePackageLabel(context: Context, pkg: String): String {
            return try {
                val pm = context.packageManager
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (_: Exception) {
                pkg
            }
        }

        private fun postHeadsUpShieldNotification(
            context: Context,
            shieldIntent: Intent,
            appName: String,
            title: String,
            reason: String,
            motivation: String
        ) {
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        SHIELD_NOTIF_CHANNEL_ID,
                        "Nestin Mindful App Pause & Shield Alerts",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Immediate warning when opening an app paused in Break the Cycle or Roo Digital Discipline"
                    }
                    nm.createNotificationChannel(channel)
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pending = PendingIntent.getActivity(context, SHIELD_NOTIF_ID, shieldIntent, flags)
                val bodyText = if (motivation.isNotBlank()) {
                    "$reason\nRemember your Why: “$motivation”"
                } else {
                    reason
                }
                val notif = NotificationCompat.Builder(context, SHIELD_NOTIF_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle("$appName is paused • $title")
                    .setContentText(bodyText)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .setContentIntent(pending)
                    .setFullScreenIntent(pending, true)
                    .build()
                nm.notify(SHIELD_NOTIF_ID, notif)
            } catch (_: Exception) {}
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }
        val pkg = event.packageName?.toString()?.trim() ?: return
        interceptPackageIfNeeded(applicationContext, pkg, fromAccessibility = true)
    }

    override fun onInterrupt() {
        // Nothing sensitive held in memory.
    }
}
