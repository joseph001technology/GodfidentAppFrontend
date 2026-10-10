package com.example.godfident_flutter

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Schedules the RINGING part of alarms (reminder alarms and pre-set Focus
 * sessions) with AlarmManager. When one fires, [AlarmReceiver] starts
 * [AlarmRingService], which plays the sound on Android's ALARM audio stream
 * from a foreground service - so it keeps ringing when another app makes a
 * sound, when a notification arrives, or when the volume keys are pressed.
 *
 * Alarms are kept in SharedPreferences so they survive a reboot
 * ([BootReceiver] calls [rearmAll]) and so repeating ones can re-arm
 * themselves after they fire.
 */
object AlarmScheduler {
    private const val PREFS = "godfident_alarms"
    private const val KEY = "alarms_v1"

    const val EXTRA_ID = "alarm_id"

    /** Phone was off / app was dead: ring still if it is less than this late, otherwise say it was missed. */
    const val CATCHUP_WINDOW_MS = 60L * 60L * 1000L
    const val SNOOZE_MINUTES = 10

    /** Id of the one-shot copy used for snoozes and catch-up rings (never collides with a real alarm id). */
    fun derivedId(id: Int): Int = 1_500_000_000 + (Math.abs(id.toLong()) % 100_000_000L).toInt()

    /** Next occurrence after [t]. repeatMs == -1 means "monthly". */
    private fun advance(t: Long, repeatMs: Long): Long {
        if (repeatMs > 0) return t + repeatMs
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = t
        cal.add(java.util.Calendar.MONTH, 1)
        return cal.timeInMillis
    }

    class Alarm(
        val id: Int,
        var whenMs: Long,
        val repeatMs: Long, // 0 = once, else DAY or WEEK in ms
        val title: String,
        val body: String,
        val route: String,
        val soundUri: String, // content:// or android.resource:// ; empty = default alarm tone
        val maxSeconds: Int,
        val startLabel: String, // "" = no Start button
        val ring: Boolean = true, // false = a normal notification (reminder), true = ringing alarm
        val skipKey: String = "" // Flutter pref holding a yyyy-MM-dd; if it equals today the alarm stays silent
    ) {
        fun toJson() = JSONObject().apply {
            put("id", id); put("when", whenMs); put("repeat", repeatMs)
            put("title", title); put("body", body); put("route", route)
            put("sound", soundUri); put("max", maxSeconds); put("start", startLabel)
            put("ring", ring); put("skip", skipKey)
        }

        companion object {
            fun fromJson(o: JSONObject) = Alarm(
                o.getInt("id"), o.getLong("when"), o.optLong("repeat", 0),
                o.optString("title"), o.optString("body"), o.optString("route"),
                o.optString("sound"), o.optInt("max", 60), o.optString("start"),
                o.optBoolean("ring", true), o.optString("skip")
            )
        }
    }

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(c: Context): MutableList<Alarm> {
        val raw = prefs(c).getString(KEY, null) ?: return mutableListOf()
        return try {
            val a = JSONArray(raw)
            MutableList(a.length()) { Alarm.fromJson(a.getJSONObject(it)) }
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun save(c: Context, list: List<Alarm>) {
        val a = JSONArray()
        list.forEach { a.put(it.toJson()) }
        prefs(c).edit().putString(KEY, a.toString()).apply()
    }

    fun find(c: Context, id: Int): Alarm? = load(c).firstOrNull { it.id == id }

    private fun pending(c: Context, id: Int): PendingIntent {
        val i = Intent(c, AlarmReceiver::class.java).putExtra(EXTRA_ID, id)
        i.action = "com.example.godfident_flutter.ALARM_$id"
        return PendingIntent.getBroadcast(
            c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(c: Context, alarm: Alarm) {
        val list = load(c)
        list.removeAll { it.id == alarm.id }
        list.add(alarm)
        save(c, list)
        arm(c, alarm)
    }

    private fun arm(c: Context, alarm: Alarm) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(c, alarm.id)
        val canExact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (canExact) {
                // setAlarmClock is exempt from Doze and from background-start limits.
                val show = PendingIntent.getActivity(
                    c, alarm.id,
                    Intent(c, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(alarm.whenMs, show), pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.whenMs, pi)
            }
        } catch (_: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, alarm.whenMs, pi)
        }
    }

    fun cancel(c: Context, id: Int) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(c, id))
        val list = load(c)
        if (list.removeAll { it.id == id }) save(c, list)
    }

    /**
     * After a reboot / app update / app start: arm everything again, and deal
     * with alarms whose time passed while the phone was off:
     *  - less than an hour late  -> ring (a few seconds from now)
     *  - an hour or more late    -> a "missed" notification (name + what it was for)
     * Repeating alarms are moved on to their next future time either way.
     */
    fun rearmAll(c: Context) {
        val now = System.currentTimeMillis()
        val keep = mutableListOf<Alarm>()
        val late = mutableListOf<Pair<Alarm, Long>>()
        for (a in load(c)) {
            if (a.whenMs > now) {
                keep.add(a)
                arm(c, a)
                continue
            }
            val missedAt: Long
            if (a.repeatMs != 0L) {
                // Only the most recent missed occurrence matters.
                var t = a.whenMs
                var next = advance(t, a.repeatMs)
                while (next <= now) { t = next; next = advance(t, a.repeatMs) }
                missedAt = t
                val moved = Alarm(a.id, next, a.repeatMs, a.title, a.body, a.route, a.soundUri, a.maxSeconds, a.startLabel, a.ring, a.skipKey)
                keep.add(moved)
                arm(c, moved)
            } else {
                missedAt = a.whenMs
            }
            late.add(Pair(a, missedAt))
        }
        save(c, keep)
        for ((a, t) in late) handleLate(c, a, t, now)
    }

    /**
     * "Only nudge me if I have not prayed / read today": the app stores today's date in a
     * Flutter preference when the person does it; if that date is today, stay silent.
     */
    fun skipToday(c: Context, a: Alarm): Boolean {
        if (a.skipKey.isEmpty()) return false
        val v = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter." + a.skipKey, "") ?: ""
        val cal = java.util.Calendar.getInstance()
        val today = String.format(
            java.util.Locale.US, "%04d-%02d-%02d",
            cal.get(java.util.Calendar.YEAR), cal.get(java.util.Calendar.MONTH) + 1, cal.get(java.util.Calendar.DAY_OF_MONTH)
        )
        return v == today
    }

    private fun handleLate(c: Context, a: Alarm, missedAt: Long, now: Long) {
        if (skipToday(c, a)) return
        if (now - missedAt < CATCHUP_WINDOW_MS) {
            // Re-schedule as a normal alarm a few seconds from now: an alarm-clock
            // alarm may start the sound service even straight after boot.
            schedule(c, Alarm(derivedId(a.id), now + 4000L, 0L, a.title, a.body, a.route, a.soundUri, a.maxSeconds, a.startLabel, a.ring, a.skipKey))
        } else {
            AlarmRingService.postMissed(c, a.id, a.title, a.body, a.route, missedAt)
        }
    }

    /** Rings [a] again in [minutes] (survives a reboot because it is stored like any other alarm). */
    fun snooze(c: Context, a: Alarm, minutes: Int = SNOOZE_MINUTES) {
        schedule(c, Alarm(derivedId(a.id), System.currentTimeMillis() + minutes * 60_000L, 0L,
            a.title, a.body, a.route, a.soundUri, a.maxSeconds, a.startLabel, true, a.skipKey))
    }

    /** Called when an alarm fires: re-arms repeating ones, forgets one-time ones. */
    fun onFired(c: Context, id: Int) {
        val list = load(c)
        val a = list.firstOrNull { it.id == id } ?: return
        if (a.repeatMs != 0L) {
            val now = System.currentTimeMillis()
            while (a.whenMs <= now) a.whenMs = advance(a.whenMs, a.repeatMs)
            save(c, list)
            arm(c, a)
        } else {
            list.removeAll { it.id == id }
            save(c, list)
        }
    }
}
