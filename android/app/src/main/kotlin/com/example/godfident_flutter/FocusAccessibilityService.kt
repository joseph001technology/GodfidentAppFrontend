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

        /** Package of the app window currently in front (ignores keyboards / system UI). */
        @Volatile private var frontPkg: String = ""
        @Volatile private var instance: FocusAccessibilityService? = null

        /** Browsers whose address bar we can read: package -> address-bar view ids. */
        private val BROWSER_URL_IDS: Map<String, List<String>> = mapOf(
            "com.android.chrome" to listOf("com.android.chrome:id/url_bar"),
            "com.chrome.beta" to listOf("com.chrome.beta:id/url_bar"),
            "com.sec.android.app.sbrowser" to listOf("com.sec.android.app.sbrowser:id/location_bar_edit_text"),
            "org.mozilla.firefox" to listOf("org.mozilla.firefox:id/mozac_browser_toolbar_url_view", "org.mozilla.firefox:id/url_bar_title"),
            "com.brave.browser" to listOf("com.brave.browser:id/url_bar"),
            "com.microsoft.emmx" to listOf("com.microsoft.emmx:id/url_bar"),
            "com.opera.browser" to listOf("com.opera.browser:id/url_field"),
            "com.opera.mini.native" to listOf("com.opera.mini.native:id/url_field"),
            "com.duckduckgo.mobile.android" to listOf("com.duckduckgo.mobile.android:id/omnibarTextInput"),
            "com.kiwibrowser.browser" to listOf("com.kiwibrowser.browser:id/url_bar"),
            "com.vivaldi.browser" to listOf("com.vivaldi.browser:id/url_bar"),
        )

        /** Called by the DNS filter when a blocked name was looked up. Acts only if a browser is in front. */
        fun onBlockedLookup() {
            val svc = instance ?: return
            if (BROWSER_URL_IDS.containsKey(frontPkg) || frontPkg.contains("browser")) {
                svc.handler.post { svc.closeBlockedPage("That website is blocked") }
            }
        }

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

    private var lastRedirectAt = 0L
    private var lastUrlCheckAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        isConnected = true
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        isConnected = false
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        isConnected = false
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    /**
     * Takes the person out of a blocked page: Back (closes a freshly opened tab or leaves the
     * page), then Home so the page is no longer visible, then opens Godfident on the Universal
     * Rules (or the Bible). Android does not let one app close another app's tab directly.
     */
    private fun closeBlockedPage(message: String) {
        val now = System.currentTimeMillis()
        if (now - lastRedirectAt < 4000) return
        lastRedirectAt = now
        performGlobalAction(GLOBAL_ACTION_BACK)
        handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 250)
        try { Toast.makeText(this, message, Toast.LENGTH_LONG).show() } catch (_: Exception) {}
        handler.postDelayed({
            try {
                startActivity(
                    Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        putExtra(MainActivity.EXTRA_REDIRECT_ROUTE, "/blocked-redirect")
                    }
                )
            } catch (_: Exception) {}
        }, 600)
    }

    /** Reads ONLY the address bar of a known browser, in memory, never stored or sent. */
    private fun checkAddressBar(pkg: String) {
        val now = System.currentTimeMillis()
        if (now - lastUrlCheckAt < 350) return
        lastUrlCheckAt = now
        val ids = BROWSER_URL_IDS[pkg] ?: return
        val prefs = getSharedPreferences(WebsiteBlockVpnService.PREFS, Context.MODE_PRIVATE)
        val domains = prefs.getStringSet(WebsiteBlockVpnService.KEY_DOMAINS, emptySet()) ?: emptySet()
        val words = prefs.getStringSet(WebsiteBlockVpnService.KEY_KEYWORDS, emptySet()) ?: emptySet()
        if (domains.isEmpty() && words.isEmpty()) return
        val root = try { rootInActiveWindow } catch (_: Exception) { null } ?: return
        for (id in ids) {
            val nodes = try { root.findAccessibilityNodeInfosByViewId(id) } catch (_: Exception) { null } ?: continue
            for (n in nodes) {
                val text = n.text?.toString() ?: ""
                if (text.isNotEmpty() && WebsiteBlockVpnService.addressBlocked(text, domains, words)) {
                    closeBlockedPage("That is blocked. Spend this moment with God instead.")
                    return
                }
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            if (BROWSER_URL_IDS.containsKey(pkg)) checkAddressBar(pkg)
            return
        }
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (!pkg.contains("inputmethod") && !pkg.contains("keyboard") && pkg != "com.android.systemui") frontPkg = pkg
        if (BROWSER_URL_IDS.containsKey(pkg)) checkAddressBar(pkg)
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
