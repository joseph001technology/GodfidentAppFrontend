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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Method channel `com.godfident/focus_blocking` — the bridge between the Dart
 * restriction screens and the real Android enforcement:
 *  - [FocusBlockingService]    blocks launching of chosen apps (UsageStats)
 *  - [WebsiteBlockVpnService]  blocks chosen domains system-wide (local VPN/DNS)
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.godfident/focus_blocking"
        const val EXTRA_BLOCKED_APP_LABEL = "extra_blocked_app_label"
        private const val REQ_VPN = 7001
    }

    private var pendingBlockedAppLabel: String? = null
    private var pendingVpnResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeBlockedAppExtra(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        consumeBlockedAppExtra(intent)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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

                // Android never lets a normal app silently remove another app.
                // This opens the system "Uninstall?" dialog; the user confirms.
                "uninstallApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank() || pkg == packageName) {
                        result.success(false)
                    } else {
                        try {
                            startActivity(
                                Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
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
