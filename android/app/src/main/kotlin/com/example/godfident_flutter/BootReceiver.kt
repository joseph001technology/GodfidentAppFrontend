package com.example.godfident_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat

/**
 * Restores protection after a reboot so a restart is not a way around it.
 * Website protection is only restored if Android's VPN consent is still
 * granted (VpnService.prepare returns null); otherwise it stays INACTIVE and
 * the app tells the user, rather than pretending.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        val web = context.getSharedPreferences(WebsiteBlockVpnService.PREFS, Context.MODE_PRIVATE)
        if (web.getBoolean(WebsiteBlockVpnService.KEY_ACTIVE, false) && VpnService.prepare(context) == null) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, WebsiteBlockVpnService::class.java))
            } catch (_: Exception) {
            }
        }

        val focus = context.getSharedPreferences(FocusBlockingService.PREFS_NAME, Context.MODE_PRIVATE)
        val endAt = focus.getLong(FocusBlockingService.KEY_END_AT, 0L)
        val stillRunning = focus.getBoolean(FocusBlockingService.KEY_SESSION_ACTIVE, false) &&
            (endAt == 0L || endAt > System.currentTimeMillis())
        if (stillRunning) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, FocusBlockingService::class.java))
            } catch (_: Exception) {
            }
        }
    }
}
