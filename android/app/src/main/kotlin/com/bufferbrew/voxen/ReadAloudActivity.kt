package com.bufferbrew.voxen

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle

/**
 * "Read aloud" in other apps' text-selection menu.
 *
 * It has no screen: it hands the selection to [ReadAloudService], which reads
 * it with the voice picked in Settings (Kokoro or the device voice), and
 * closes at once. The app you
 * selected the text in stays in front, so nothing opens or blinks.
 *
 * The first time only, it asks to show notifications, so the reading gets a
 * Stop button.
 */
class ReadAloudActivity : Activity() {
    private var started = false

    override fun onResume() {
        super.onResume()
        if (started) return
        started = true
        val text = intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            ?.toString()?.trim().orEmpty()
        if (text.isNotEmpty() && !ReadAloudService.read(this, text)) {
            // Android refused the background reader: open Voxen with the text.
            startActivity(
                Intent(this, MainActivity::class.java)
                    .setAction(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, text)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
        if (shouldAskForNotifications()) {
            prefs().edit().putBoolean(ASKED, true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        } else {
            close()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            ReadAloudService.refresh(this)
        }
        close()
    }

    private fun shouldAskForNotifications() =
        Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED &&
            !prefs().getBoolean(ASKED, false)

    private fun prefs() = getSharedPreferences("read_aloud", MODE_PRIVATE)

    private fun close() {
        finish()
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    private companion object {
        const val ASKED = "asked_notifications"
    }
}
