package com.nestin.app.oem

import android.content.Context
import com.nestin.app.services.NestinKeepAliveService
import com.nestin.app.services.NestinKeepAliveTileService
import org.json.JSONObject

/**
 * Coordinates Keep-Alive Guard state across native Android Quick Settings
 * (`NestinKeepAliveTileService`), `NestinKeepAliveService`, and Flutter's
 * `SharedPreferences` config (`flutter.nestin_oem_hardening_v1`).
 */
object KeepAliveGuardState {
    private const val PREFS_NAME = "nestin_oem_guard_prefs"
    private const val KEY_KEEP_ALIVE_ENABLED = "keep_alive_enabled"
    private const val KEY_HAS_EXPLICIT_STATE = "has_explicit_state"
    private const val KEY_TILE_ADDED = "qs_tile_added"

    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_KEY_OEM_CONFIG = "flutter.nestin_oem_hardening_v1"

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_HAS_EXPLICIT_STATE, false)) {
            return prefs.getBoolean(KEY_KEEP_ALIVE_ENABLED, false)
        }
        return readFlutterKeepAliveFlag(context) ?: NestinKeepAliveService.isRunning
    }

    fun isCurrentlyGuarded(context: Context): Boolean {
        return NestinKeepAliveService.isRunning || isEnabled(context)
    }

    fun setEnabled(
        context: Context,
        enabled: Boolean,
        syncFlutterConfig: Boolean = true,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_HAS_EXPLICIT_STATE, true)
            .putBoolean(KEY_KEEP_ALIVE_ENABLED, enabled)
            .apply()

        if (syncFlutterConfig) {
            writeFlutterKeepAliveFlag(context, enabled)
        }
        NestinKeepAliveTileService.requestTileUpdate(context)
    }

    fun syncRuntimeState(context: Context, isRunning: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_HAS_EXPLICIT_STATE, true)
            .putBoolean(KEY_KEEP_ALIVE_ENABLED, isRunning)
            .apply()
        NestinKeepAliveTileService.requestTileUpdate(context)
    }

    fun setTileAdded(context: Context, added: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_TILE_ADDED, added).apply()
    }

    fun isTileAdded(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_TILE_ADDED, false)
    }

    private fun readFlutterKeepAliveFlag(context: Context): Boolean? {
        return try {
            val flutterPrefs = context.getSharedPreferences(
                FLUTTER_PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            val raw = flutterPrefs.getString(FLUTTER_KEY_OEM_CONFIG, null)
            if (raw.isNullOrBlank()) null
            else JSONObject(raw).optBoolean("keepAliveEnabledByUser", false)
        } catch (_: Exception) {
            null
        }
    }

    private fun writeFlutterKeepAliveFlag(context: Context, enabled: Boolean) {
        try {
            val flutterPrefs = context.getSharedPreferences(
                FLUTTER_PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            val raw = flutterPrefs.getString(FLUTTER_KEY_OEM_CONFIG, null)
            val json = if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
            json.put("keepAliveEnabledByUser", enabled)
            if (!json.has("bannerDismissed")) {
                json.put("bannerDismissed", false)
            }
            flutterPrefs.edit()
                .putString(FLUTTER_KEY_OEM_CONFIG, json.toString())
                .apply()
        } catch (_: Exception) {
            // Best-effort sync; native prefs still remain authoritative.
        }
    }
}
