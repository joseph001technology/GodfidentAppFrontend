package com.example.godfident_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Plays the alarm sound on the ALARM stream (looping) from a foreground
 * service until Stop / Start is pressed, the app is opened from the alarm, or
 * the time limit is reached.
 *
 * Why not a notification sound: Android silences a notification sound when
 * another notification arrives or a volume key is pressed. This player simply
 * ignores audio-focus loss and keeps going; the volume keys only change the
 * loudness.
 */
class AlarmRingService : Service() {

    companion object {
        const val ACTION_STOP = "com.example.godfident_flutter.ALARM_STOP"
        private const val CHANNEL = "godfident_alarm_ring"
        @Volatile var running = false

        fun stop(c: Context) {
            c.startService(Intent(c, AlarmRingService::class.java).setAction(ACTION_STOP))
        }

        private fun ensureChannel(c: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.getNotificationChannel(CHANNEL) == null) {
                    val ch = NotificationChannel(CHANNEL, "Ringing alarms", NotificationManager.IMPORTANCE_HIGH)
                    ch.setSound(null, null) // the sound comes from the service, not the channel
                    ch.enableVibration(false)
                    ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    nm.createNotificationChannel(ch)
                }
            }
        }

        private fun openApp(c: Context, id: Int, route: String): PendingIntent {
            val i = Intent(c, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(MainActivity.EXTRA_ALARM_ROUTE, route)
            return PendingIntent.getActivity(
                c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun build(c: Context, id: Int, title: String, body: String, route: String, startLabel: String): Notification {
            ensureChannel(c)
            val stopPi = PendingIntent.getService(
                c, 900000 + id,
                Intent(c, AlarmRingService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val open = openApp(c, id, route)
            val b = NotificationCompat.Builder(c, CHANNEL)
                .setSmallIcon(c.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(open)
                .setFullScreenIntent(open, true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            if (startLabel.isNotEmpty()) b.addAction(0, startLabel, open)
            b.addAction(0, "Stop", stopPi)
            return b.build()
        }

        /** Used only when the service could not be started. */
        fun postPlainNotification(c: Context, id: Int, title: String, body: String, route: String) {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(id, build(c, id, title, body, route, ""))
        }
    }

    private var player: MediaPlayer? = null
    private var focusReq: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentId = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        // A new alarm replaces whatever was ringing.
        releasePlayer()

        currentId = intent.getIntExtra("id", 1)
        val title = intent.getStringExtra("title") ?: "Godfident"
        val body = intent.getStringExtra("body") ?: ""
        val route = intent.getStringExtra("route") ?: ""
        val sound = intent.getStringExtra("sound") ?: ""
        val maxSec = intent.getIntExtra("max", 60)
        val startLabel = intent.getStringExtra("start") ?: ""

        val n = build(this, currentId, title, body, route, startLabel)
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(currentId, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(currentId, n)
            }
        } catch (_: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        startSound(sound)
        startVibration()
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ shutdown() }, maxSec.coerceIn(10, 3600) * 1000L)
        return START_NOT_STICKY
    }

    private fun startSound(sound: String) {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                // No change listener on purpose: losing focus must NOT stop an alarm.
                focusReq = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(attrs)
                    .build()
                am.requestAudioFocus(focusReq!!)
            }
        } catch (_: Exception) {}

        val uri: Uri = if (sound.isNotEmpty()) Uri.parse(sound)
        else Settings.System.DEFAULT_ALARM_ALERT_URI
        val mp = MediaPlayer()
        try {
            mp.setAudioAttributes(attrs)
            mp.setDataSource(this, uri)
            mp.isLooping = true
            mp.prepare()
            mp.start()
            player = mp
        } catch (_: Exception) {
            // The chosen song may be gone/unreadable: fall back to the phone's alarm tone.
            try {
                mp.reset()
                mp.setAudioAttributes(attrs)
                mp.setDataSource(this, Settings.System.DEFAULT_ALARM_ALERT_URI)
                mp.isLooping = true
                mp.prepare()
                mp.start()
                player = mp
            } catch (_: Exception) {
                mp.release()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun startVibration() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 600, 500)
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createWaveform(pattern, 0))
            else v.vibrate(pattern, 0)
        } catch (_: Exception) {}
    }

    private fun releasePlayer() {
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
        try {
            (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
        } catch (_: Exception) {}
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= 26) focusReq?.let { am.abandonAudioFocusRequest(it) }
        } catch (_: Exception) {}
        focusReq = null
    }

    private fun shutdown() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        running = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        running = false
        super.onDestroy()
    }
}
