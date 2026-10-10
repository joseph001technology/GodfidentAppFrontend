package com.example.godfident_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Fires at the alarm time and starts the ringing service (or posts the reminder). */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // NOTE: reminders created while offline have NEGATIVE ids. The old
        // "id < 0 -> return" silently dropped every one of them.
        val id = intent?.getIntExtra(AlarmScheduler.EXTRA_ID, Int.MIN_VALUE) ?: Int.MIN_VALUE
        if (id == Int.MIN_VALUE) return
        val alarm = AlarmScheduler.find(context, id) ?: return
        // Re-arm (repeating) or forget (one-time) BEFORE ringing, so a crash
        // while ringing can never lose tomorrow's alarm.
        AlarmScheduler.onFired(context, id)

        if (AlarmScheduler.skipToday(context, alarm)) return // already prayed / read today

        if (!alarm.ring) {
            AlarmRingService.postReminder(context, alarm.id, alarm.title, alarm.body, alarm.route, alarm.soundUri)
            return
        }
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
            // The sound service was refused (e.g. Android would not let it start): still make a
            // noise - a notification on a channel that has the alarm sound.
            AlarmRingService.postReminder(context, alarm.id, alarm.title, alarm.body, alarm.route, alarm.soundUri)
        }
    }
}
