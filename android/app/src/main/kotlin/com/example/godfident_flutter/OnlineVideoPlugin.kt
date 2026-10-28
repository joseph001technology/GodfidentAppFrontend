package com.example.godfident_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.DatabaseUtils
import android.database.sqlite.SQLiteConstraintException
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors

/**
 * Online Videos (saved links to videos that stay on Instagram / TikTok / Facebook / YouTube ...).
 *
 *  - STORAGE: a small SQLite database in the app's private storage (godfident_online_videos.db).
 *    Android's own SQLite - no extra library, no server. It stores only links and titles, never video files.
 *  - SHARE: receives ACTION_SEND text from Android's share menu. The share first lands in the screenless
 *    ShareReceiverActivity (the only share filter, see AndroidManifest.xml), which forwards it to MainActivity;
 *    this plugin reads it there and hands it to Dart. Works when Godfident is closed (the intent that started
 *    MainActivity is read when the plugin attaches) and when it is open (onNewIntent).
 *  - CONNECTIVITY: tells Dart when the phone gains/loses internet, so thumbnails and playback
 *    resume by themselves.
 *  - OPENING: starts the in-app viewer (OnlineVideoPlayerActivity) or the platform's app / browser.
 *
 * Nothing in this file touches the network or the Godfident server.
 * Registered from MainActivity.configureFlutterEngine; it does not touch any other feature.
 */
class OnlineVideoPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener {

    companion object {
        const val CHANNEL = "com.godfident/online_videos"

        /** Shares waiting for Dart (text, subject). A queue, so two quick shares are both kept. */
        private val pending = ConcurrentLinkedQueue<Pair<String, String>>()
    }

    private var ctx: Context? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var db: OvDb? = null
    private val io = Executors.newSingleThreadExecutor() // one thread: database calls never overlap
    private val main = Handler(Looper.getMainLooper())

    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var lastOnline: Boolean? = null

    // ───────────── plugin lifecycle ─────────────

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        ctx = b.applicationContext
        db = OvDb(b.applicationContext)
        channel = MethodChannel(b.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        registerNetwork()
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        unregisterNetwork()
        channel?.setMethodCallHandler(null)
        channel = null
        io.shutdown()
        try { db?.close() } catch (_: Exception) {}
        db = null
        ctx = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        binding = b
        b.addOnNewIntentListener(this)
        // Godfident was started by a share while it was closed: the starting intent carries the text.
        handleIntent(b.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        binding?.removeOnNewIntentListener(this)
        binding = null
        activity = null
    }

    /** Godfident was already open and a share arrived. */
    override fun onNewIntent(intent: Intent): Boolean {
        handleIntent(intent)
        return false // let MainActivity and the other plugins see the intent too
    }

    // ───────────── share intake ─────────────

    /**
     * Only plain-text shares (what Instagram, TikTok, Facebook and YouTube send for "Share link").
     * Everything else (the app's normal launch, alarm / session intents ...) is ignored, so the
     * existing launch behaviour is untouched.
     */
    private fun handleIntent(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        // Re-opened from the recent-apps list: the old share intent comes back. Do not save it again.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val type = intent.type ?: ""
        if (!type.startsWith("text/")) return

        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: ""
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: intent.getStringExtra(Intent.EXTRA_TITLE) ?: ""

        // Consume it, so a re-delivered intent (process restore, rotation) is not handled twice.
        intent.action = null
        intent.removeExtra(Intent.EXTRA_TEXT)

        pending.add(Pair(text, subject))
        // Dart may not be running yet (cold start): it asks by itself when it starts. If it is, this wakes it.
        main.post { try { channel?.invokeMethod("shared", null) } catch (_: Exception) {} }
    }

    // ───────────── connectivity ─────────────

    private fun isOnlineNow(): Boolean {
        val c = ctx ?: return true
        val cm = c.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return true
        return try {
            if (Build.VERSION.SDK_INT >= 23) {
                val n = cm.activeNetwork
                val caps = if (n == null) null else cm.getNetworkCapabilities(n)
                caps != null &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.isConnected == true
            }
        } catch (_: SecurityException) {
            true // cannot tell: do not block the person
        }
    }

    private fun pushOnline(online: Boolean) {
        if (lastOnline == online) return
        lastOnline = online
        main.post { try { channel?.invokeMethod("connectivity", online) } catch (_: Exception) {} }
    }

    private fun registerNetwork() {
        try {
            val c = ctx ?: return
            val cm = c.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    pushOnline(
                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                    )
                }

                override fun onLost(network: Network) {
                    pushOnline(isOnlineNow())
                }
            }
            cm.registerNetworkCallback(
                NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(), cb
            )
            netCallback = cb
        } catch (_: Exception) {
            // Needs ACCESS_NETWORK_STATE (declared in the manifest). Without it Dart simply asks isOnline on demand.
        }
    }

    private fun unregisterNetwork() {
        try {
            val cb = netCallback ?: return
            (ctx?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)?.unregisterNetworkCallback(cb)
        } catch (_: Exception) {}
        netCallback = null
    }

    // ───────────── opening ─────────────

    private fun httpUri(raw: String): Uri? {
        val u = try { Uri.parse(raw) } catch (_: Exception) { return null }
        return if (u.scheme == "https" || u.scheme == "http") u else null
    }

    /** The platform's own app if it handles the link, otherwise the browser. */
    private fun openExternal(url: String): Boolean {
        val uri = httpUri(url) ?: return false
        val from: Context = activity ?: ctx ?: return false
        val i = Intent(Intent.ACTION_VIEW, uri)
        if (activity == null) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            from.startActivity(i)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    /** The in-app viewer: an official embed page in a WebView, with Back and "Open original". */
    private fun play(call: MethodCall): Boolean {
        val embed = call.argument<String>("embedUrl") ?: return false
        val uri = httpUri(embed) ?: return false
        if (uri.scheme != "https") return false
        val from: Context = activity ?: ctx ?: return false
        val i = Intent(from, OnlineVideoPlayerActivity::class.java)
            .putExtra(OnlineVideoPlayerActivity.EXTRA_EMBED, embed)
            .putExtra(OnlineVideoPlayerActivity.EXTRA_URL, call.argument<String>("originalUrl") ?: embed)
            .putExtra(OnlineVideoPlayerActivity.EXTRA_TITLE, call.argument<String>("title") ?: "")
            .putExtra(OnlineVideoPlayerActivity.EXTRA_PLATFORM, call.argument<String>("platform") ?: "")
        if (activity == null) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            from.startActivity(i)
            true
        } catch (_: Exception) {
            false
        }
    }

    // ───────────── method channel ─────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "page" -> dbCall(result) {
                it.page(
                    call.argument<Int>("offset") ?: 0,
                    (call.argument<Int>("limit") ?: 24).coerceIn(1, 100),
                    call.argument<String>("scope") ?: "all",
                    call.argument<String>("collectionId")
                )
            }
            "add" -> dbCall(result) {
                it.add(
                    call.argument<String>("id") ?: "",
                    call.argument<String>("url") ?: "",
                    call.argument<String>("key") ?: "",
                    call.argument<String>("platform") ?: "other",
                    call.argument<String>("title"),
                    call.argument<String>("thumbUrl"),
                    call.argument<String>("collectionId")
                )
            }
            "get" -> dbCall(result) { it.get(call.argument<String>("id") ?: "") }
            "remove" -> dbCall(result) { it.remove(call.argument<String>("id") ?: "") }
            "setCollection" -> dbCall(result) {
                it.setCollection(call.argument<String>("id") ?: "", call.argument<String>("collectionId"))
            }
            "rename" -> dbCall(result) {
                it.rename(call.argument<String>("id") ?: "", call.argument<String>("title") ?: "")
            }
            "saveMeta" -> dbCall(result) {
                it.saveMeta(
                    call.argument<String>("id") ?: "",
                    call.argument<String>("title"),
                    call.argument<String>("thumbUrl"),
                    call.argument<Int>("state") ?: 0
                )
            }
            "collections" -> dbCall(result) { it.collections() }
            "createCollection" -> dbCall(result) {
                it.createCollection(call.argument<String>("id") ?: "", call.argument<String>("name") ?: "")
            }
            "renameCollection" -> dbCall(result) {
                it.renameCollection(call.argument<String>("id") ?: "", call.argument<String>("name") ?: "")
            }
            "deleteCollection" -> dbCall(result) { it.deleteCollection(call.argument<String>("id") ?: "") }

            "takePendingShare" -> {
                val p = pending.poll()
                result.success(if (p == null) null else mapOf("text" to p.first, "subject" to p.second))
            }
            "isOnline" -> result.success(isOnlineNow())
            "openExternal" -> result.success(openExternal(call.argument<String>("url") ?: ""))
            "play" -> result.success(play(call))
            else -> result.notImplemented()
        }
    }

    /** Runs a database call off the main thread and answers on the main thread. */
    private fun dbCall(result: MethodChannel.Result, work: (OvDb) -> Any?) {
        val d = db
        if (d == null) {
            result.error("no_db", "Online videos database is not ready.", null)
            return
        }
        try {
            io.execute {
                try {
                    val out = work(d)
                    main.post { result.success(out) }
                } catch (e: Throwable) {
                    main.post { result.error("db", e.message, null) }
                }
            }
        } catch (e: Throwable) {
            result.error("db", e.message, null)
        }
    }
}

/**
 * The Online Videos database.
 *
 *  videos       one row per saved link. dedupe_key is UNIQUE: the same video can never be saved twice,
 *               however the link was shared (the key is worked out in Dart, see video_link.dart).
 *  collections  names the person created. Deleting one never deletes videos (their collection_id
 *               just becomes NULL).
 *
 * Paging is done here with LIMIT / OFFSET, so opening the library reads one page of rows, not all of them.
 */
private class OvDb(c: Context) : SQLiteOpenHelper(c.applicationContext, "godfident_online_videos.db", null, 1) {

    companion object {
        private const val COLS = "id, url, platform, title, thumb_url, collection_id, added_at, meta_state, title_edited"
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE collections (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, created_at INTEGER NOT NULL)")
        db.execSQL("CREATE UNIQUE INDEX idx_collections_name ON collections(name COLLATE NOCASE)")
        db.execSQL(
            "CREATE TABLE videos (" +
                "id TEXT PRIMARY KEY NOT NULL, " +
                "url TEXT NOT NULL, " +
                "dedupe_key TEXT NOT NULL UNIQUE, " +
                "platform TEXT NOT NULL, " +
                "title TEXT, " +
                "thumb_url TEXT, " +
                "collection_id TEXT REFERENCES collections(id) ON DELETE SET NULL, " +
                "added_at INTEGER NOT NULL, " +
                "meta_state INTEGER NOT NULL DEFAULT 0, " +
                "title_edited INTEGER NOT NULL DEFAULT 0)"
        )
        db.execSQL("CREATE INDEX idx_videos_added ON videos(added_at DESC, id DESC)")
        db.execSQL("CREATE INDEX idx_videos_collection ON videos(collection_id, added_at DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Version 1 only. Future versions add columns here with ALTER TABLE; never drop the person's links.
    }

    private fun str(c: Cursor, i: Int): String? = if (c.isNull(i)) null else c.getString(i)

    private fun row(c: Cursor): Map<String, Any?> = mapOf(
        "id" to c.getString(0),
        "url" to c.getString(1),
        "platform" to c.getString(2),
        "title" to str(c, 3),
        "thumbUrl" to str(c, 4),
        "collectionId" to str(c, 5),
        "addedAt" to c.getLong(6),
        "metaState" to c.getInt(7),
        "titleEdited" to c.getInt(8)
    )

    // ───────────── videos ─────────────

    fun page(offset: Int, limit: Int, scope: String, collectionId: String?): Map<String, Any?> {
        val where: String
        val args: Array<String>
        when (scope) {
            "collection" -> { where = "WHERE collection_id = ?"; args = arrayOf(collectionId ?: "") }
            "none" -> { where = "WHERE collection_id IS NULL"; args = emptyArray() }
            else -> { where = ""; args = emptyArray() }
        }
        val rd = readableDatabase
        val items = ArrayList<Map<String, Any?>>()
        // One extra row tells whether there is a next page without a second query.
        rd.rawQuery(
            "SELECT $COLS FROM videos $where ORDER BY added_at DESC, id DESC LIMIT ? OFFSET ?",
            args + arrayOf((limit + 1).toString(), offset.toString())
        ).use { c -> while (c.moveToNext()) items.add(row(c)) }
        val hasMore = items.size > limit
        if (hasMore) items.removeAt(items.size - 1)
        val total = DatabaseUtils.longForQuery(rd, "SELECT COUNT(*) FROM videos $where", args)
        return mapOf("items" to items, "hasMore" to hasMore, "total" to total)
    }

    fun get(id: String): Map<String, Any?>? {
        readableDatabase.rawQuery("SELECT $COLS FROM videos WHERE id = ?", arrayOf(id)).use { c ->
            return if (c.moveToFirst()) row(c) else null
        }
    }

    private fun byKey(key: String): Map<String, Any?>? {
        readableDatabase.rawQuery("SELECT $COLS FROM videos WHERE dedupe_key = ?", arrayOf(key)).use { c ->
            return if (c.moveToFirst()) row(c) else null
        }
    }

    private fun collectionExists(id: String): Boolean =
        DatabaseUtils.longForQuery(readableDatabase, "SELECT COUNT(*) FROM collections WHERE id = ?", arrayOf(id)) > 0

    /** Saves a link, or reports the one already saved. Never needs a title, thumbnail or the network. */
    fun add(
        id: String, url: String, key: String, platform: String,
        title: String?, thumbUrl: String?, collectionId: String?
    ): Map<String, Any?> {
        if (id.isEmpty() || url.isEmpty() || key.isEmpty()) throw IllegalArgumentException("empty link")
        byKey(key)?.let { return mapOf("status" to "duplicate", "video" to it) }

        val cv = ContentValues()
        cv.put("id", id)
        cv.put("url", url)
        cv.put("dedupe_key", key)
        cv.put("platform", platform)
        if (!title.isNullOrBlank()) cv.put("title", title.trim()) else cv.putNull("title")
        if (!thumbUrl.isNullOrBlank()) cv.put("thumb_url", thumbUrl) else cv.putNull("thumb_url")
        if (collectionId != null && collectionExists(collectionId)) cv.put("collection_id", collectionId) else cv.putNull("collection_id")
        cv.put("added_at", System.currentTimeMillis())
        cv.put("meta_state", 0)
        cv.put("title_edited", 0)

        val rowId = try {
            writableDatabase.insertOrThrow("videos", null, cv)
        } catch (_: SQLiteConstraintException) {
            -1L // lost a race to the same key: report it as a duplicate below
        }
        if (rowId == -1L) {
            byKey(key)?.let { return mapOf("status" to "duplicate", "video" to it) }
            throw IllegalStateException("could not save")
        }
        val saved = get(id) ?: throw IllegalStateException("saved row not found")
        return mapOf("status" to "added", "video" to saved)
    }

    fun remove(id: String): Boolean = writableDatabase.delete("videos", "id = ?", arrayOf(id)) > 0

    fun setCollection(id: String, collectionId: String?): Boolean {
        val cv = ContentValues()
        if (collectionId != null && collectionExists(collectionId)) cv.put("collection_id", collectionId) else cv.putNull("collection_id")
        return writableDatabase.update("videos", cv, "id = ?", arrayOf(id)) > 0
    }

    /** The person's own title. Empty = go back to the platform's title (looked up again later). */
    fun rename(id: String, title: String): Boolean {
        val t = title.trim()
        val cv = ContentValues()
        if (t.isEmpty()) {
            cv.putNull("title"); cv.put("title_edited", 0); cv.put("meta_state", 0)
        } else {
            cv.put("title", t.take(200)); cv.put("title_edited", 1)
        }
        return writableDatabase.update("videos", cv, "id = ?", arrayOf(id)) > 0
    }

    /** What the one-time lookup found. A platform title never replaces one the person typed. */
    fun saveMeta(id: String, title: String?, thumbUrl: String?, state: Int): Boolean {
        val wd = writableDatabase
        val cv = ContentValues()
        cv.put("meta_state", state)
        if (!thumbUrl.isNullOrBlank()) cv.put("thumb_url", thumbUrl)
        val n = wd.update("videos", cv, "id = ?", arrayOf(id))
        if (!title.isNullOrBlank()) {
            wd.execSQL("UPDATE videos SET title = ? WHERE id = ? AND title_edited = 0", arrayOf(title.trim().take(200), id))
        }
        return n > 0
    }

    // ───────────── collections ─────────────

    fun collections(): Map<String, Any?> {
        val rd = readableDatabase
        val list = ArrayList<Map<String, Any?>>()
        rd.rawQuery(
            "SELECT c.id, c.name, COUNT(v.id) FROM collections c " +
                "LEFT JOIN videos v ON v.collection_id = c.id GROUP BY c.id ORDER BY c.name COLLATE NOCASE", null
        ).use { c -> while (c.moveToNext()) list.add(mapOf("id" to c.getString(0), "name" to c.getString(1), "count" to c.getInt(2))) }
        val total = DatabaseUtils.longForQuery(rd, "SELECT COUNT(*) FROM videos", null)
        val unsorted = DatabaseUtils.longForQuery(rd, "SELECT COUNT(*) FROM videos WHERE collection_id IS NULL", null)
        return mapOf("collections" to list, "total" to total, "unsorted" to unsorted)
    }

    /** Creates a collection. A name that already exists (any capitalisation) returns the existing one. */
    fun createCollection(id: String, name: String): Map<String, Any?> {
        val n = name.trim().take(60)
        if (id.isEmpty() || n.isEmpty()) throw IllegalArgumentException("empty name")
        readableDatabase.rawQuery("SELECT id, name FROM collections WHERE name = ? COLLATE NOCASE", arrayOf(n)).use { c ->
            if (c.moveToFirst()) return mapOf("id" to c.getString(0), "name" to c.getString(1), "count" to 0)
        }
        val cv = ContentValues()
        cv.put("id", id); cv.put("name", n); cv.put("created_at", System.currentTimeMillis())
        writableDatabase.insertOrThrow("collections", null, cv)
        return mapOf("id" to id, "name" to n, "count" to 0)
    }

    fun renameCollection(id: String, name: String): Boolean {
        val n = name.trim().take(60)
        if (n.isEmpty()) return false
        val cv = ContentValues()
        cv.put("name", n)
        return try {
            writableDatabase.update("collections", cv, "id = ?", arrayOf(id)) > 0
        } catch (_: SQLiteConstraintException) {
            false // another collection already has that name
        }
    }

    /** Removes the collection only. Its videos stay saved and become "not sorted". */
    fun deleteCollection(id: String): Boolean {
        val wd = writableDatabase
        wd.beginTransaction()
        try {
            val cv = ContentValues()
            cv.putNull("collection_id")
            wd.update("videos", cv, "collection_id = ?", arrayOf(id))
            val n = wd.delete("collections", "id = ?", arrayOf(id))
            wd.setTransactionSuccessful()
            return n > 0
        } finally {
            wd.endTransaction()
        }
    }
}
