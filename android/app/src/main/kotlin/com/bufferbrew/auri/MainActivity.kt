package com.bufferbrew.auri

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from other apps (Share sheet) and hands it to
 * Flutter. "Read aloud" in the selection menu goes to [ReadAloudActivity]
 * instead, which reads without opening the app.
 *
 * Flutter pulls the text with `takeText`, so a cold start can't lose it to a
 * race with engine start-up; while running, `textAvailable` tells Flutter to
 * pull again.
 */
class MainActivity : AudioServiceActivity() {
    private var channel: MethodChannel? = null
    private var pendingText: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity gets its old intent again; don't replay it.
        if (savedInstanceState == null) pendingText = textFrom(intent)
        super.onCreate(savedInstanceState)
        if (pendingText != null) channel?.invokeMethod("textAvailable", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeText") {
                    result.success(pendingText)
                    pendingText = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = textFrom(intent) ?: return
        pendingText = text
        channel?.invokeMethod("textAvailable", null)
    }

    private fun textFrom(intent: Intent?): Map<String, String?>? {
        val text = when (intent?.action) {
            Intent.ACTION_PROCESS_TEXT ->
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            Intent.ACTION_SEND ->
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            else -> null
        }
        if (text.isNullOrBlank()) return null
        return mapOf(
            "text" to text,
            "subject" to intent?.getStringExtra(Intent.EXTRA_SUBJECT),
        )
    }

    private companion object {
        const val CHANNEL = "auri/incoming_text"
    }
}
