package com.example.godfident_flutter

import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Single place that answers "should this package be blocked right now?" so the
 * accessibility service (instant, primary) and the usage-stats poller
 * (fallback) always agree.
 */
object FocusPolicy {

    private var cachedAllowed: Set<String> = emptySet()
    private var cachedAt = 0L

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(FocusBlockingService.PREFS_NAME, Context.MODE_PRIVATE)

    fun isSessionActive(ctx: Context): Boolean {
        val p = prefs(ctx)
        if (!p.getBoolean(FocusBlockingService.KEY_SESSION_ACTIVE, false)) return false
        val endAt = p.getLong(FocusBlockingService.KEY_END_AT, 0L)
        if (endAt != 0L && endAt <= System.currentTimeMillis()) {
            // Time is up: end the session natively, even if Godfident is closed.
            p.edit().putBoolean(FocusBlockingService.KEY_SESSION_ACTIVE, false).apply()
            return false
        }
        return true
    }

    /** Apps that must stay usable in "only Godfident" mode so the phone is never bricked. */
    private fun alwaysAllowed(ctx: Context): Set<String> {
        val now = System.currentTimeMillis()
        if (now - cachedAt < 60_000 && cachedAllowed.isNotEmpty()) return cachedAllowed
        val set = mutableSetOf(ctx.packageName, "com.android.systemui", "com.android.settings")
        try {
            val pm = ctx.packageManager
            pm.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
                ?.activityInfo?.packageName?.let { set.add(it) }
            pm.resolveActivity(Intent(Intent.ACTION_DIAL), 0)?.activityInfo?.packageName?.let { set.add(it) }
            Settings.Secure.getString(ctx.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                ?.substringBefore('/')?.let { set.add(it) }
            // Emergency / telephony UI must never be blocked.
            set.add("android")
            set.add("com.android.permissioncontroller")
            set.add("com.google.android.permissioncontroller")
            set.add("com.android.packageinstaller")
            set.add("com.google.android.packageinstaller")
            set.add("com.android.phone")
            set.add("com.android.server.telecom")
            set.add("com.google.android.dialer")
        } catch (_: Exception) {
        }
        cachedAllowed = set
        cachedAt = now
        return set
    }

    fun shouldBlock(ctx: Context, pkg: String?): Boolean {
        if (pkg.isNullOrEmpty() || pkg == ctx.packageName) return false
        if (!isSessionActive(ctx)) return false
        val p = prefs(ctx)
        return if (p.getBoolean(FocusBlockingService.KEY_ALLOW_ONLY, false)) {
            pkg !in alwaysAllowed(ctx)
        } else {
            pkg in (p.getStringSet(FocusBlockingService.KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet())
        }
    }

    fun labelFor(ctx: Context, pkg: String): String = try {
        val pm = ctx.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        pkg
    }

    fun recordAttempt(ctx: Context, label: String) {
        val p = prefs(ctx)
        p.edit()
            .putInt(FocusBlockingService.KEY_BLOCKED_ATTEMPT_COUNT, p.getInt(FocusBlockingService.KEY_BLOCKED_ATTEMPT_COUNT, 0) + 1)
            .putString(FocusBlockingService.KEY_LAST_BLOCKED_LABEL, label)
            .apply()
    }
}
