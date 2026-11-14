package com.nestin.app.geofencing

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class GeofencingPlugin(
    private val activity: Activity,
    private val channel: MethodChannel
) {
    companion object {
        const val CHANNEL_NAME = "com.nestin.app/geofencing"
        const val REQ_FOREGROUND_LOCATION = 4201
        const val REQ_BACKGROUND_LOCATION = 4202

        @Volatile
        var activeInstance: GeofencingPlugin? = null
            private set

        fun register(activity: Activity, flutterEngine: FlutterEngine): GeofencingPlugin {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = GeofencingPlugin(activity, channel)
            activeInstance = plugin

            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> {
                        val pm = activity.packageManager
                        result.success(pm.hasSystemFeature(PackageManager.FEATURE_LOCATION))
                    }
                    "checkPermission" -> {
                        result.success(
                            GeofenceRegistry.getPermissionStateString(activity, activity)
                        )
                    }
                    "requestForegroundPermission" -> {
                        plugin.requestForegroundPermission(result)
                    }
                    "requestBackgroundPermission" -> {
                        plugin.requestBackgroundPermission(result)
                    }
                    "openAppLocationSettings" -> {
                        result.success(plugin.openAppLocationSettings())
                    }
                    "getCurrentLocation" -> {
                        plugin.getCurrentLocation(result)
                    }
                    "syncGeofences" -> {
                        val args = call.arguments as? Map<*, *>
                        val rawRegions = args?.get("regions") as? List<*> ?: emptyList<Any>()
                        val typedRegions = rawRegions.mapNotNull { it as? Map<*, *> }
                        val ok = GeofenceRegistry.syncNativeAlerts(activity, typedRegions)
                        result.success(ok)
                    }
                    "removeGeofence" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = args?.get("id") as? String
                        if (id != null && id.isNotEmpty()) {
                            GeofenceRegistry.removeAlertById(activity, id)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "clearAllGeofences" -> {
                        GeofenceRegistry.clearAll(activity)
                        result.success(true)
                    }
                    "drainPendingEvents" -> {
                        result.success(GeofenceRegistry.drainPendingEvents(activity))
                    }
                    else -> result.notImplemented()
                }
            }
            return plugin
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun dispatchTransitionToFlutter(payload: Map<String, Any>): Boolean {
        return try {
            mainHandler.post {
                try {
                    channel.invokeMethod("onGeofenceTransition", payload)
                } catch (_: Exception) {}
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun requestForegroundPermission(result: MethodChannel.Result) {
        if (GeofenceRegistry.hasForegroundPermission(activity)) {
            result.success(GeofenceRegistry.getPermissionStateString(activity, activity))
            return
        }
        activity.getSharedPreferences(GeofenceRegistry.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(GeofenceRegistry.KEY_REQUESTED_FOREGROUND, true)
            .apply()

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            REQ_FOREGROUND_LOCATION
        )
    }

    private fun requestBackgroundPermission(result: MethodChannel.Result) {
        if (!GeofenceRegistry.hasForegroundPermission(activity)) {
            pendingPermissionResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                REQ_FOREGROUND_LOCATION
            )
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            GeofenceRegistry.hasBackgroundPermission(activity)
        ) {
            result.success(GeofenceRegistry.getPermissionStateString(activity, activity))
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQ_BACKGROUND_LOCATION
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQ_FOREGROUND_LOCATION && requestCode != REQ_BACKGROUND_LOCATION) {
            return false
        }
        val callback = pendingPermissionResult
        pendingPermissionResult = null
        callback?.success(GeofenceRegistry.getPermissionStateString(activity, activity))
        return true
    }

    private fun openAppLocationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!GeofenceRegistry.hasForegroundPermission(activity)) {
            result.success(null)
            return
        }

        val lm = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.success(null)
            return
        }

        val bestLast = findBestLastKnownLocation(lm)
        if (bestLast != null &&
            (System.currentTimeMillis() - bestLast.time) < 120_000L
        ) {
            result.success(locationToMap(bestLast))
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val provider = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    lm.isProviderEnabled(LocationManager.FUSED_PROVIDER) ->
                    LocationManager.FUSED_PROVIDER
                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                    LocationManager.GPS_PROVIDER
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                    LocationManager.NETWORK_PROVIDER
                else -> null
            }
            if (provider != null) {
                lm.getCurrentLocation(
                    provider,
                    null,
                    activity.mainExecutor
                ) { location ->
                    val chosen = location ?: bestLast
                    result.success(chosen?.let { locationToMap(it) })
                }
                return
            }
        }

        val fallbackProvider = when {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> null
        }

        if (fallbackProvider == null) {
            result.success(bestLast?.let { locationToMap(it) })
            return
        }

        var completed = false
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (completed) return
                completed = true
                lm.removeUpdates(this)
                result.success(locationToMap(location))
            }

            @Deprecated("Deprecated in API 29")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        try {
            lm.requestLocationUpdates(fallbackProvider, 0L, 0f, listener, Looper.getMainLooper())
            mainHandler.postDelayed({
                if (!completed) {
                    completed = true
                    lm.removeUpdates(listener)
                    result.success(bestLast?.let { locationToMap(it) })
                }
            }, 6_000L)
        } catch (_: Exception) {
            if (!completed) {
                completed = true
                result.success(bestLast?.let { locationToMap(it) })
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun findBestLastKnownLocation(lm: LocationManager): Location? {
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        var best: Location? = null
        for (p in providers) {
            try {
                val loc = lm.getLastKnownLocation(p) ?: continue
                if (best == null || loc.time > best.time) {
                    best = loc
                }
            } catch (_: Exception) {}
        }
        return best
    }

    private fun locationToMap(loc: Location): Map<String, Any> {
        return mapOf(
            "latitude" to loc.latitude,
            "longitude" to loc.longitude,
            "accuracy" to loc.accuracy.toDouble(),
            "timestampMs" to loc.time,
            "isSimulated" to false
        )
    }

    fun dispose() {
        if (activeInstance === this) {
            activeInstance = null
        }
    }
}
