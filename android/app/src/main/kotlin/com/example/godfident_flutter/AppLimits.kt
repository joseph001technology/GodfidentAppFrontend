package com.example.godfident_flutter

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import org.json.JSONObject
import java.util.Calendar

/**
 * Daily time limits per app.
 *
 * - The person picks minutes per day for an app. Android's own usage log says how long it
 *   has really been on screen today; once that reaches the limit the accessibility service
 *   sends the person Home whenever the app is opened, until midnight.
 * - A limit is LOCKED for [LOCK_MS] (one week) from the moment it is set: it cannot be
 *   raised, changed or removed meanwhile - not from the app screen, because this object
 *   itself refuses. After the week it can be edited (which locks it again).
 * - The data lives in its own preferences file, which is excluded from Android backup
 *   (see res/xml/backup_rules.xml), so reinstalling Godfident starts with no limits.
 *
 * Needs "Usage access" to read the real minutes used.
 */
object AppLimits {
    const val PREFS = "godfident_app_limits"
    private const val KEY = "limits_v1"
    const val LOCK_MS = 7L * 24 * 60 * 60 * 1000

    class Limit(val pkg: String, val label: String, val minutes: Int, val setAt: Long, val lockedUntil: Long)

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun all(c: Context): Map<String, Limit> {
        val raw = prefs(c).getString(KEY, null) ?: return emptyMap()
        val out = LinkedHashMap<String, Limit>()
        try {
            val o = JSONObject(raw)
            for (k in o.keys()) {
                val e = o.getJSONObject(k)
                out[k] = Limit(k, e.optString("l", k), e.optInt("m", 0), e.optLong("s", 0L), e.optLong("u", 0L))
            }
        } catch (_: Exception) {
        }
        return out
    }

    private fun save(c: Context, m: Map<String, Limit>) {
        val o = JSONObject()
        for ((k, v) in m) {
            o.put(k, JSONObject().put("l", v.label).put("m", v.minutes).put("s", v.setAt).put("u", v.lockedUntil))
        }
        prefs(c).edit().putString(KEY, o.toString()).apply()
    }

    fun get(c: Context, pkg: String): Limit? = all(c)[pkg]

    fun isLocked(l: Limit, now: Long = System.currentTimeMillis()) = l.lockedUntil > now

    /** Returns "ok", "locked" (still inside its week), "protected" or "invalid". */
    fun set(c: Context, pkg: String, label: String, minutes: Int): String {
        if (pkg.isBlank() || minutes < 1 || minutes > 24 * 60) return "invalid"
        if (FocusPolicy.neverBlock(c, pkg)) return "protected"
        val m = LinkedHashMap(all(c))
        val old = m[pkg]
        val now = System.currentTimeMillis()
        if (old != null && isLocked(old, now)) return "locked"
        m[pkg] = Limit(pkg, label.ifBlank { pkg }, minutes, now, now + LOCK_MS)
        save(c, m)
        return "ok"
    }

    /** Returns "ok", "locked" or "none". */
    fun remove(c: Context, pkg: String): String {
        val m = LinkedHashMap(all(c))
        val old = m[pkg] ?: return "none"
        if (isLocked(old)) return "locked"
        m.remove(pkg)
        save(c, m)
        return "ok"
    }

    private fun startOfToday(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    /** Milliseconds [pkg] has been in the foreground since midnight, or -1 if Usage access is missing. */
    fun usedTodayMs(c: Context, pkg: String): Long {
        return try {
            val usm = c.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            // Start a little before midnight so an app already open at 00:00 is seen resuming.
            val events = usm.queryEvents(startOfToday() - 60_000L, now) ?: return -1L
            val e = UsageEvents.Event()
            val dayStart = startOfToday()
            var total = 0L
            var openSince = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(e)
                val t = e.timeStamp
                when (e.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> if (e.packageName == pkg && openSince == 0L) openSince = maxOf(t, dayStart)
                    UsageEvents.Event.MOVE_TO_BACKGROUND, 23 /* ACTIVITY_STOPPED */ ->
                        if (e.packageName == pkg && openSince != 0L) { total += maxOf(0L, t - openSince); openSince = 0L }
                    16 /* SCREEN_NON_INTERACTIVE */, 26 /* DEVICE_SHUTDOWN */ ->
                        if (openSince != 0L) { total += maxOf(0L, t - openSince); openSince = 0L }
                }
            }
            if (openSince != 0L) total += maxOf(0L, now - openSince)
            total
        } catch (_: Throwable) {
            -1L
        }
    }

    /** Time left today for a limited app, or null when [pkg] has no limit / usage cannot be read. */
    fun remainingMs(c: Context, pkg: String): Long? {
        val l = get(c, pkg) ?: return null
        val used = usedTodayMs(c, pkg)
        if (used < 0) return null
        return l.minutes * 60_000L - used
    }

    fun isOver(c: Context, pkg: String): Boolean {
        val r = remainingMs(c, pkg) ?: return false
        return r <= 0L
    }

    // ── foreground watcher state (used by GuardianService) ───────────────
    private var fgPkg: String? = null
    private var fgCheckedAt = 0L

    /**
     * The app in front right now, kept up to date by reading only the usage events
     * since the previous call. Needs Usage access; returns null when unknown.
     */
    fun foregroundNow(c: Context): String? {
        return try {
            val usm = c.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val from = if (fgCheckedAt == 0L) now - 10 * 60_000L else fgCheckedAt - 1_000L
            val events = usm.queryEvents(from, now) ?: return fgPkg
            val e = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(e)
                when (e.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> fgPkg = e.packageName
                    UsageEvents.Event.MOVE_TO_BACKGROUND, 23 -> if (e.packageName == fgPkg) fgPkg = null
                    16, 26 -> fgPkg = null
                }
            }
            fgCheckedAt = now
            fgPkg
        } catch (_: Throwable) {
            null
        }
    }
}
