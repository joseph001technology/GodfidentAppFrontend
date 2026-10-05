package com.example.godfident_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Fires at the alarm time and starts the ringing service. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val id = intent?.getIntExtra(AlarmScheduler.EXTRA_ID, -1) ?: -1
        if (id < 0) return
        val alarm = AlarmScheduler.find(context, id) ?: return
        // Re-arm (repeating) or forget (one-time) BEFORE ringing, so a crash
        // while ringing can never lose tomorrow's alarm.
        AlarmScheduler.onFired(context, id)
        val svc = Intent(context, AlarmRingService::class.java)
            .putExtra("id", alarm.id)
            .putExtra("title", alarm.title)
            .putExtra("body", alarm.body)
            .putExtra("route", alarm.route)
            .putExtra("sound", alarm.soundUri)
            .putExtra("max", alarm.maxSeconds)
            .putExtra("start", alarm.startLabel)
        try {
            ContextCompat.startForegroundService(context, svc)
        } catch (_: Exception) {
            // Last resort: at least show something.
            AlarmRingService.postPlainNotification(context, alarm.id, alarm.title, alarm.body, alarm.route)
        }
    }
}
