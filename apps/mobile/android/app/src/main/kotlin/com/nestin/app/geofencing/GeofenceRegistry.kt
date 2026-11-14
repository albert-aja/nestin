package com.nestin.app.geofencing

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.nestin.app.MainActivity
import org.json.JSONArray
import org.json.JSONObject

object GeofenceRegistry {
    const val PREFS_NAME = "nestin_geofence_prefs"
    const val KEY_REGIONS_JSON = "registered_regions_json"
    const val KEY_PENDING_EVENTS = "pending_geofence_events"
    const val KEY_REQUESTED_FOREGROUND = "has_requested_foreground"
    const val ACTION_PROXIMITY_ALERT = "com.nestin.app.ACTION_PROXIMITY_ALERT"

    const val CHANNEL_ID = "nestin_geofence_channel"
    const val CHANNEL_NAME = "Scout Location Reminders"
    const val CHANNEL_DESC = "Arrival and departure alerts when reaching or leaving saved places"

    fun hasForegroundPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    fun hasBackgroundPermission(context: Context): Boolean {
        if (!hasForegroundPermission(context)) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    fun getPermissionStateString(context: Context, activity: android.app.Activity?): String {
        if (!hasForegroundPermission(context)) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val askedBefore = prefs.getBoolean(KEY_REQUESTED_FOREGROUND, false)
            if (askedBefore && activity != null) {
                val showRationale = ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.ACCESS_FINE_LOCATION
                )
                if (!showRationale) {
                    return "deniedForever"
                }
            }
            return "denied"
        }
        return if (hasBackgroundPermission(context)) "always" else "whileInUse"
    }

    fun loadRegionsJson(context: Context): JSONArray {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_REGIONS_JSON, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    fun saveRegionsJson(context: Context, array: JSONArray) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_REGIONS_JSON, array.toString())
            .apply()
    }

    @SuppressLint("MissingPermission")
    fun syncNativeAlerts(context: Context, regions: List<Map<*, *>>): Boolean {
        clearAllAlertsOnly(context)

        val jsonArray = JSONArray()
        for (region in regions) {
            val id = region["id"] as? String ?: continue
            val lat = (region["latitude"] as? Number)?.toDouble() ?: continue
            val lng = (region["longitude"] as? Number)?.toDouble() ?: continue
            val radius = (region["radiusMeters"] as? Number)?.toFloat() ?: 150f

            val obj = JSONObject().apply {
                put("id", id)
                put("placeId", region["placeId"] as? String ?: "")
                put("placeName", region["placeName"] as? String ?: "Saved Place")
                put("title", region["title"] as? String ?: "Location Reminder")
                put("notes", region["notes"] as? String ?: "")
                put("latitude", lat)
                put("longitude", lng)
                put("radiusMeters", radius.toDouble())
                put("triggerType", region["triggerType"] as? String ?: "arrive")
                put("oneTimeOnly", region["oneTimeOnly"] as? Boolean ?: false)
                put("cooldownMinutes", (region["cooldownMinutes"] as? Number)?.toInt() ?: 30)
                put("checkDepartureChecklist", region["checkDepartureChecklist"] as? Boolean ?: false)
                val lastMs = (region["lastTriggeredMs"] as? Number)?.toLong() ?: 0L
                put("lastTriggeredMs", lastMs)
            }
            jsonArray.put(obj)
        }

        saveRegionsJson(context, jsonArray)
        return reregisterArray(context, jsonArray)
    }

    fun reregisterAll(context: Context): Boolean {
        val jsonArray = loadRegionsJson(context)
        return reregisterArray(context, jsonArray)
    }

    @SuppressLint("MissingPermission")
    private fun reregisterArray(context: Context, array: JSONArray): Boolean {
        if (!hasForegroundPermission(context)) return false
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false

        var success = true
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val id = obj.optString("id", "")
            if (id.isEmpty()) continue
            val lat = obj.optDouble("latitude", 0.0)
            val lng = obj.optDouble("longitude", 0.0)
            val radius = obj.optDouble("radiusMeters", 150.0).toFloat().coerceIn(50f, 5000f)

            try {
                val pendingIntent = buildProximityPendingIntent(context, id)
                locationManager.addProximityAlert(lat, lng, radius, -1L, pendingIntent)
            } catch (_: Exception) {
                success = false
            }
        }
        return success
    }

    @SuppressLint("MissingPermission")
    fun removeAlertById(context: Context, id: String) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        try {
            locationManager?.removeProximityAlert(buildProximityPendingIntent(context, id))
        } catch (_: Exception) {}

        val existing = loadRegionsJson(context)
        val filtered = JSONArray()
        for (i in 0 until existing.length()) {
            val item = existing.optJSONObject(i) ?: continue
            if (item.optString("id") != id) {
                filtered.put(item)
            }
        }
        saveRegionsJson(context, filtered)
    }

    @SuppressLint("MissingPermission")
    fun clearAllAlertsOnly(context: Context) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val existing = loadRegionsJson(context)
        for (i in 0 until existing.length()) {
            val item = existing.optJSONObject(i) ?: continue
            val id = item.optString("id", "")
            if (id.isNotEmpty()) {
                try {
                    locationManager?.removeProximityAlert(buildProximityPendingIntent(context, id))
                } catch (_: Exception) {}
            }
        }
    }

    fun clearAll(context: Context) {
        clearAllAlertsOnly(context)
        saveRegionsJson(context, JSONArray())
    }

    fun buildProximityPendingIntent(context: Context, id: String): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java).apply {
            action = ACTION_PROXIMITY_ALERT
            data = Uri.parse("nestin://geofence_alert/$id")
            putExtra("id", id)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            flags
        )
    }

    fun handleProximityTrigger(context: Context, id: String, isEntering: Boolean) {
        val array = loadRegionsJson(context)
        val updatedArray = JSONArray()
        var matchedObj: JSONObject? = null
        val nowMs = System.currentTimeMillis()
        val transition = if (isEntering) "enter" else "exit"

        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optString("id") != id) {
                updatedArray.put(obj)
                continue
            }

            val triggerType = obj.optString("triggerType", "arrive")
            val matchesTrigger = when (triggerType) {
                "arrive" -> isEntering
                "leave" -> !isEntering
                else -> true
            }
            if (!matchesTrigger) {
                updatedArray.put(obj)
                continue
            }

            val cooldownMinutes = obj.optInt("cooldownMinutes", 30).coerceAtLeast(0)
            val lastTriggeredMs = obj.optLong("lastTriggeredMs", 0L)
            val elapsedMinutes = (nowMs - lastTriggeredMs) / 60000L
            if (lastTriggeredMs > 0L && cooldownMinutes > 0 && elapsedMinutes < cooldownMinutes) {
                updatedArray.put(obj)
                continue
            }

            matchedObj = obj
            obj.put("lastTriggeredMs", nowMs)
            val oneTimeOnly = obj.optBoolean("oneTimeOnly", false)
            if (!oneTimeOnly) {
                updatedArray.put(obj)
            } else {
                try {
                    val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    lm?.removeProximityAlert(buildProximityPendingIntent(context, id))
                } catch (_: Exception) {}
            }
        }

        val target = matchedObj ?: return
        saveRegionsJson(context, updatedArray)

        val placeId = target.optString("placeId", "")
        val placeName = target.optString("placeName", "Saved Place")
        val title = target.optString("title", "Location Reminder")
        val notes = target.optString("notes", "")
        val checkDepartureChecklist = target.optBoolean("checkDepartureChecklist", false)

        postGeofenceNotification(
            context = context,
            reminderId = id,
            title = title,
            notes = notes,
            placeName = placeName,
            isEntering = isEntering,
            checkDepartureChecklist = checkDepartureChecklist
        )

        val eventObj = JSONObject().apply {
            put("reminderId", id)
            put("placeId", placeId)
            put("placeName", placeName)
            put("transition", transition)
            put("timestampMs", nowMs)
            put("latitude", target.optDouble("latitude", 0.0))
            put("longitude", target.optDouble("longitude", 0.0))
            put("isSimulated", false)
            put("alreadyNotifiedNatively", true)
        }

        val dispatched = GeofencingPlugin.activeInstance?.dispatchTransitionToFlutter(
            mapOf(
                "reminderId" to id,
                "placeId" to placeId,
                "placeName" to placeName,
                "transition" to transition,
                "timestampMs" to nowMs,
                "latitude" to target.optDouble("latitude", 0.0),
                "longitude" to target.optDouble("longitude", 0.0),
                "isSimulated" to false,
                "alreadyNotifiedNatively" to true
            )
        ) ?: false

        if (!dispatched) {
            queuePendingEvent(context, eventObj)
        }
    }

    private fun queuePendingEvent(context: Context, eventObj: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_EVENTS, null)
        val list = try {
            if (raw != null) JSONArray(raw) else JSONArray()
        } catch (_: Exception) {
            JSONArray()
        }
        list.put(eventObj)
        prefs.edit().putString(KEY_PENDING_EVENTS, list.toString()).apply()
    }

    fun drainPendingEvents(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_EVENTS, null) ?: return emptyList()
        prefs.edit().remove(KEY_PENDING_EVENTS).apply()

        val result = mutableListOf<Map<String, Any>>()
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                result.add(
                    mapOf(
                        "reminderId" to obj.optString("reminderId", ""),
                        "placeId" to obj.optString("placeId", ""),
                        "placeName" to obj.optString("placeName", ""),
                        "transition" to obj.optString("transition", "enter"),
                        "timestampMs" to obj.optLong("timestampMs", System.currentTimeMillis()),
                        "latitude" to obj.optDouble("latitude", 0.0),
                        "longitude" to obj.optDouble("longitude", 0.0),
                        "isSimulated" to obj.optBoolean("isSimulated", false),
                        "alreadyNotifiedNatively" to obj.optBoolean("alreadyNotifiedNatively", true)
                    )
                )
            }
        } catch (_: Exception) {}
        return result
    }

    private fun postGeofenceNotification(
        context: Context,
        reminderId: String,
        title: String,
        notes: String,
        placeName: String,
        isEntering: Boolean,
        checkDepartureChecklist: Boolean
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val actionPrefix = if (isEntering) "Near $placeName" else "Leaving $placeName"
        val notifTitle = "🧭 $actionPrefix: $title"
        val bodyBuilder = StringBuilder()
        if (notes.isNotBlank()) {
            bodyBuilder.append(notes)
        } else {
            bodyBuilder.append(
                if (isEntering) {
                    "Scout Location Reminder triggered arriving near $placeName."
                } else {
                    "Scout Location Reminder triggered departing $placeName."
                }
            )
        }
        if (checkDepartureChecklist && !isEntering) {
            bodyBuilder.append(" • Check BeforeYouGo keys, wallet & essentials!")
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("nestin://location_reminders")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val contentIntent = PendingIntent.getActivity(
            context,
            reminderId.hashCode(),
            launchIntent,
            piFlags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle(notifTitle)
            .setContentText(bodyBuilder.toString())
            .setStyle(NotificationCompat.BigTextStyle().bigText(bodyBuilder.toString()))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        val notifId = 7500 + (kotlin.math.abs(reminderId.hashCode()) % 500)
        manager.notify(notifId, notification)
    }
}

