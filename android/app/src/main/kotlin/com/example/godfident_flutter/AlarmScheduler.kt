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

    class Alarm(
        val id: Int,
        var whenMs: Long,
        val repeatMs: Long, // 0 = once, else DAY or WEEK in ms
        val title: String,
        val body: String,
        val route: String,
        val soundUri: String, // content:// or android.resource:// ; empty = default alarm tone
        val maxSeconds: Int,
        val startLabel: String // "" = no Start button
    ) {
        fun toJson() = JSONObject().apply {
            put("id", id); put("when", whenMs); put("repeat", repeatMs)
            put("title", title); put("body", body); put("route", route)
            put("sound", soundUri); put("max", maxSeconds); put("start", startLabel)
        }

        companion object {
            fun fromJson(o: JSONObject) = Alarm(
                o.getInt("id"), o.getLong("when"), o.optLong("repeat", 0),
                o.optString("title"), o.optString("body"), o.optString("route"),
                o.optString("sound"), o.optInt("max", 60), o.optString("start")
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

    /** After a reboot / app update: arm everything again (past one-time alarms are dropped). */
    fun rearmAll(c: Context) {
        val now = System.currentTimeMillis()
        val keep = mutableListOf<Alarm>()
        for (a in load(c)) {
            if (a.repeatMs > 0) {
                while (a.whenMs <= now) a.whenMs += a.repeatMs
            } else if (a.whenMs <= now) {
                continue
            }
            keep.add(a)
            arm(c, a)
        }
        save(c, keep)
    }

    /** Called when an alarm fires: re-arms repeating ones, forgets one-time ones. */
    fun onFired(c: Context, id: Int) {
        val list = load(c)
        val a = list.firstOrNull { it.id == id } ?: return
        if (a.repeatMs > 0) {
            val now = System.currentTimeMillis()
            while (a.whenMs <= now) a.whenMs += a.repeatMs
            save(c, list)
            arm(c, a)
        } else {
            list.removeAll { it.id == id }
            save(c, list)
        }
    }
}
