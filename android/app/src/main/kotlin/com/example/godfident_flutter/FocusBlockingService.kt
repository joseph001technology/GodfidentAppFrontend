package com.example.godfident_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Real Focus Mode enforcement.
 *
 * While a Focus session is active, this runs as a foreground service (so
 * Android doesn't kill it) and polls [UsageStatsManager] roughly once a
 * second for whichever app is currently in the foreground. If that app's
 * package name is on the current session's block list, we relaunch
 * [MainActivity] (bringing Godfident back to the front) and stash the
 * blocked app's label so the Dart side can show a "You tried to open
 * TikTok during Focus Mode" screen the next time it asks
 * `getLastBlockedApp` on the method channel — see MainActivity.kt.
 *
 * This is polling-based, not push-based (no AccessibilityService), which
 * is the standard, lower-friction approach most Android app-blockers use.
 * It's not pixel-perfect instantaneous, but it reliably catches a blocked
 * app within ~1 second of it coming to the foreground.
 */
class FocusBlockingService : Service() {

    companion object {
        const val PREFS_NAME = "focus_blocking_prefs"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_BLOCKED_ATTEMPT_COUNT = "blocked_attempt_count"
        const val KEY_LAST_BLOCKED_LABEL = "last_blocked_app_label"
        const val KEY_SESSION_ACTIVE = "session_active"
        const val KEY_END_AT = "session_end_at_ms"      // 0 = no end time
        const val KEY_ALLOW_ONLY = "session_allow_only" // "only Godfident" mode
        const val EXTRA_BLOCKED_PACKAGES = "extra_blocked_packages"
        const val EXTRA_END_AT = "extra_end_at_ms"
        const val EXTRA_ALLOW_ONLY = "extra_allow_only"

        private const val NOTIFICATION_CHANNEL_ID = "focus_mode_active"
        private const val NOTIFICATION_ID = 4201
        private const val POLL_INTERVAL_MS = 1000L
    }

    private lateinit var prefs: SharedPreferences
    private lateinit var usageStatsManager: UsageStatsManager
    private val pollHandler = Handler(Looper.getMainLooper())
    private var blockedPackages: Set<String> = emptySet()
    private var ownPackageName: String = ""
    private var endAtMs: Long = 0L
    private var allowOnly: Boolean = false
    private var alwaysAllowed: Set<String> = emptySet()

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            pollHandler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        ownPackageName = packageName
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.hasExtra(EXTRA_BLOCKED_PACKAGES)) {
            // Fresh start from the app.
            blockedPackages = intent.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES)?.toSet() ?: emptySet()
            endAtMs = intent.getLongExtra(EXTRA_END_AT, 0L)
            allowOnly = intent.getBooleanExtra(EXTRA_ALLOW_ONLY, false)
            prefs.edit()
                .putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages)
                .putBoolean(KEY_SESSION_ACTIVE, true)
                .putLong(KEY_END_AT, endAtMs)
                .putBoolean(KEY_ALLOW_ONLY, allowOnly)
                .putInt(KEY_BLOCKED_ATTEMPT_COUNT, 0)
                .apply()
        } else {
            // Restart after the OS killed us / after reboot: restore saved session.
            blockedPackages = prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
            endAtMs = prefs.getLong(KEY_END_AT, 0L)
            allowOnly = prefs.getBoolean(KEY_ALLOW_ONLY, false)
            if (!prefs.getBoolean(KEY_SESSION_ACTIVE, false)) {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        if (endAtMs != 0L && endAtMs <= System.currentTimeMillis()) {
            prefs.edit().putBoolean(KEY_SESSION_ACTIVE, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }

        alwaysAllowed = computeAlwaysAllowed()
        startForeground(NOTIFICATION_ID, buildNotification())
        pollHandler.removeCallbacks(pollRunnable)
        pollHandler.post(pollRunnable)
        return START_STICKY
    }

    /** Apps that must never be blocked in "only Godfident" mode so the phone stays usable. */
    private fun computeAlwaysAllowed(): Set<String> {
        val set = mutableSetOf(ownPackageName, "com.android.systemui", "com.android.settings")
        try {
            val home = packageManager.resolveActivity(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            home?.activityInfo?.packageName?.let { set.add(it) }
            val dial = packageManager.resolveActivity(Intent(Intent.ACTION_DIAL), 0)
            dial?.activityInfo?.packageName?.let { set.add(it) }
            val ime = android.provider.Settings.Secure.getString(
                contentResolver, android.provider.Settings.Secure.DEFAULT_INPUT_METHOD)
            ime?.substringBefore('/')?.let { set.add(it) }
        } catch (_: Exception) {
        }
        return set
    }

    override fun onDestroy() {
        pollHandler.removeCallbacks(pollRunnable)
        // KEY_SESSION_ACTIVE is cleared only on an explicit stop or when the
        // session time runs out, so a process kill + restart can resume it.
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        if (!FocusPolicy.isSessionActive(this)) {
            // Session finished (or ended) - stop by ourselves.
            stopSelf()
            return
        }
        // When the accessibility service is on it already handles blocking
        // instantly; the poller only matters as a fallback.
        if (FocusAccessibilityService.isConnected) return

        val foregroundPackage = currentForegroundPackage() ?: return
        if (!FocusPolicy.shouldBlock(this, foregroundPackage)) return

        val label = appLabelFor(foregroundPackage)
        FocusPolicy.recordAttempt(this, label)
        bringGodfidentToFront(label)
    }

    /**
     * Finds the most recently foregrounded app via usage-events in the last
     * few seconds. Requires PACKAGE_USAGE_STATS — see AndroidManifest.xml
     * and MainActivity's hasUsageAccess/requestUsageAccess handlers. If
     * that permission hasn't been granted, this silently returns null and
     * blocking simply doesn't happen (Dart side should check
     * `hasUsageAccess` before letting a session start).
     */
    private fun currentForegroundPackage(): String? {
        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - 10_000, now)
        var lastForegroundPackage: String? = null
        val event = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastForegroundPackage = event.packageName
            }
        }
        return lastForegroundPackage
    }

    private fun appLabelFor(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun bringGodfidentToFront(blockedAppLabel: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(MainActivity.EXTRA_BLOCKED_APP_LABEL, blockedAppLabel)
        }
        startActivity(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Focus Mode active",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shown while Godfident is protecting your focus session"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): android.app.Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(ownPackageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Focus session active")
            .setContentText("Godfident is protecting your time with God.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }
}
