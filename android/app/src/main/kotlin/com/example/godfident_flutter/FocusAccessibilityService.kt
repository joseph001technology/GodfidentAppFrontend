package com.example.godfident_flutter

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

/**
 * Instant app blocking.
 *
 * Android 10+ forbids a plain background service from opening screens, which is
 * why the usage-stats poller alone could only post a notification. An
 * accessibility service is told the moment ANY app window comes to the front,
 * and is allowed to press Home for the user. So when a blocked app opens during
 * a Focus session we immediately send the user Home and then bring Godfident up.
 *
 * It declares canRetrieveWindowContent="false": Godfident cannot read what is on
 * screen or what you type - it only learns which app window opened.
 */
class FocusAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var isConnected: Boolean = false
            private set

        /** True if the user has switched the service on in Android settings. */
        fun isEnabled(ctx: Context): Boolean {
            if (isConnected) return true
            return try {
                val enabled = Settings.Secure.getString(
                    ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                ) ?: return false
                val me = ComponentName(ctx, FocusAccessibilityService::class.java)
                enabled.split(':').any {
                    ComponentName.unflattenFromString(it) == me
                }
            } catch (_: Exception) {
                false
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockedPkg: String? = null
    private var lastBlockedAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        isConnected = true
    }

    override fun onUnbind(intent: Intent?): Boolean {
        isConnected = false
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        isConnected = false
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (!FocusPolicy.shouldBlock(this, pkg)) return

        // Debounce: one app opening can fire several window events.
        val now = System.currentTimeMillis()
        if (pkg == lastBlockedPkg && now - lastBlockedAt < 700) return
        lastBlockedPkg = pkg
        lastBlockedAt = now

        val label = FocusPolicy.labelFor(this, pkg)
        FocusPolicy.recordAttempt(this, label)

        // 1. Take the user out of the blocked app right now.
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 2. Say why, then bring Godfident forward.
        handler.post {
            try {
                Toast.makeText(this, "$label is blocked during your Focus session", Toast.LENGTH_SHORT).show()
            } catch (_: Exception) {
            }
        }
        handler.postDelayed({
            try {
                startActivity(
                    Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        putExtra(MainActivity.EXTRA_BLOCKED_APP_LABEL, label)
                    }
                )
            } catch (_: Exception) {
                // Home was already pressed, so the app is still not usable.
            }
        }, 150)
    }
}
