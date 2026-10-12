package com.example.godfident_flutter

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
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
 * Blocked WORDS: besides browser address bars, it looks at what is typed into search
 * boxes in ANY app (Telegram, X, Instagram, YouTube, TikTok ...). The text is compared
 * in memory with the words you chose to block, then forgotten; it is never stored or
 * sent, password fields are skipped, and Godfident's own screens are never checked.
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

        /** Parts of a view id that mean "this is a search box" (search_edit_text, query, omnibox ...). */
        private val SEARCH_ID_PARTS = listOf("search", "query", "omnibox", "url_bar", "location_bar", "find", "et_kw", "keyword")

        /** Words in a box's hint that mean the same, in a few common languages. */
        private val SEARCH_HINTS = listOf(
            "search", "find", "look up", "tafuta", "buscar", "rechercher", "recherche", "suche", "pesquisar", "cerca", "поиск", "搜索", "검색", "ابحث", "بحث"
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
        // From now on Godfident knows the person wants this on, and can bring it back if Android turns it off.
        try { AccessibilityGuard.markWanted(this, true) } catch (_: Throwable) {}
        // The system starts this service at boot even when other background starts are blocked:
        // use that moment to bring the background guardian and every alarm back.
        try { Guardian.ensure(this) } catch (_: Throwable) {}
        try { AlarmScheduler.rearmAll(this, 90_000L) } catch (_: Throwable) {}
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

    // ───────────── blocked words typed in other apps ─────────────

    private var lastScanAt = 0L

    private fun blockedWords(): Set<String> =
        getSharedPreferences(WebsiteBlockVpnService.PREFS, Context.MODE_PRIVATE)
            .getStringSet(WebsiteBlockVpnService.KEY_KEYWORDS, emptySet()) ?: emptySet()

    private fun isIgnoredPackage(pkg: String): Boolean =
        pkg == packageName || pkg == "com.android.systemui" || pkg.contains("inputmethod") || pkg.contains("keyboard")

    /** A box meant for searching (not a chat message): by its id name or its hint text. */
    private fun looksLikeSearchBox(n: AccessibilityNodeInfo, pkg: String): Boolean {
        if (BROWSER_URL_IDS.containsKey(pkg) || pkg.contains("browser") || pkg.contains("searchbox") || pkg.contains("quicksearch")) return true
        val id = (n.viewIdResourceName ?: "").lowercase()
        if (SEARCH_ID_PARTS.any { id.contains(it) }) return true
        val hint = try { if (Build.VERSION.SDK_INT >= 26) n.hintText?.toString()?.lowercase() ?: "" else "" } catch (_: Throwable) { "" }
        if (hint.isNotEmpty() && SEARCH_HINTS.any { hint.contains(it) }) return true
        val desc = n.contentDescription?.toString()?.lowercase() ?: ""
        return desc.isNotEmpty() && SEARCH_HINTS.any { desc.contains(it) }
    }

    private fun isEditText(n: AccessibilityNodeInfo): Boolean =
        n.isEditable || (n.className?.toString() ?: "").endsWith("EditText")

    private fun clearField(n: AccessibilityNodeInfo?) {
        if (n == null) return
        try {
            val args = Bundle()
            args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "")
            n.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Throwable) {}
    }

    /** The person is typing: if it is a search box and the text holds a blocked word, stop it. */
    private fun checkTyping(event: AccessibilityEvent, pkg: String) {
        if (isIgnoredPackage(pkg)) return
        val words = blockedWords()
        if (words.isEmpty()) return
        val src = event.source ?: return
        if (src.isPassword) return
        val text = event.text?.joinToString(" ") { it?.toString() ?: "" } ?: ""
        if (text.isBlank() || !WebsiteBlockVpnService.hasBlockedWord(text, words)) return
        if (!looksLikeSearchBox(src, pkg)) return
        clearField(src)
        closeBlockedPage("That word is blocked. Spend this moment with God instead.")
    }

    /**
     * A page can reach a blocked search without typing it (tapping a trend, a hashtag, a suggestion).
     * Looks at the search boxes currently on screen - and only those - for a blocked word.
     */
    private fun scanSearchBoxes(pkg: String) {
        if (isIgnoredPackage(pkg)) return
        val now = System.currentTimeMillis()
        if (now - lastScanAt < 700) return
        lastScanAt = now
        val words = blockedWords()
        if (words.isEmpty()) return
        val root = try { rootInActiveWindow } catch (_: Throwable) { null } ?: return
        if (root.packageName?.toString() != pkg) return
        var visited = 0
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && visited < 300) {
            val n = stack.removeLast()
            visited++
            try {
                if (!n.isPassword && isEditText(n) && looksLikeSearchBox(n, pkg)) {
                    val t = n.text?.toString() ?: ""
                    if (t.isNotBlank() && WebsiteBlockVpnService.hasBlockedWord(t, words)) {
                        clearField(n)
                        closeBlockedPage("That word is blocked. Spend this moment with God instead.")
                        return
                    }
                }
                for (i in 0 until n.childCount) n.getChild(i)?.let { stack.addLast(it) }
            } catch (_: Throwable) {}
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // An exception that escapes from here makes Android switch the service OFF by itself.
        try {
            handleEvent(event)
        } catch (_: Throwable) {
        }
    }

    private fun handleEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            checkTyping(event, pkg)
            return
        }
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            if (BROWSER_URL_IDS.containsKey(pkg)) checkAddressBar(pkg) else scanSearchBoxes(pkg)
            return
        }
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (!pkg.contains("inputmethod") && !pkg.contains("keyboard") && pkg != "com.android.systemui") frontPkg = pkg
        if (BROWSER_URL_IDS.containsKey(pkg)) checkAddressBar(pkg) else scanSearchBoxes(pkg)
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
