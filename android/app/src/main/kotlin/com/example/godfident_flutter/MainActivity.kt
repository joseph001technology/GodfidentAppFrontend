package com.example.godfident_flutter

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.content.ContentUris
import android.util.Size
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Method channel `com.godfident/focus_blocking` — the bridge between the Dart
 * restriction screens and the real Android enforcement:
 *  - [FocusBlockingService]    blocks launching of chosen apps (UsageStats)
 *  - [WebsiteBlockVpnService]  blocks chosen domains system-wide (local VPN/DNS)
 */
class MainActivity : AudioServiceActivity() {

    companion object {
        const val CHANNEL = "com.godfident/focus_blocking"
        const val EXTRA_BLOCKED_APP_LABEL = "extra_blocked_app_label"
        const val EXTRA_ALARM_ROUTE = "extra_alarm_route"
        /** A blocked website was closed: open the page that points back to God (Universal Rules or Bible). */
        const val EXTRA_REDIRECT_ROUTE = "extra_redirect_route"
        private const val REQ_VPN = 7001
    }

    private var pendingBlockedAppLabel: String? = null
    private var pendingAlarmRoute: String? = null
    private var channel: MethodChannel? = null
    private var pendingVpnResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeBlockedAppExtra(intent)
        consumeAlarmRoute(intent)
        consumeRedirect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeBlockedAppExtra(intent)
        consumeAlarmRoute(intent)
        consumeRedirect(intent)
    }

    private fun consumeRedirect(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_REDIRECT_ROUTE) ?: return
        intent.removeExtra(EXTRA_REDIRECT_ROUTE)
        val ch = channel
        if (ch != null) ch.invokeMethod("onAlarmRoute", route) else pendingAlarmRoute = route
    }

    /** Opened from a ringing alarm: stop the sound and tell Dart where to go. */
    private fun consumeAlarmRoute(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_ALARM_ROUTE) ?: return
        intent.removeExtra(EXTRA_ALARM_ROUTE)
        try { AlarmRingService.stop(this) } catch (_: Exception) {}
        val ch = channel
        if (ch != null) ch.invokeMethod("onAlarmRoute", route) else pendingAlarmRoute = route
    }

    private fun consumeBlockedAppExtra(intent: Intent?) {
        intent?.getStringExtra(EXTRA_BLOCKED_APP_LABEL)?.let { label ->
            pendingBlockedAppLabel = label
            focusPrefs().edit().putString(FocusBlockingService.KEY_LAST_BLOCKED_LABEL, label).apply()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_VPN) {
            pendingVpnResult?.success(resultCode == RESULT_OK)
            pendingVpnResult = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun focusPrefs() =
        getSharedPreferences(FocusBlockingService.PREFS_NAME, Context.MODE_PRIVATE)

    private fun webPrefs() =
        getSharedPreferences(WebsiteBlockVpnService.PREFS, Context.MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                // ───── app restriction / focus session ─────
                "hasUsageAccess" -> result.success(hasUsageAccess())

                "requestUsageAccess" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }

                "getInstalledApps" -> Thread {
                    val apps = try { getInstalledLaunchableApps() } catch (_: Exception) { emptyList() }
                    runOnUiThread { result.success(apps) }
                }.start()

                "startFocusSession" -> {
                    val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                    val endAt = (call.argument<Number>("endAtMs"))?.toLong() ?: 0L
                    val allowOnly = call.argument<Boolean>("allowOnly") ?: false
                    val intent = Intent(this, FocusBlockingService::class.java).apply {
                        putStringArrayListExtra(FocusBlockingService.EXTRA_BLOCKED_PACKAGES, ArrayList(packages))
                        putExtra(FocusBlockingService.EXTRA_END_AT, endAt)
                        putExtra(FocusBlockingService.EXTRA_ALLOW_ONLY, allowOnly)
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }

                "stopFocusSession" -> {
                    focusPrefs().edit().putBoolean(FocusBlockingService.KEY_SESSION_ACTIVE, false).apply()
                    stopService(Intent(this, FocusBlockingService::class.java))
                    result.success(true)
                }

                "isSessionActive" -> result.success(sessionInfo()["active"])

                "getSessionInfo" -> result.success(sessionInfo())

                "getBlockedAttemptCount" ->
                    result.success(focusPrefs().getInt(FocusBlockingService.KEY_BLOCKED_ATTEMPT_COUNT, 0))

                "getLastBlockedApp" -> {
                    val prefs = focusPrefs()
                    val label = pendingBlockedAppLabel
                        ?: prefs.getString(FocusBlockingService.KEY_LAST_BLOCKED_LABEL, null)
                    pendingBlockedAppLabel = null
                    prefs.edit().remove(FocusBlockingService.KEY_LAST_BLOCKED_LABEL).apply()
                    result.success(label)
                }

                // ───── website protection (VPN/DNS) ─────
                "websiteStatus" -> result.success(websiteStatus())

                // ───── accessibility (instant app blocking) ─────
                "isAccessibilityEnabled" -> result.success(FocusAccessibilityService.isEnabled(this))

                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }

                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                // ───── ringing alarms (reminder alarms, pre-set Focus sessions) ─────
                "scheduleAlarm" -> {
                    try {
                        AlarmScheduler.schedule(
                            this,
                            AlarmScheduler.Alarm(
                                id = call.argument<Int>("id") ?: 0,
                                whenMs = (call.argument<Number>("whenMs") ?: 0).toLong(),
                                repeatMs = (call.argument<Number>("repeatMs") ?: 0).toLong(),
                                title = call.argument<String>("title") ?: "",
                                body = call.argument<String>("body") ?: "",
                                route = call.argument<String>("route") ?: "",
                                soundUri = resolveSound(call.argument<String>("sound") ?: ""),
                                maxSeconds = call.argument<Int>("maxSeconds") ?: 60,
                                startLabel = call.argument<String>("startLabel") ?: "",
                                ring = call.argument<Boolean>("ring") ?: true
                            )
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "rearmAlarms" -> {
                    // App started: make sure every stored alarm is armed, ring ones that
                    // are less than an hour late and report older ones as missed.
                    try { AlarmScheduler.rearmAll(this) } catch (_: Exception) {}
                    result.success(true)
                }
                "cancelAlarm" -> {
                    AlarmScheduler.cancel(this, call.argument<Int>("id") ?: 0)
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    AlarmRingService.stop(this)
                    result.success(true)
                }
                "getLaunchRoute" -> {
                    val r = pendingAlarmRoute
                    pendingAlarmRoute = null
                    result.success(r)
                }
                "canScheduleExactAlarms" -> {
                    val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    result.success(Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms())
                }

                // ───── songs stored on the device (MediaStore) ─────
                "getDeviceSongs" -> Thread {
                    val songs = try { queryDeviceSongs() } catch (_: Exception) { emptyList() }
                    runOnUiThread { result.success(songs) }
                }.start()

                "getSongArtwork" -> {
                    val uri = call.argument<String>("uri")
                    Thread {
                        val bytes = try { loadArtwork(uri) } catch (_: Exception) { null }
                        runOnUiThread { result.success(bytes) }
                    }.start()
                }

                "requestVpnPermission" -> {
                    val prepare = VpnService.prepare(this)
                    if (prepare == null) {
                        result.success(true)
                    } else {
                        pendingVpnResult?.success(false)
                        pendingVpnResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(prepare, REQ_VPN)
                    }
                }

                "setBlockedKeywords" -> {
                    val words = call.argument<List<String>>("keywords") ?: emptyList()
                    webPrefs().edit().putStringSet(WebsiteBlockVpnService.KEY_KEYWORDS, words.toSet()).apply()
                    result.success(true)
                }
                "setBlockedDomains" -> {
                    val domains = call.argument<List<String>>("domains") ?: emptyList()
                    webPrefs().edit().putStringSet(WebsiteBlockVpnService.KEY_DOMAINS, domains.toSet()).apply()
                    result.success(true)
                }

                "startWebsiteProtection" -> {
                    if (VpnService.prepare(this) != null) {
                        result.success(false) // consent missing: Dart must request it first
                    } else {
                        webPrefs().edit().putBoolean(WebsiteBlockVpnService.KEY_ACTIVE, true).apply()
                        ContextCompat.startForegroundService(this, Intent(this, WebsiteBlockVpnService::class.java))
                        result.success(true) // "requested" — Dart verifies via websiteStatus
                    }
                }

                "stopWebsiteProtection" -> {
                    webPrefs().edit().putBoolean(WebsiteBlockVpnService.KEY_ACTIVE, false).apply()
                    startService(
                        Intent(this, WebsiteBlockVpnService::class.java)
                            .setAction(WebsiteBlockVpnService.ACTION_STOP)
                    )
                    result.success(true)
                }

                "openVpnSettings" -> {
                    startActivity(Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /** "raw:godfident_bell" -> android.resource:// URI of the bundled tone; anything else is used as is. */
    private fun resolveSound(s: String): String {
        if (s.startsWith("raw:")) {
            val name = s.removePrefix("raw:")
            val id = resources.getIdentifier(name, "raw", packageName)
            if (id != 0) return "android.resource://$packageName/$id"
            return ""
        }
        return s
    }

    private fun sessionInfo(): Map<String, Any> {
        val p = focusPrefs()
        val endAt = p.getLong(FocusBlockingService.KEY_END_AT, 0L)
        val flagged = p.getBoolean(FocusBlockingService.KEY_SESSION_ACTIVE, false)
        val active = flagged && (endAt == 0L || endAt > System.currentTimeMillis())
        return mapOf(
            "active" to active,
            "endAtMs" to endAt,
            "allowOnly" to p.getBoolean(FocusBlockingService.KEY_ALLOW_ONLY, false),
            "attempts" to p.getInt(FocusBlockingService.KEY_BLOCKED_ATTEMPT_COUNT, 0)
        )
    }

    private fun websiteStatus(): Map<String, Any> {
        val p = webPrefs()
        val privateDns = try {
            Settings.Global.getString(contentResolver, "private_dns_mode") == "hostname"
        } catch (_: Exception) {
            false
        }
        return mapOf(
            "vpnPermissionGranted" to (VpnService.prepare(this) == null),
            "running" to WebsiteBlockVpnService.isRunning,
            "wanted" to p.getBoolean(WebsiteBlockVpnService.KEY_ACTIVE, false),
            "blockedLookups" to p.getInt(WebsiteBlockVpnService.KEY_BLOCKED_COUNT, 0),
            "privateDnsStrict" to privateDns,
            "totalQueries" to WebsiteBlockVpnService.totalQueries,
            "lastHost" to WebsiteBlockVpnService.lastHost,
            "lastError" to WebsiteBlockVpnService.lastError
        )
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Real installed launchable apps (name, package, icon). Excludes Godfident itself. */
    private fun getInstalledLaunchableApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(launcherIntent, 0)
            .mapNotNull { ri ->
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName) return@mapNotNull null
                val icon: ByteArray? = try {
                    val bmp = ri.loadIcon(pm).toBitmap(64, 64)
                    val out = ByteArrayOutputStream()
                    bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
                    out.toByteArray()
                } catch (_: Exception) {
                    null
                }
                mapOf<String, Any?>(
                    "packageName" to pkg,
                    "label" to ri.loadLabel(pm).toString(),
                    "icon" to icon
                )
            }
            .distinctBy { it["packageName"] as String }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    /** Real audio files on the phone, straight from Android's media database. */
    private fun queryDeviceSongs(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION
        )
        // Real music only: skips ringtones/notification sounds and clips under 20 s.
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= 20000"
        contentResolver.query(collection, projection, selection, null, "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC")?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val artist = c.getString(artistCol)
                out.add(
                    mapOf(
                        "id" to id,
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "title" to (c.getString(titleCol) ?: "Unknown"),
                        "artist" to (if (artist == null || artist == "<unknown>") "Unknown artist" else artist),
                        "album" to (c.getString(albumCol) ?: ""),
                        "durationMs" to c.getLong(durCol)
                    )
                )
            }
        }
        return out
    }

    private fun loadArtwork(uri: String?): ByteArray? {
        if (uri == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val bmp = contentResolver.loadThumbnail(Uri.parse(uri), Size(160, 160), null)
        val stream = ByteArrayOutputStream()
        bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, stream)
        return stream.toByteArray()
    }
}
