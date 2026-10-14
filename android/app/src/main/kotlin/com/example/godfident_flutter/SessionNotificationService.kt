package com.example.godfident_flutter

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat

/**
 * What the person sees while a Focus / Prayer session is on: a "now playing"
 * style card (lock screen, notification shade, media area) showing the name
 * of the session, a live countdown, what it is for, and how many sessions wait
 * in the queue.
 *
 * The state lives in SharedPreferences so the card is rebuilt if Android kills
 * the process, and so [AlarmReceiver] can tell that a session is busy.
 */
object SessionUi {
    private const val PREFS = "godfident_session_ui"
    const val CHANNEL = "godfident_session_card"
    const val NOTIF_ID = 4300
    const val ACTION_REFRESH = "com.example.godfident_flutter.SESSION_REFRESH"
    const val ACTION_END_ALARM = "com.example.godfident_flutter.SESSION_END"

    private fun p(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val ART_FILE = "session_art.png"
    @Volatile private var artCache: Bitmap? = null

    /** The picture of the running session (small, square), or null if none was saved. */
    fun art(c: Context): Bitmap? {
        artCache?.let { return it }
        return try {
            val f = java.io.File(c.filesDir, ART_FILE)
            if (!f.exists()) return null
            val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(f.path, o)
            var sample = 1
            while (o.outWidth / sample > 512 || o.outHeight / sample > 512) sample *= 2
            val bmp = BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = sample })
            artCache = bmp
            bmp
        } catch (_: Throwable) { null }
    }

    class State(
        val active: Boolean, val frozen: Boolean, val name: String, val purposeLabel: String,
        val startedAt: Long, val endAt: Long, val totalMs: Long, val frozenLeftMs: Long, val route: String
    ) {
        fun leftMs(now: Long = System.currentTimeMillis()): Long =
            if (frozen) frozenLeftMs else (endAt - now).coerceAtLeast(0L)
    }

    fun state(c: Context): State {
        val s = p(c)
        return State(
            s.getBoolean("active", false), s.getBoolean("frozen", false), s.getString("name", "") ?: "",
            s.getString("purposeLabel", "") ?: "", s.getLong("startedAt", 0L), s.getLong("endAt", 0L),
            s.getLong("totalMs", 0L), s.getLong("frozenLeftMs", 0L), s.getString("route", "/focus") ?: "/focus"
        )
    }

    /** True while a session is RUNNING (not frozen): any session that comes due now waits in the queue. */
    fun isBusy(c: Context): Boolean {
        val st = state(c)
        if (!st.active) return false
        // A frozen session is not "in use": a scheduled session that comes due now rings normally
        // (the person can still choose "Keep in queue").
        if (st.frozen) return false
        // A running (not frozen) session whose time is long over must not block the queue forever.
        if (!st.frozen && st.endAt != 0L && st.endAt < System.currentTimeMillis() - 120_000L) {
            p(c).edit().putBoolean("active", false).apply()
            return false
        }
        return true
    }

    fun show(
        c: Context, name: String, purposeLabel: String, startedAt: Long, endAt: Long, totalMs: Long,
        frozen: Boolean, frozenLeftMs: Long, route: String, art: ByteArray? = null
    ) {
        // The session's picture, shown in the notification's picture slot.
        if (art != null && art.isNotEmpty()) {
            try { java.io.File(c.filesDir, ART_FILE).writeBytes(art); artCache = null } catch (_: Exception) {}
        }
        p(c).edit()
            .putBoolean("active", true).putBoolean("frozen", frozen).putString("name", name)
            .putString("purposeLabel", purposeLabel).putLong("startedAt", startedAt).putLong("endAt", endAt)
            .putLong("totalMs", totalMs).putLong("frozenLeftMs", frozenLeftMs).putString("route", route)
            .apply()
        scheduleEnd(c, if (frozen) 0L else endAt)
        refresh(c)
    }

    /** [advance] = the session is over, so ring the oldest waiting one. */
    fun hide(c: Context, advance: Boolean) {
        val was = state(c).active
        p(c).edit().putBoolean("active", false).apply()
        scheduleEnd(c, 0L)
        try { c.stopService(Intent(c, SessionNotificationService::class.java)) } catch (_: Exception) {}
        try { (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID) } catch (_: Exception) {}
        if (advance && was) FocusQueue.ringNext(c)
    }

    /** Called by the end alarm (and the guardian) when a running session's time is up. */
    fun onEnded(c: Context) {
        val st = state(c)
        if (!st.active || st.frozen) return
        if (st.endAt > System.currentTimeMillis() + 2000L) return
        hide(c, advance = true)
    }

    fun refresh(c: Context) {
        if (!state(c).active) return
        try {
            ContextCompat.startForegroundService(c, Intent(c, SessionNotificationService::class.java).setAction(ACTION_REFRESH))
        } catch (_: Exception) {
            // Cannot start a service from the background right now: at least post the card.
            try {
                val n = SessionNotificationService.build(c, null)
                (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, n)
            } catch (_: Exception) {}
        }
    }

    private fun scheduleEnd(c: Context, endAt: Long) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            c, 4301, Intent(c, SessionEndReceiver::class.java).setAction(ACTION_END_ALARM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
        if (endAt <= System.currentTimeMillis()) return
        try {
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endAt, pi)
            }
        } catch (_: Exception) {
            try { am.set(AlarmManager.RTC_WAKEUP, endAt, pi) } catch (_: Exception) {}
        }
    }
}

class SessionEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try { SessionUi.onEnded(context) } catch (_: Exception) {}
    }
}

class SessionNotificationService : Service() {

    companion object {
        private const val TICK_MS = 30_000L

        private fun openApp(c: Context, code: Int, route: String): PendingIntent {
            val i = Intent(c, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(MainActivity.EXTRA_ALARM_ROUTE, route)
            return PendingIntent.getActivity(c, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        private fun minutesText(ms: Long): String {
            val m = (ms + 59_000L) / 60_000L
            return if (m >= 60) "${m / 60} hr ${m % 60} min" else "$m min"
        }

        fun build(c: Context, session: MediaSession?): Notification {
            val st = SessionUi.state(c)
            val left = st.leftMs()
            val title = st.name.ifBlank { st.purposeLabel.ifBlank { "Time with God" } }
            val queued = FocusQueue.size(c)
            val sub = buildString {
                append(if (st.frozen) "Frozen · ${minutesText(left)} to go" else "${minutesText(left)} left")
                if (st.purposeLabel.isNotBlank() && st.name.isNotBlank()) append(" · ").append(st.purposeLabel)
                if (queued > 0) append(" · $queued waiting")
            }

            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, SessionUi.CHANNEL) else Notification.Builder(c)
            b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(sub)
                .setSubText("Godfident Focus")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_TRANSPORT)
                .setContentIntent(openApp(c, 4310, st.route))
            SessionUi.art(c)?.let { b.setLargeIcon(it) }
            if (!st.frozen && st.endAt > System.currentTimeMillis()) {
                b.setShowWhen(true).setWhen(st.endAt)
                if (Build.VERSION.SDK_INT >= 24) b.setUsesChronometer(true).setChronometerCountDown(true)
            } else {
                b.setShowWhen(false)
            }
            // Freeze / resume only: open Godfident on the page that does it. Tapping the card itself opens the session.
            if (st.frozen) {
                b.addAction(android.R.drawable.ic_media_play, "Resume", openApp(c, 4311, "/focus?act=resume"))
            } else {
                b.addAction(android.R.drawable.ic_media_pause, "Freeze", openApp(c, 4311, "/focus?act=freeze"))
            }
            val style = Notification.MediaStyle().setShowActionsInCompactView(0)
            if (session != null) style.setMediaSession(session.sessionToken)
            b.setStyle(style)
            return b.build()
        }
    }

    private var session: MediaSession? = null
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            val st = SessionUi.state(this@SessionNotificationService)
            if (!st.active) {
                stopSelf()
                return
            }
            if (!st.frozen && st.endAt != 0L && st.endAt <= System.currentTimeMillis()) {
                SessionUi.onEnded(this@SessionNotificationService)
                return
            }
            render()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        try {
            session = MediaSession(this, "GodfidentFocus").also {
                it.setSessionActivity(openApp(this, 4314, "/focus"))
                it.isActive = true
            }
        } catch (_: Exception) {
            session = null
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val st = SessionUi.state(this)
        // Must call startForeground right away after startForegroundService.
        startForeground(SessionUi.NOTIF_ID, build(this, session))
        if (!st.active) {
            stopSelf()
            return START_NOT_STICKY
        }
        render()
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, TICK_MS)
        return START_STICKY
    }

    private fun render() {
        val st = SessionUi.state(this)
        val s = session
        if (s != null) {
            try {
                val title = st.name.ifBlank { st.purposeLabel.ifBlank { "Time with God" } }
                val left = st.leftMs()
                s.setMetadata(
                    MediaMetadata.Builder()
                        .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                        .putString(MediaMetadata.METADATA_KEY_ARTIST,
                            (if (st.frozen) "Frozen · " else "") + minutesText(left) + (if (st.frozen) " to go" else " left") +
                                (if (st.purposeLabel.isNotBlank()) " · ${st.purposeLabel}" else ""))
                        .putString(MediaMetadata.METADATA_KEY_ALBUM, "Godfident Focus")
                        .apply { SessionUi.art(this@SessionNotificationService)?.let { putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it) } }
                        .putLong(MediaMetadata.METADATA_KEY_DURATION, st.totalMs.coerceAtLeast(1L))
                        .build()
                )
                val pos = (st.totalMs - left).coerceIn(0L, st.totalMs.coerceAtLeast(1L))
                s.setPlaybackState(
                    PlaybackState.Builder()
                        .setActions(0L)
                        .setState(
                            if (st.frozen) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING,
                            pos, if (st.frozen) 0f else 1f
                        )
                        .build()
                )
            } catch (_: Exception) {}
        }
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(SessionUi.NOTIF_ID, build(this, s))
        } catch (_: Exception) {}
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(SessionUi.CHANNEL) == null) {
                val ch = NotificationChannel(SessionUi.CHANNEL, "Focus session", NotificationManager.IMPORTANCE_LOW)
                ch.description = "Shows the running Focus or Prayer session with its countdown"
                ch.setSound(null, null)
                ch.enableVibration(false)
                ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                nm.createNotificationChannel(ch)
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try { session?.release() } catch (_: Exception) {}
        session = null
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiped away from recents: keep the card (and its countdown) alive.
        try { SessionUi.refresh(this) } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }
}
