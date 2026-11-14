package com.nestin.app.geofencing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.LocationManager

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: intent.data?.lastPathSegment ?: return
        val entering = intent.getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, true)
        GeofenceRegistry.handleProximityTrigger(context.applicationContext, id, entering)
    }
}

