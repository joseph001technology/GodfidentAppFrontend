package com.example.godfident_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Real website blocking.
 *
 * Establishes a local VPN whose ONLY route is a fake DNS server address.
 * Every DNS lookup the phone makes (Chrome, Firefox, any app) is therefore
 * delivered to this service. A lookup for a blocked domain (or any of its
 * subdomains) is answered with NXDOMAIN, so the site cannot load; every
 * other lookup is forwarded untouched to a real resolver. No web traffic
 * is read or stored — only the host name inside DNS queries is inspected,
 * and nothing leaves the device.
 *
 * Known limits (also shown to the user in the app):
 *  - Browsers using their own DNS-over-HTTPS ("Secure DNS") or Android
 *    "Private DNS" in strict mode bypass this; the app warns about the
 *    latter and the user must disable Secure DNS in the browser.
 *  - The user can still switch the VPN off in Android settings; the app
 *    then reports protection as INACTIVE (see [onRevoke]).
 */
class WebsiteBlockVpnService : VpnService() {

    companion object {
        const val PREFS = "godfident_website_prefs"
        const val KEY_DOMAINS = "blocked_domains"
        const val KEY_ACTIVE = "protection_active"
        const val KEY_BLOCKED_COUNT = "blocked_lookup_count"
        const val ACTION_STOP = "com.example.godfident_flutter.STOP_WEB_PROTECTION"

        private const val CHANNEL_ID = "website_protection"
        private const val NOTIFICATION_ID = 4202
        private const val VPN_ADDRESS = "10.99.0.1"
        private const val FAKE_DNS = "10.99.0.2"
        private val UPSTREAM_DNS = arrayOf("8.8.8.8", "1.1.1.1")

        @Volatile
        var isRunning: Boolean = false
            private set

        // Live diagnostics shown in the app so "is it even receiving lookups?" is answerable.
        @Volatile var totalQueries: Int = 0
        @Volatile var lastHost: String = ""
        @Volatile var lastError: String = ""

        /** True if [host] equals a blocked domain or is a subdomain of one. */
        fun isBlocked(host: String, domains: Set<String>): Boolean {
            val h = host.lowercase().trimEnd('.')
            for (raw in domains) {
                val d = raw.lowercase().trim().removePrefix("www.")
                if (d.isEmpty()) continue
                if (h == d || h.endsWith(".$d")) return true
            }
            return false
        }
    }

    private var tun: ParcelFileDescriptor? = null
    private var worker: Thread? = null
    private var pool: ExecutorService? = null

    @Volatile
    private var stopping = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown(markInactive = true)
            stopSelf()
            return START_NOT_STICKY
        }
        if (isRunning) return START_STICKY

        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        val builder = Builder()
            .setSession("Godfident website protection")
            .addAddress(VPN_ADDRESS, 32)
            .addDnsServer(FAKE_DNS)
            .addRoute(FAKE_DNS, 32) // only DNS to the fake server is captured
            .setBlocking(true)
        totalQueries = 0
        lastHost = ""
        lastError = ""
        val pfd = try {
            builder.establish()
        } catch (e: Exception) {
            lastError = "establish failed: ${e.message}"
            null
        }
        if (pfd == null) {
            if (lastError.isEmpty()) lastError = "Android refused to create the VPN (permission missing or revoked)"
            // VPN permission was not granted / revoked: do NOT claim protection.
            shutdown(markInactive = true)
            stopSelf()
            return START_NOT_STICKY
        }

        tun = pfd
        stopping = false
        isRunning = true
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ACTIVE, true).apply()
        pool = Executors.newCachedThreadPool()
        worker = Thread({ runLoop(pfd) }, "godfident-dns").also { it.start() }
        return START_STICKY
    }

    override fun onRevoke() {
        // User turned the VPN off (or another VPN took over).
        shutdown(markInactive = true)
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        shutdown(markInactive = false)
        super.onDestroy()
    }

    private fun shutdown(markInactive: Boolean) {
        stopping = true
        isRunning = false
        try { worker?.interrupt() } catch (_: Exception) {}
        try { pool?.shutdownNow() } catch (_: Exception) {}
        try { tun?.close() } catch (_: Exception) {}
        tun = null
        worker = null
        pool = null
        if (markInactive) {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ACTIVE, false).apply()
        }
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
    }

    // ───────────────────────── packet loop ─────────────────────────

    private fun runLoop(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buf = ByteArray(32767)
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        while (!stopping && !Thread.currentThread().isInterrupted) {
            val len = try { input.read(buf) } catch (e: Exception) { lastError = "read: ${e.message}"; break }
            if (len <= 0) continue
            val packet = buf.copyOf(len)
            try {
                handlePacket(packet, output, prefs)
            } catch (_: Exception) {
                // malformed packet: drop it
            }
        }
    }

    private fun handlePacket(p: ByteArray, out: FileOutputStream, prefs: android.content.SharedPreferences) {
        if (p.size < 28) return
        val version = (p[0].toInt() shr 4) and 0xF
        if (version != 4) return
        val ihl = (p[0].toInt() and 0xF) * 4
        if (ihl < 20 || p.size < ihl + 8) return
        val proto = p[9].toInt() and 0xFF
        if (proto == 6) { rejectTcp(p, ihl, out); return }
        if (proto != 17) return

        val dstPort = ((p[ihl + 2].toInt() and 0xFF) shl 8) or (p[ihl + 3].toInt() and 0xFF)
        if (dstPort != 53) return

        val srcIp = p.copyOfRange(12, 16)
        val dstIp = p.copyOfRange(16, 20)
        val srcPort = ((p[ihl].toInt() and 0xFF) shl 8) or (p[ihl + 1].toInt() and 0xFF)
        val udpLen = ((p[ihl + 4].toInt() and 0xFF) shl 8) or (p[ihl + 5].toInt() and 0xFF)
        val payloadStart = ihl + 8
        val payloadEnd = minOf(p.size, ihl + udpLen)
        if (payloadEnd <= payloadStart + 12) return
        val dns = p.copyOfRange(payloadStart, payloadEnd)

        val parsed = parseQuestion(dns) ?: return
        totalQueries++
        lastHost = parsed.first
        val domains = prefs.getStringSet(KEY_DOMAINS, emptySet()) ?: emptySet()

        if (isBlocked(parsed.first, domains)) {
            prefs.edit().putInt(KEY_BLOCKED_COUNT, prefs.getInt(KEY_BLOCKED_COUNT, 0) + 1).apply()
            val reply = buildNxDomain(dns, parsed.second)
            writeReply(out, dstIp, srcIp, srcPort, reply)
        } else {
            pool?.execute {
                val reply = forward(dns) ?: return@execute
                writeReply(out, dstIp, srcIp, srcPort, reply)
            }
        }
    }

    /**
     * Answers any TCP attempt to the fake DNS address (e.g. Android's DNS-over-TLS
     * probe on port 853) with an immediate RST, so it fails fast and Android falls
     * back to plain DNS instead of hanging for several seconds.
     */
    private fun rejectTcp(p: ByteArray, ihl: Int, out: FileOutputStream) {
        if (p.size < ihl + 20) return
        val flags = p[ihl + 13].toInt() and 0xFF
        if (flags and 0x04 != 0) return // already a RST
        val srcIp = p.copyOfRange(12, 16)
        val dstIp = p.copyOfRange(16, 20)
        val srcPort0 = p[ihl].toInt() and 0xFF
        val srcPort1 = p[ihl + 1].toInt() and 0xFF
        val dstPort0 = p[ihl + 2].toInt() and 0xFF
        val dstPort1 = p[ihl + 3].toInt() and 0xFF
        var seq = 0L
        for (i in 4..7) seq = (seq shl 8) or (p[ihl + i].toLong() and 0xFF)
        val ack = (seq + (if (flags and 0x02 != 0) 1 else 0)) and 0xFFFFFFFFL
        val b = ByteArray(40)
        b[0] = 0x45; b[2] = 0; b[3] = 40; b[6] = 0x40; b[8] = 64; b[9] = 6
        System.arraycopy(dstIp, 0, b, 12, 4)
        System.arraycopy(srcIp, 0, b, 16, 4)
        val ck = ipChecksum(b, 20)
        b[10] = (ck shr 8).toByte(); b[11] = ck.toByte()
        b[20] = dstPort0.toByte(); b[21] = dstPort1.toByte()
        b[22] = srcPort0.toByte(); b[23] = srcPort1.toByte()
        // seq = 0
        b[28] = (ack shr 24).toByte(); b[29] = (ack shr 16).toByte(); b[30] = (ack shr 8).toByte(); b[31] = ack.toByte()
        b[32] = 0x50 // data offset 5 words
        b[33] = 0x14 // RST + ACK
        // TCP checksum over pseudo-header
        var sum = 0
        fun add(hi: Int, lo: Int) { sum += (hi and 0xFF shl 8) or (lo and 0xFF) }
        add(b[12].toInt(), b[13].toInt()); add(b[14].toInt(), b[15].toInt())
        add(b[16].toInt(), b[17].toInt()); add(b[18].toInt(), b[19].toInt())
        sum += 6; sum += 20
        var i = 20
        while (i < 40) { add(b[i].toInt(), b[i + 1].toInt()); i += 2 }
        while (sum shr 16 != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        val tck = sum.inv() and 0xFFFF
        b[36] = (tck shr 8).toByte(); b[37] = tck.toByte()
        synchronized(this) { try { out.write(b) } catch (_: Exception) {} }
    }

    /** Returns (hostname, endOfQuestionOffset) or null. */
    private fun parseQuestion(dns: ByteArray): Pair<String, Int>? {
        var i = 12
        val sb = StringBuilder()
        while (i < dns.size) {
            val l = dns[i].toInt() and 0xFF
            if (l == 0) {
                i++
                break
            }
            if (l and 0xC0 != 0) return null // compression not valid in a question
            i++
            if (i + l > dns.size) return null
            if (sb.isNotEmpty()) sb.append('.')
            sb.append(String(dns, i, l, Charsets.ISO_8859_1))
            i += l
        }
        if (i + 4 > dns.size) return null
        return Pair(sb.toString(), i + 4)
    }

    private fun buildNxDomain(query: ByteArray, questionEnd: Int): ByteArray {
        val r = query.copyOf(questionEnd)
        r[2] = 0x81.toByte() // QR=1, RD=1
        r[3] = 0x83.toByte() // RA=1, RCODE=3 (NXDOMAIN)
        r[6] = 0; r[7] = 0   // ANCOUNT
        r[8] = 0; r[9] = 0   // NSCOUNT
        r[10] = 0; r[11] = 0 // ARCOUNT
        return r
    }

    private fun forward(query: ByteArray): ByteArray? {
        for (server in UPSTREAM_DNS) {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket) // bypass our own VPN
                socket.soTimeout = 4000
                val addr = InetAddress.getByName(server)
                socket.send(DatagramPacket(query, query.size, addr, 53))
                val buf = ByteArray(4096)
                val resp = DatagramPacket(buf, buf.size)
                socket.receive(resp)
                return buf.copyOf(resp.length)
            } catch (_: Exception) {
                // try next upstream
            } finally {
                try { socket?.close() } catch (_: Exception) {}
            }
        }
        return null
    }

    @Synchronized
    private fun writeReply(out: FileOutputStream, srcIp: ByteArray, dstIp: ByteArray, dstPort: Int, payload: ByteArray) {
        val total = 20 + 8 + payload.size
        val b = ByteArray(total)
        b[0] = 0x45
        b[2] = (total shr 8).toByte(); b[3] = total.toByte()
        b[6] = 0x40 // don't fragment
        b[8] = 64   // TTL
        b[9] = 17   // UDP
        System.arraycopy(srcIp, 0, b, 12, 4)
        System.arraycopy(dstIp, 0, b, 16, 4)
        val ck = ipChecksum(b, 20)
        b[10] = (ck shr 8).toByte(); b[11] = ck.toByte()
        // UDP header (checksum 0 is legal for IPv4)
        b[20] = 0; b[21] = 53
        b[22] = (dstPort shr 8).toByte(); b[23] = dstPort.toByte()
        val udpLen = 8 + payload.size
        b[24] = (udpLen shr 8).toByte(); b[25] = udpLen.toByte()
        System.arraycopy(payload, 0, b, 28, payload.size)
        try { out.write(b) } catch (_: Exception) {}
    }

    private fun ipChecksum(b: ByteArray, len: Int): Int {
        var sum = 0
        var i = 0
        while (i < len) {
            sum += ((b[i].toInt() and 0xFF) shl 8) or (b[i + 1].toInt() and 0xFF)
            i += 2
        }
        while (sum shr 16 != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        return sum.inv() and 0xFFFF
    }

    // ───────────────────────── notification ─────────────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Website protection", NotificationManager.IMPORTANCE_LOW)
            ch.description = "Shown while Godfident is blocking websites"
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 1, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Website protection is on")
            .setContentText("Godfident is blocking your protected websites.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }
}
