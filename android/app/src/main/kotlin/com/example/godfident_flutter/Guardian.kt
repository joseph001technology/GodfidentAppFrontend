package com.example.godfident_flutter

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import androidx.core.content.ContextCompat

/**
 * Keeps Godfident alive in the background so reminders, alarms and Focus
 * sessions do not depend on the app having been opened:
 *
 *  - [GuardianService]: a quiet foreground service (minimum-importance
 *    notification) that Android is far less willing to kill; it also listens
 *    for the phone being unlocked / the clock changing and re-arms everything.
 *  - a heartbeat alarm every 15 minutes ([GuardianReceiver]) and a persisted
 *    JobScheduler job ([GuardianJobService]) that bring the service back and
 *    re-arm alarms even if the service was killed.
 *  - the boot receiver and the accessibility service also call [ensure], so
 *    the guardian comes back after a restart even if one path is blocked.
 *
 * [tick] is the one place that "repairs" things: alarms, Safe Browsing,
 * the running Focus session, the session card, and the accessibility service.
 */
object Guardian {
    private const val PREFS = "godfident_guardian"
    private const val KEY_ENABLED = "enabled"
    const val ACTION_HEARTBEAT = "com.example.godfident_flutter.GUARDIAN_HEARTBEAT"
    const val ACTION_RESTART = "com.example.godfident_flutter.GUARDIAN_RESTART"
    const val HEARTBEAT_MS = 15L * 60L * 1000L
    private const val JOB_ID = 4400

    fun isEnabled(c: Context): Boolean =
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

    fun setEnabled(c: Context, on: Boolean) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, on).apply()
        if (on) ensure(c) else {
            try { c.stopService(Intent(c, GuardianService::class.java)) } catch (_: Exception) {}
        }
    }

    /** Starts everything that keeps the app alive. Safe to call at any time and as often as wanted. */
    fun ensure(c: Context) {
        scheduleHeartbeat(c)
        scheduleJob(c)
        if (!isEnabled(c)) return
        try {
            ContextCompat.startForegroundService(c, Intent(c, GuardianService::class.java))
        } catch (_: Exception) {
            // Android refused a background start: the heartbeat will retry.
        }
    }

    fun scheduleHeartbeat(c: Context, delayMs: Long = HEARTBEAT_MS) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            c, 4401, Intent(c, GuardianReceiver::class.java).setAction(ACTION_HEARTBEAT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val at = System.currentTimeMillis() + delayMs
        try {
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: Exception) {
            try { am.set(AlarmManager.RTC_WAKEUP, at, pi) } catch (_: Exception) {}
        }
    }

    private fun scheduleJob(c: Context) {
        try {
            val js = c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (Build.VERSION.SDK_INT >= 24 && js.getPendingJob(JOB_ID) != null) return
            val job = JobInfo.Builder(JOB_ID, ComponentName(c, GuardianJobService::class.java))
                .setPeriodic(HEARTBEAT_MS)
                .setPersisted(true)
                .build()
            js.schedule(job)
        } catch (_: Exception) {}
    }

    /** Repairs anything that should be running but is not. Never throws. */
    fun tick(c: Context) {
        // 1. Alarms (reminders, scheduled Focus sessions, nudges). The grace keeps one that is due this
        //    very second from being treated as "missed".
        try { AlarmScheduler.rearmAll(c, 90_000L) } catch (_: Exception) {}

        // 2. Safe Browsing.
        try {
            val web = c.getSharedPreferences(WebsiteBlockVpnService.PREFS, Context.MODE_PRIVATE)
            if (web.getBoolean(WebsiteBlockVpnService.KEY_ACTIVE, false) &&
                !WebsiteBlockVpnService.isRunning && VpnService.prepare(c) == null
            ) {
                ContextCompat.startForegroundService(c, Intent(c, WebsiteBlockVpnService::class.java))
            }
        } catch (_: Exception) {}

        // 3. A Focus session that should still be blocking apps.
        try {
            if (FocusPolicy.isSessionActive(c)) {
                ContextCompat.startForegroundService(c, Intent(c, FocusBlockingService::class.java))
            }
        } catch (_: Exception) {}

        // 4. The session card / queue.
        try {
            SessionUi.onEnded(c)
            if (SessionUi.state(c).active) SessionUi.refresh(c)
        } catch (_: Exception) {}

        // 5. The accessibility service.
        try { AccessibilityGuard.check(c) } catch (_: Exception) {}

        // 6. Next heartbeat.
        scheduleHeartbeat(c)
    }
}

/** The heartbeat alarm. */
class GuardianReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            Guardian.tick(context)
            Guardian.ensure(context)
        } catch (_: Exception) {}
    }
}

/** Persisted periodic job: runs about every 15 minutes, survives reboots, works when alarms are delayed. */
class GuardianJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        try {
            Guardian.tick(this)
            Guardian.ensure(this)
        } catch (_: Exception) {}
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean = true
}

class GuardianService : Service() {
    companion object {
        private const val CHANNEL = "godfident_guardian"
        private const val NOTIF_ID = 4402
    }

    private var receiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                val ch = NotificationChannel(CHANNEL, "Keeping Godfident ready", NotificationManager.IMPORTANCE_MIN)
                ch.description = "A quiet notification that keeps your reminders and Focus sessions on time"
                ch.setShowBadge(false)
                ch.setSound(null, null)
                nm.createNotificationChannel(ch)
            }
        }
        try {
            val f = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_TIME_CHANGED)
                addAction(Intent.ACTION_TIMEZONE_CHANGED)
                addAction(Intent.ACTION_POWER_CONNECTED)
            }
            val r = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent?) {
                    // The phone was opened (or the clock changed): make sure everything is armed.
                    try { Guardian.tick(context) } catch (_: Exception) {}
                }
            }
            receiver = r
            // Receives system broadcasts only; not exported to other apps.
            ContextCompat.registerReceiver(this, r, f, ContextCompat.RECEIVER_NOT_EXPORTED)
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val open = PendingIntent.getActivity(
            this, 4403, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val n = b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Godfident is ready")
            .setContentText("Keeping your reminders and Focus sessions on time")
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(open)
            .setPriority(Notification.PRIORITY_MIN)
            .build()
        try {
            startForeground(NOTIF_ID, n)
        } catch (_: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        try { Guardian.tick(this) } catch (_: Exception) {}
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiped from recents: make sure we (and every alarm) come straight back.
        try { Guardian.tick(this) } catch (_: Exception) {}
        Guardian.scheduleHeartbeat(this, 2_000L)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        receiver = null
        if (Guardian.isEnabled(this)) Guardian.scheduleHeartbeat(this, 5_000L)
        super.onDestroy()
    }
}

/**
 * Notices when Android has switched the Godfident accessibility service off
 * (battery managers and crash recovery do this) and brings it back:
 *  - if the phone allows it (WRITE_SECURE_SETTINGS granted once through adb) it is switched back on silently;
 *  - otherwise a notification takes the person straight to Accessibility settings.
 */
object AccessibilityGuard {
    private const val PREFS = "godfident_a11y_guard"
    const val KEY_WANTED = "wanted"
    private const val KEY_LAST_NAG = "last_nag"
    private const val NAG_EVERY_MS = 6L * 60L * 60L * 1000L
    private const val CHANNEL = "godfident_a11y_off"
    private const val NOTIF_ID = 4410

    private fun p(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun markWanted(c: Context, wanted: Boolean) = p(c).edit().putBoolean(KEY_WANTED, wanted).apply()

    fun check(c: Context) {
        if (!p(c).getBoolean(KEY_WANTED, false)) return
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (FocusAccessibilityService.isEnabled(c)) {
            nm.cancel(NOTIF_ID)
            return
        }
        if (tryRestore(c)) return
        val now = System.currentTimeMillis()
        if (now - p(c).getLong(KEY_LAST_NAG, 0L) < NAG_EVERY_MS) return
        p(c).edit().putLong(KEY_LAST_NAG, now).apply()
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Protection switched off", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val pi = PendingIntent.getActivity(
            c, 4411,
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        nm.notify(
            NOTIF_ID,
            b.setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("Godfident Focus was switched off")
                .setContentText("Android turned it off. Tap to switch it back on so apps and words stay blocked.")
                .setStyle(Notification.BigTextStyle().bigText("Android turned the Godfident Focus accessibility service off. Tap to open Accessibility settings and switch it back on, so blocked apps and words stay blocked."))
                .setAutoCancel(true)
                .setContentIntent(pi)
                .build()
        )
    }

    /** Works only if WRITE_SECURE_SETTINGS was granted (one-time adb command). Never throws. */
    private fun tryRestore(c: Context): Boolean {
        return try {
            if (c.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS") != PackageManager.PERMISSION_GRANTED) return false
            val me = ComponentName(c, FocusAccessibilityService::class.java).flattenToString()
            val cur = Settings.Secure.getString(c.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
            if (!cur.split(':').contains(me)) {
                val next = if (cur.isEmpty()) me else "$cur:$me"
                Settings.Secure.putString(c.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, next)
            }
            Settings.Secure.putInt(c.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 1)
            true
        } catch (_: Exception) {
            false
        }
    }
}
