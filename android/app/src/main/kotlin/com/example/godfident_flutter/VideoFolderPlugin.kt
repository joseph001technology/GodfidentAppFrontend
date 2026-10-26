package com.example.godfident_flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * The permanent Godfident video folder: Movies/Godfident/ on shared storage.
 *
 * - Videos and the manifest live THERE, not in app-private storage, so they survive an
 *   uninstall and show up in the Gallery.
 * - Access uses Android's folder picker (Storage Access Framework). Android forgets the
 *   permission when the app is uninstalled; the folder itself stays. On the next launch the
 *   picker opens pointed at Movies/Godfident so one tap reconnects the SAME folder.
 * - The folder is always found before it is created, so a reinstall (or another account on
 *   the same phone) never produces "Godfident (1)".
 * - Nothing in this file touches the network.
 *
 * Registered from MainActivity.configureFlutterEngine; it does not touch the blocking code.
 */
class VideoFolderPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "com.godfident/video_folder"
        private const val REQ_PICK_TREE = 7101
        private const val REQ_PICK_VIDEOS = 7102
        private const val PREFS = "godfident_video_folder"
        private const val KEY_TREE = "tree_uri"
        private const val KEY_ROOT = "root_doc_id"

        private const val AUTHORITY = "com.android.externalstorage.documents"
        private const val FOLDER_NAME = "Godfident"
        private const val FOLDER_PATH = "Movies/Godfident"
        private const val MANIFEST = "godfident-library.json"
        private const val MANIFEST_TMP = "godfident-library.tmp.json"
        private val VIDEO_EXT = setOf("mp4", "m4v", "mkv", "webm", "3gp", "mov", "avi", "ts")
    }

    private var ctx: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var pendingPick: MethodChannel.Result? = null
    private var pendingVideos: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val thumbs = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    // ───────────── plugin lifecycle ─────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ctx = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        io.shutdown()
        thumbs.shutdown()
        ctx = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    // ───────────── method channel ─────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> background(result) { status() }
            "pickFolder" -> pickFolder(result)
            "pickVideos" -> pickVideos(result)
            "listVideos" -> background(result) { listVideos() }
            "thumbnail" -> background(result, thumbs) { thumbnail(call.argument<String>("uri") ?: "") }
            "probe" -> background(result) { probe(call.argument<String>("uri") ?: "") }
            "readManifest" -> background(result) { readManifest() }
            "writeManifest" -> background(result) { writeManifest(call.argument<String>("text") ?: "") }
            "importVideo" -> background(result) {
                importVideo(call.argument<String>("sourceUri") ?: "", call.argument<String>("name"))
            }
            "deleteFile" -> background(result) { deleteFile(call.argument<String>("name") ?: "") }
            else -> result.notImplemented()
        }
    }

    /** Runs [work] off the main thread and always answers on the main thread. */
    private fun background(result: MethodChannel.Result, pool: java.util.concurrent.ExecutorService = io, work: () -> Any?) {
        try {
            pool.execute {
                val out: Any? = try {
                    work()
                } catch (e: Throwable) {
                    null
                }
                main.post { result.success(out) }
            }
        } catch (e: Throwable) {
            result.success(null)
        }
    }

    // ───────────── saved folder ─────────────

    private fun prefs() = ctx!!.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun treeUri(): Uri? = prefs().getString(KEY_TREE, null)?.let { Uri.parse(it) }
    private fun rootDocId(): String? = prefs().getString(KEY_ROOT, null)

    private fun hasGrant(tree: Uri): Boolean =
        ctx!!.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }

    private fun rootUri(tree: Uri, rootId: String): Uri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)

    private fun status(): Map<String, Any?> {
        val tree = treeUri()
        val root = rootDocId()
        val base = mapOf<String, Any?>("folderPath" to FOLDER_PATH)
        if (tree == null || root == null) return base + mapOf("connected" to false, "reason" to "not_connected")
        if (!hasGrant(tree)) return base + mapOf("connected" to false, "reason" to "access_lost")
        if (!exists(rootUri(tree, root))) return base + mapOf("connected" to false, "reason" to "folder_missing")
        return base + mapOf("connected" to true)
    }

    private fun exists(docUri: Uri): Boolean = try {
        ctx!!.contentResolver.query(
            docUri, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null
        )?.use { it.moveToFirst() } ?: false
    } catch (e: Exception) {
        false
    }

    // ───────────── folder picker ─────────────

    private fun pickFolder(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.success(mapOf("ok" to false, "error" to "failed"))
            return
        }
        pendingPick?.success(mapOf("ok" to false, "error" to "cancelled"))
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
            if (Build.VERSION.SDK_INT >= 26) {
                // Open the picker already looking at Movies/Godfident.
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri(AUTHORITY, "primary:$FOLDER_PATH")
                )
            }
        }
        try {
            @Suppress("DEPRECATION")
            act.startActivityForResult(intent, REQ_PICK_TREE)
        } catch (e: Exception) {
            pendingPick = null
            result.success(mapOf("ok" to false, "error" to "failed"))
        }
    }

    /** Android's own file chooser for videos (several allowed). Returns content:// uris. */
    private fun pickVideos(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.success(emptyList<String>())
            return
        }
        pendingVideos?.success(emptyList<String>())
        pendingVideos = result
        // Android 13+: the system photo picker (a Gallery-style grid of the phone's videos, with
        // thumbnails, no permission needed). Older phones: the system chooser, which lists
        // Gallery / Photos / Files with video thumbnails.
        val intent = if (Build.VERSION.SDK_INT >= 33) {
            Intent(android.provider.MediaStore.ACTION_PICK_IMAGES).apply {
                type = "video/*"
                putExtra(
                    android.provider.MediaStore.EXTRA_PICK_IMAGES_MAX,
                    android.provider.MediaStore.getPickImagesMaxLimit()
                )
            }
        } else {
            Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        try {
            @Suppress("DEPRECATION")
            act.startActivityForResult(intent, REQ_PICK_VIDEOS)
        } catch (e: Exception) {
            pendingVideos = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQ_PICK_VIDEOS) {
            val res = pendingVideos
            pendingVideos = null
            val out = ArrayList<String>()
            if (resultCode == Activity.RESULT_OK && data != null) {
                data.data?.let { out.add(it.toString()) }
                data.clipData?.let { cd -> for (i in 0 until cd.itemCount) out.add(cd.getItemAt(i).uri.toString()) }
            }
            res?.success(out)
            return true
        }
        if (requestCode != REQ_PICK_TREE) return false
        val res = pendingPick
        pendingPick = null
        val uri = data?.data
        val grantFlags = data?.flags ?: 0
        if (res == null) return true
        if (resultCode != Activity.RESULT_OK || uri == null) {
            res.success(mapOf("ok" to false, "error" to "cancelled"))
            return true
        }
        io.execute {
            val out: Map<String, Any?> = try {
                connect(uri, grantFlags)
            } catch (e: Throwable) {
                mapOf("ok" to false, "error" to "failed")
            }
            main.post { res.success(out) }
        }
        return true
    }

    /**
     * Accepts a pick of Movies/Godfident itself, or of Movies (then finds the existing
     * Godfident folder inside it, creating it only if it really is not there).
     */
    private fun connect(tree: Uri, flags: Int): Map<String, Any?> {
        val resolver = ctx!!.contentResolver
        try {
            resolver.takePersistableUriPermission(
                tree, flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            )
        } catch (e: Exception) {
            return mapOf("ok" to false, "error" to "no_access")
        }

        val docId = DocumentsContract.getTreeDocumentId(tree) // e.g. "primary:Movies/Godfident"
        val path = docId.substringAfter(':', "")
        val rootId: String? = when (path) {
            FOLDER_PATH -> docId
            "Movies" -> findChild(tree, docId, FOLDER_NAME, dirOnly = true)?.docId ?: createFolder(tree, docId)
            else -> null
        }
        if (rootId == null) {
            try {
                resolver.releasePersistableUriPermission(
                    tree, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
            return mapOf("ok" to false, "error" to "wrong_folder")
        }
        prefs().edit().putString(KEY_TREE, tree.toString()).putString(KEY_ROOT, rootId).apply()
        return mapOf("ok" to true, "folderPath" to FOLDER_PATH)
    }

    private fun createFolder(tree: Uri, parentDocId: String): String? {
        val created = try {
            DocumentsContract.createDocument(
                ctx!!.contentResolver,
                DocumentsContract.buildDocumentUriUsingTree(tree, parentDocId),
                DocumentsContract.Document.MIME_TYPE_DIR,
                FOLDER_NAME
            )
        } catch (e: Exception) {
            null
        }
        // Re-read instead of trusting the returned name, in case the provider renamed it.
        return findChild(tree, parentDocId, FOLDER_NAME, dirOnly = true)?.docId
            ?: created?.let { DocumentsContract.getDocumentId(it) }
    }

    // ───────────── folder contents ─────────────

    private class Child(val docId: String, val name: String, val mime: String, val size: Long, val modified: Long) {
        val isDir get() = mime == DocumentsContract.Document.MIME_TYPE_DIR
    }

    private fun children(tree: Uri, parentDocId: String): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentDocId)
        val out = ArrayList<Child>()
        ctx!!.contentResolver.query(
            uri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED
            ),
            null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    Child(
                        c.getString(0) ?: continue,
                        c.getString(1) ?: continue,
                        c.getString(2) ?: "",
                        if (c.isNull(3)) 0L else c.getLong(3),
                        if (c.isNull(4)) 0L else c.getLong(4)
                    )
                )
            }
        }
        return out
    }

    private fun findChild(tree: Uri, parentDocId: String, name: String, dirOnly: Boolean = false): Child? =
        children(tree, parentDocId).firstOrNull { it.name == name && (!dirOnly || it.isDir) }

    private fun isVideo(c: Child): Boolean {
        if (c.isDir) return false
        if (c.mime.startsWith("video/")) return true
        return c.name.substringAfterLast('.', "").lowercase() in VIDEO_EXT
    }

    private fun listVideos(): List<Map<String, Any?>>? {
        val tree = treeUri() ?: return null
        val root = rootDocId() ?: return null
        return children(tree, root).filter { isVideo(it) }.map {
            mapOf(
                "name" to it.name,
                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, it.docId).toString(),
                "size" to it.size,
                "lastModified" to it.modified
            )
        }
    }

    // ───────────── validation ─────────────

    /** A small JPEG frame (about 1 second in) so the library can show what each video is. */
    private fun thumbnail(uriString: String): ByteArray? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(ctx!!, Uri.parse(uriString))
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val atUs = if (dur > 2000) 1_000_000L else 0L
            var bmp = r.getFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: r.getFrameAtTime(-1)
                ?: return null
            val maxW = 480
            if (bmp.width > maxW) {
                val h = (bmp.height * (maxW.toFloat() / bmp.width)).toInt().coerceAtLeast(1)
                bmp = Bitmap.createScaledBitmap(bmp, maxW, h, true)
            }
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 80, out)
            out.toByteArray()
        } catch (e: Throwable) {
            null
        } finally {
            try { r.release() } catch (_: Throwable) {}
        }
    }

    /** Opens the file with the platform decoder front-end. Cheap; not a full decode. */
    private fun probe(uriString: String): Map<String, Any?> {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(ctx!!, Uri.parse(uriString))
            val hasVideo = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            mapOf("durationMs" to dur, "playable" to (hasVideo && dur > 0))
        } catch (e: Throwable) {
            mapOf("durationMs" to 0L, "playable" to false)
        } finally {
            try { r.release() } catch (_: Throwable) {}
        }
    }

    // ───────────── manifest (kept IN Movies/Godfident/) ─────────────

    private fun readText(uri: Uri): String? = try {
        ctx!!.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
    } catch (e: Exception) {
        null
    }

    private fun readManifest(): Map<String, Any?> {
        val tree = treeUri() ?: return mapOf("main" to null, "tmp" to null)
        val root = rootDocId() ?: return mapOf("main" to null, "tmp" to null)
        val kids = children(tree, root)
        fun text(name: String): String? =
            kids.firstOrNull { it.name == name && !it.isDir }?.let {
                readText(DocumentsContract.buildDocumentUriUsingTree(tree, it.docId))
            }
        return mapOf("main" to text(MANIFEST), "tmp" to text(MANIFEST_TMP))
    }

    /**
     * Write to a temp file, then swap it in. If the app dies half-way, either the old
     * manifest or the complete temp copy is still there; the reader accepts both.
     */
    private fun writeManifest(text: String): Boolean {
        val resolver = ctx!!.contentResolver
        val tree = treeUri() ?: return false
        val root = rootDocId() ?: return false
        val parent = rootUri(tree, root)

        findChild(tree, root, MANIFEST_TMP)?.let {
            try { DocumentsContract.deleteDocument(resolver, DocumentsContract.buildDocumentUriUsingTree(tree, it.docId)) } catch (_: Exception) {}
        }
        val tmp = try {
            DocumentsContract.createDocument(resolver, parent, "application/json", MANIFEST_TMP)
        } catch (e: Exception) {
            null
        } ?: return false
        return try {
            resolver.openOutputStream(tmp, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)); it.flush() } ?: return false
            findChild(tree, root, MANIFEST)?.let {
                DocumentsContract.deleteDocument(resolver, DocumentsContract.buildDocumentUriUsingTree(tree, it.docId))
            }
            // If the rename fails the temp copy stays and is read as a fallback.
            DocumentsContract.renameDocument(resolver, tmp, MANIFEST)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ───────────── import / delete ─────────────

    private fun importVideo(sourceUriString: String, wantedName: String?): Map<String, Any?> {
        val resolver = ctx!!.contentResolver
        val tree = treeUri() ?: return mapOf("ok" to false, "error" to "no_folder")
        val root = rootDocId() ?: return mapOf("ok" to false, "error" to "no_folder")
        val src = Uri.parse(sourceUriString)

        var srcName: String? = null
        var srcSize = -1L
        try {
            resolver.query(src, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    srcName = c.getString(0)
                    if (!c.isNull(1)) srcSize = c.getLong(1)
                }
            }
        } catch (_: Exception) {}

        val name = sanitize(wantedName ?: srcName ?: "video.mp4")
        val ext = name.substringAfterLast('.', "").lowercase()
        var mime = resolver.getType(src) ?: ""
        if (!mime.startsWith("video/")) mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: ""
        if (!mime.startsWith("video/")) return mapOf("ok" to false, "error" to "not_video")

        // Same name and same size already in the folder: it is the same file. Reuse it.
        findChild(tree, root, name)?.let { same ->
            if (!same.isDir && srcSize > 0 && same.size == srcSize) {
                return mapOf(
                    "ok" to true, "name" to same.name, "size" to same.size, "duplicate" to true,
                    "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, same.docId).toString()
                )
            }
        }

        val dest = try {
            DocumentsContract.createDocument(resolver, rootUri(tree, root), mime, name)
        } catch (e: Exception) {
            null
        } ?: return mapOf("ok" to false, "error" to "copy_failed")

        try {
            val input = resolver.openInputStream(src) ?: throw IOException("cannot open source")
            input.use { i ->
                resolver.openOutputStream(dest, "w")?.use { o ->
                    val buf = ByteArray(256 * 1024)
                    while (true) {
                        val n = i.read(buf)
                        if (n < 0) break
                        o.write(buf, 0, n)
                    }
                    o.flush()
                } ?: throw IOException("cannot open destination")
            }
        } catch (e: Throwable) {
            // Never leave half a video in the folder (it would show up in the Gallery).
            try { DocumentsContract.deleteDocument(resolver, dest) } catch (_: Exception) {}
            val msg = (e.message ?: "").lowercase()
            val full = msg.contains("enospc") || msg.contains("no space") || msg.contains("quota")
            return mapOf("ok" to false, "error" to if (full) "no_space" else "copy_failed")
        }

        val destDocId = DocumentsContract.getDocumentId(dest)
        val child = children(tree, root).firstOrNull { it.docId == destDocId }
        scanForGallery(destDocId, mime)
        return mapOf(
            "ok" to true,
            "name" to (child?.name ?: name),
            "size" to (child?.size ?: 0L),
            "duplicate" to false,
            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, destDocId).toString()
        )
    }

    private fun deleteFile(name: String): Boolean {
        val resolver = ctx!!.contentResolver
        val tree = treeUri() ?: return false
        val root = rootDocId() ?: return false
        val f = findChild(tree, root, name) ?: return true // already gone
        if (f.isDir) return false
        val ok = try {
            DocumentsContract.deleteDocument(resolver, DocumentsContract.buildDocumentUriUsingTree(tree, f.docId))
        } catch (e: Exception) {
            false
        }
        if (ok) scanForGallery(f.docId, f.mime)
        return ok
    }

    /** Best effort: tells MediaStore about a change so Gallery shows (or drops) the file now. */
    private fun scanForGallery(docId: String, mime: String) {
        try {
            if (!docId.startsWith("primary:")) return // other volumes are indexed by Android itself
            val file = File(Environment.getExternalStorageDirectory(), docId.substringAfter(':'))
            MediaScannerConnection.scanFile(ctx!!, arrayOf(file.absolutePath), arrayOf(mime), null)
        } catch (_: Throwable) {
        }
    }

    private fun sanitize(raw: String): String {
        val cleaned = raw.replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_").trim().trimStart('.')
        return if (cleaned.isEmpty()) "video.mp4" else cleaned.take(120)
    }
}
