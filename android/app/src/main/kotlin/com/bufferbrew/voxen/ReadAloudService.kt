package com.bufferbrew.voxen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.widget.Toast
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Reads selected text in the background, with a "Reading aloud"
 * notification that names the voice and has Stop and Device voice buttons.
 *
 * The reading itself is Dart (`lib/features/read_aloud/selection_reader.dart`),
 * run in a Flutter engine with no screen, so it uses the same Kokoro server,
 * on-phone Kokoro and device voice as the app, in the order picked in
 * Settings ("Read aloud in other apps").
 *
 * Selecting new text while it reads replaces the reading. The service stops
 * itself when it finishes, and the engine goes with it.
 *
 * Audio focus is left to the players: a focus request here would be taken
 * away by Auri's own Kokoro player, and read as "stop".
 */
class ReadAloudService : Service() {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var engineReady = false
    private var waiting: String? = null
    private var text = ""
    private var voice = "Starting…"
    private var why: String? = null
    private var onDevice = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                finishReading()
                return START_NOT_STICKY
            }
            ACTION_DEVICE -> {
                send("device", null)
                return START_NOT_STICKY
            }
            ACTION_REFRESH -> {
                if (text.isNotEmpty()) notifyNow()
                return START_NOT_STICKY
            }
        }
        val incoming = intent?.getStringExtra(EXTRA_TEXT)?.trim().orEmpty()
        if (incoming.isEmpty()) {
            if (text.isEmpty()) stopSelf()
            return START_NOT_STICKY
        }
        text = incoming
        voice = "Starting…"
        why = null
        onDevice = false
        goForeground()
        try {
            startEngine()
            send("read", incoming)
        } catch (e: Exception) {
            Toast.makeText(this, "Auri couldn’t start reading", Toast.LENGTH_LONG).show()
            finishReading()
        }
        return START_NOT_STICKY
    }

    private fun startEngine() {
        if (engine != null) return
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val e = FlutterEngine(applicationContext)
        channel = MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> {
                        engineReady = true
                        waiting?.let { invokeMethod("read", it) }
                        waiting = null
                    }
                    "source" -> {
                        voice = call.argument<String>("label") ?: voice
                        why = call.argument<String>("why")
                        onDevice = call.argument<Boolean>("device") ?: false
                        notifyNow()
                    }
                    "done" -> finishReading()
                    "error" -> {
                        Toast.makeText(
                            this@ReadAloudService,
                            call.arguments as? String ?: "Couldn’t read that",
                            Toast.LENGTH_LONG,
                        ).show()
                        finishReading()
                    }
                }
                result.success(null)
            }
        }
        e.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "readAloudMain"),
        )
        engine = e
    }

    private fun send(method: String, argument: String?) {
        val c = channel ?: return
        if (method == "read" && !engineReady) {
            waiting = argument
            return
        }
        if (engineReady) c.invokeMethod(method, argument)
    }

    private fun finishReading() {
        if (engineReady) channel?.invokeMethod("stop", null)
        text = ""
        waiting = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        engine?.destroy()
        engine = null
        channel = null
        engineReady = false
        super.onDestroy()
    }

    private fun goForeground() {
        val n = notification()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun notifyNow() {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification())
    }

    private fun action(action: String) = PendingIntent.getService(
        this,
        action.hashCode(),
        Intent(this, ReadAloudService::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Reading aloud", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) },
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val preview = text.replace(Regex("\\s+"), " ").let {
            if (it.length > 120) it.take(119).trimEnd() + "…" else it
        }
        val stop = action(ACTION_STOP)
        builder
            .setSmallIcon(R.drawable.ic_stat_read_aloud)
            .setContentTitle("Reading aloud")
            .setSubText(voice)
            .setContentText(why?.let { "$it · $preview" } ?: preview)
            .setStyle(
                Notification.BigTextStyle().bigText(
                    listOfNotNull(voice, why?.let { "$it, so the next voice reads." }, preview)
                        .joinToString("\n"),
                ),
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setDeleteIntent(stop)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
        if (!onDevice) {
            builder.addAction(
                Notification.Action.Builder(null, "Device voice", action(ACTION_DEVICE)).build(),
            )
        }
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    companion object {
        private const val CHANNEL = "voxen/read_aloud"
        private const val CHANNEL_ID = "read_aloud"
        private const val NOTIFICATION_ID = 7
        private const val EXTRA_TEXT = "text"
        private const val ACTION_STOP = "com.bufferbrew.voxen.STOP_READING"
        private const val ACTION_DEVICE = "com.bufferbrew.voxen.DEVICE_VOICE"
        private const val ACTION_REFRESH = "com.bufferbrew.voxen.REFRESH_READING"

        /** Starts reading [text]. False if Android wouldn't start the reader. */
        fun read(context: Context, text: String): Boolean = try {
            val intent = Intent(context, ReadAloudService::class.java).putExtra(EXTRA_TEXT, text)
            if (Build.VERSION.SDK_INT >= 26) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            false
        }

        /** Re-posts the notification, e.g. once notifications are allowed. */
        fun refresh(context: Context) {
            try {
                context.startService(
                    Intent(context, ReadAloudService::class.java).setAction(ACTION_REFRESH),
                )
            } catch (_: Exception) {
            }
        }
    }
}
