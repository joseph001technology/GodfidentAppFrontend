package com.example.godfident_flutter

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle

/**
 * The target of Android's "Share > Godfident" (plain text: a video link).
 *
 * It has no screen. It immediately hands the same share to [MainActivity] in Godfident's own task and
 * closes, where OnlineVideoPlugin reads it. This keeps MainActivity's launch mode and its LAUNCHER filter
 * exactly as they were (so alarms, Focus sessions and normal launches behave as before) while making sure a
 * share opens Godfident itself rather than a copy inside the sharing app's task.
 */
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            if (intent?.action == Intent.ACTION_SEND) {
                val fwd = Intent(intent)
                fwd.component = ComponentName(this, MainActivity::class.java)
                // Fresh flags: only what is needed to reach the running (or start a new) MainActivity.
                fwd.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                startActivity(fwd)
            }
        } catch (_: Exception) {
            // Nothing sensible to show from here; the person simply stays in the sharing app.
        }
        finish()
    }
}
