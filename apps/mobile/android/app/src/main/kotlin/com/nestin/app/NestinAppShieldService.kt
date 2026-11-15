package com.nestin.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray
import org.json.JSONObject

/**
 * Play-policy transparent AccessibilityService for Shared Device Integration (enforcing Roo Digital Discipline policies).
 *
 * Strictly listens only to foreground window transitions (`TYPE_WINDOW_STATE_CHANGED`)
 * with `canRetrieveWindowContent="false"` — never inspects screen text, passwords,
 * or keystrokes. Always preserves emergency calling, dialers, system UI, and Nestin.
 */
class NestinAppShieldService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "nestin_restriction_policy"
        const val KEY_POLICIES_JSON = "policies_json"
        const val KEY_FOCUS_EXPIRES_AT_MS = "focus_expires_at_ms"
        const val KEY_GRACE_PREFIX = "grace_"
        const val REMINDER_GRACE_MS = 5 * 60 * 1000L

        private val ESSENTIAL_PACKAGES = setOf(
            "com.android.dialer",
            "com.google.android.dialer",
            "com.samsung.android.dialer",
            "com.android.server.telecom",
            "com.android.phone",
            "com.android.emergency",
            "com.android.incallui",
            "com.android.settings",
            "com.android.systemui"
        )

        fun isEssentialPackage(pkg: String, hostPkg: String): Boolean {
            val lower = pkg.lowercase()
            if (lower.isBlank()) return true
            if (lower == hostPkg.lowercase()) return true
            if (ESSENTIAL_PACKAGES.contains(lower)) return true
            if (lower.contains("emergency") || lower.contains("telecom") || lower.endsWith(".dialer")) {
                return true
            }
            if (lower.contains("inputmethod") || lower.endsWith("launcher")) {
                return true
            }
            return false
        }
    }

    private var lastHandledPackage: String? = null
    private var lastHandledAtMs: Long = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }
        val pkg = event.packageName?.toString()?.trim() ?: return
        if (isEssentialPackage(pkg, applicationContext.packageName)) return

        val now = System.currentTimeMillis()
        // Debounce repeated window events within 900ms for same package
        if (pkg == lastHandledPackage && (now - lastHandledAtMs) < 900L) {
            return
        }

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(KEY_POLICIES_JSON, null) ?: return
        val matched = findActivePolicyForPackage(rawJson, pkg, now) ?: return

        val canContinue = matched.optBoolean("canContinue", true)
        if (canContinue) {
            val graceUntil = prefs.getLong("$KEY_GRACE_PREFIX$pkg", 0L)
            if (now < graceUntil) {
                return
            }
        }

        lastHandledPackage = pkg
        lastHandledAtMs = now

        val intent = Intent(this, NestinShieldActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(NestinShieldActivity.EXTRA_PACKAGE_NAME, pkg)
            putExtra(NestinShieldActivity.EXTRA_APP_NAME, matched.optString("appName", pkg))
            putExtra(NestinShieldActivity.EXTRA_SOURCE_LABEL, matched.optString("sourceLabel", "Roo Digital Discipline"))
            putExtra(NestinShieldActivity.EXTRA_TITLE, matched.optString("title", "App Restricted"))
            putExtra(NestinShieldActivity.EXTRA_REASON, matched.optString("reason", "Restriction active."))
            putExtra(NestinShieldActivity.EXTRA_MOTIVATION, matched.optString("motivation", ""))
            putExtra(NestinShieldActivity.EXTRA_CAN_CONTINUE, canContinue)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        // Nothing sensitive held in memory.
    }

    private fun findActivePolicyForPackage(rawJson: String, pkg: String, nowMs: Long): JSONObject? {
        return try {
            val arr = JSONArray(rawJson)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                if (obj.optString("packageName") != pkg) continue
                val expiresAtMs = obj.optLong("expiresAtMs", 0L)
                // Crash/reboot safety guard: expired time-bound rules stop enforcing automatically.
                if (expiresAtMs > 0L && nowMs >= expiresAtMs) {
                    continue
                }
                return obj
            }
            null
        } catch (_: Exception) {
            null
        }
    }
}
