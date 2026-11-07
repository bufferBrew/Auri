package com.bufferbrew.voicebrew

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text from other apps (selection menu "Read with VoiceBrew" or the
 * Share sheet) and hands it to Flutter.
 *
 * Flutter pulls the text with `takeText`, so a cold start can't lose it to a
 * race with engine start-up; while running, `textAvailable` tells Flutter to
 * pull again.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity gets its old intent again; don't replay it.
        if (savedInstanceState == null) pendingText = textFrom(intent)
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

    private fun textFrom(intent: Intent?): String? {
        val text = when (intent?.action) {
            Intent.ACTION_PROCESS_TEXT ->
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            Intent.ACTION_SEND ->
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            else -> null
        }
        return text?.takeIf { it.isNotBlank() }
    }

    private companion object {
        const val CHANNEL = "voicebrew/incoming_text"
    }
}
