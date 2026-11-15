package com.nestin.app.services

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.nestin.app.MainActivity
import com.nestin.app.R
import com.nestin.app.oem.KeepAliveGuardState
import com.nestin.app.oem.OemHardeningPlugin

/**
 * Android 7.0+ (API 24+) Quick Settings tile letting users toggle
 * [NestinKeepAliveService] directly from the system notification shade.
 */
@RequiresApi(Build.VERSION_CODES.N)
class NestinKeepAliveTileService : TileService() {

    companion object {
        fun requestTileUpdate(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    requestListeningState(
                        context.applicationContext,
                        ComponentName(
                            context.applicationContext,
                            NestinKeepAliveTileService::class.java,
                        ),
                    )
                } catch (_: Exception) {
                    // Ignore when launcher/shade does not have tile pinned.
                }
            }
        }
    }

    override fun onTileAdded() {
        super.onTileAdded()
        KeepAliveGuardState.setTileAdded(this, true)
        syncTileUi()
    }

    override fun onTileRemoved() {
        super.onTileRemoved()
        KeepAliveGuardState.setTileAdded(this, false)
    }

    override fun onStartListening() {
        super.onStartListening()
        KeepAliveGuardState.setTileAdded(this, true)
        syncTileUi()
    }

    override fun onClick() {
        super.onClick()
        val targetEnabled = !KeepAliveGuardState.isCurrentlyGuarded(this)

        if (targetEnabled) {
            KeepAliveGuardState.setEnabled(this, true)
            val started = NestinKeepAliveService.startService(this)
            if (!started) {
                // Fallback when OEM OS blocks background FGS creation from shade:
                // launch Nestin foreground so it activates immediately.
                KeepAliveGuardState.setEnabled(this, false)
                syncTileUi(overrideActive = false)
                openGuardScreen()
                return
            }
        } else {
            KeepAliveGuardState.setEnabled(this, false)
            NestinKeepAliveService.stopService(this)
        }

        syncTileUi(overrideActive = targetEnabled)
        OemHardeningPlugin.notifyKeepAliveStateChanged(targetEnabled)
    }

    private fun syncTileUi(overrideActive: Boolean? = null) {
        val tile = qsTile ?: return
        val isActive = overrideActive ?: KeepAliveGuardState.isCurrentlyGuarded(this)

        tile.state = if (isActive) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        val baseLabel = getString(R.string.qs_keep_alive_tile_label)
        val stateLabel = getString(
            if (isActive) R.string.qs_keep_alive_state_active
            else R.string.qs_keep_alive_state_inactive,
        )

        tile.label = baseLabel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = stateLabel
        }
        tile.contentDescription = "$baseLabel: $stateLabel"
        tile.updateTile()
    }

    private fun openGuardScreen() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("nestin://oem-hardening")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pi = PendingIntent.getActivity(
                this,
                9002,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pi)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
