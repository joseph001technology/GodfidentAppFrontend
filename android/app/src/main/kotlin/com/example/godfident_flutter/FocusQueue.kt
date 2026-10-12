package com.example.godfident_flutter

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

/**
 * Pre-set Focus sessions that came due while another session was running or
 * frozen wait here, oldest first. Only [MAX] can wait: when a fourth arrives
 * the oldest one is dropped. When the running session ends, [ringNext] rings
 * the oldest waiting session so the person can press Start.
 *
 * Kept natively (not in Dart) because the alarm fires while the app is closed.
 */
object FocusQueue {
    private const val PREFS = "godfident_focus_queue"
    private const val KEY = "queue_v1"
    const val MAX = 3

    private const val REPLAY_BASE = 1_450_000_000
    private const val NOTE_BASE = 1_460_000_000

    class Item(
        val route: String,
        val name: String,
        val minutes: Int,
        val purpose: String,
        val queuedAt: Long,
        val title: String,
        val body: String,
        val sound: String,
        val maxSeconds: Int,
        val startLabel: String
    ) {
        val startId: Int get() = Uri.parse(route).getQueryParameter("start")?.toIntOrNull() ?: 0

        fun toJson() = JSONObject().apply {
            put("route", route); put("name", name); put("minutes", minutes); put("purpose", purpose)
            put("at", queuedAt); put("title", title); put("body", body); put("sound", sound)
            put("max", maxSeconds); put("start", startLabel)
        }

        fun toMap(): Map<String, Any> = mapOf(
            "route" to route, "name" to name, "minutes" to minutes,
            "purpose" to purpose, "queuedAt" to queuedAt, "startId" to startId
        )

        companion object {
            fun fromJson(o: JSONObject) = Item(
                o.optString("route"), o.optString("name"), o.optInt("minutes", 30), o.optString("purpose"),
                o.optLong("at"), o.optString("title"), o.optString("body"), o.optString("sound"),
                o.optInt("max", 1800), o.optString("start", "Start")
            )
        }
    }

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun list(c: Context): MutableList<Item> {
        val raw = prefs(c).getString(KEY, null) ?: return mutableListOf()
        return try {
            val a = JSONArray(raw)
            MutableList(a.length()) { Item.fromJson(a.getJSONObject(it)) }
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun save(c: Context, l: List<Item>) {
        val a = JSONArray()
        l.forEach { a.put(it.toJson()) }
        prefs(c).edit().putString(KEY, a.toString()).apply()
    }

    fun size(c: Context): Int = list(c).size

    /** Alarm ids used to ring a queued session again are in this range and are never queued twice. */
    fun isReplayId(id: Int): Boolean = id >= REPLAY_BASE && id < REPLAY_BASE + 1_000_000

    private fun replayId(startId: Int): Int = REPLAY_BASE + (Math.abs(startId.toLong()) % 1_000_000L).toInt()

    /** Queues an alarm that came due while a session is busy. Returns the queue size. */
    fun add(c: Context, a: AlarmScheduler.Alarm): Int = addItem(c, itemFor(a.route, a.title, a.body, a.soundUri, a.maxSeconds, a.startLabel))

    /** Queues a session the person started by hand while another one is running. */
    fun addRoute(c: Context, route: String): Int = addItem(c, itemFor(route, "Your time with God is starting", "", "", 1800, "Start"))

    private fun itemFor(route: String, title: String, body: String, sound: String, max: Int, start: String): Item {
        val u = Uri.parse(route)
        val name = u.getQueryParameter("n")?.takeIf { it.isNotBlank() } ?: "Time with God"
        val minutes = u.getQueryParameter("m")?.toIntOrNull() ?: 30
        val purpose = u.getQueryParameter("p") ?: ""
        return Item(route, name, minutes, purpose, System.currentTimeMillis(), title, body, sound, max, start.ifEmpty { "Start" })
    }

    private fun addItem(c: Context, item: Item): Int {
        val l = list(c)
        // The same session is not queued twice.
        if (l.none { it.startId != 0 && it.startId == item.startId }) l.add(item)
        // Only three may wait: drop the oldest.
        while (l.size > MAX) l.removeAt(0)
        save(c, l)
        try {
            AlarmRingService.postPlainNotification(
                c, NOTE_BASE + (Math.abs(item.startId.toLong()) % 1_000_000L).toInt(),
                "Waiting in queue: ${item.name}",
                "Your current session is still on. ${item.name} (${item.minutes} min) will be ready when it ends. " +
                    "${l.size} of $MAX waiting.",
                "/focus"
            )
        } catch (_: Exception) {}
        refreshUi(c)
        return l.size
    }

    fun remove(c: Context, index: Int) {
        val l = list(c)
        if (index in l.indices) l.removeAt(index)
        save(c, l)
        refreshUi(c)
    }

    fun clear(c: Context) {
        prefs(c).edit().remove(KEY).apply()
        refreshUi(c)
    }

    /** The current session is over: ring the oldest waiting one (the person presses Start). */
    fun ringNext(c: Context): Item? {
        val l = list(c)
        if (l.isEmpty()) return null
        val next = l.removeAt(0)
        save(c, l)
        val title = "Up next: ${next.name}"
        val body = "${next.name} · ${next.minutes} min. Press Start to begin your Focus session."
        AlarmScheduler.schedule(
            c,
            AlarmScheduler.Alarm(
                id = replayId(next.startId), whenMs = System.currentTimeMillis() + 1500L, repeatMs = 0L,
                title = title, body = body, route = next.route, soundUri = next.sound,
                maxSeconds = next.maxSeconds, startLabel = next.startLabel
            )
        )
        return next
    }

    private fun refreshUi(c: Context) {
        try { SessionUi.refresh(c) } catch (_: Exception) {}
    }
}
