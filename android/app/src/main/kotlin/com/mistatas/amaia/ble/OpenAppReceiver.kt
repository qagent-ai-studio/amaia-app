package com.mistatas.amaia.ble

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

class OpenAppReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_OPEN_APP = "com.mistatas.amaia.OPEN_APP_FROM_BUTTON"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_OPEN_APP) {
            android.util.Log.d("OpenAppReceiver", "Broadcast received, attempting direct launch")

            try {
                val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    setClassName(context.packageName, "com.mistatas.amaia.MainActivity")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                    putExtra("opened_from_button", true)
                }

                context.startActivity(launchIntent)
                android.util.Log.d("OpenAppReceiver", "App opened directly")
                return

            } catch (e: Exception) {
                android.util.Log.w("OpenAppReceiver", "Direct launch failed: ${e.message}")
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                android.util.Log.w("OpenAppReceiver", "Overlay permission not granted, using notification only")
                return
            }

            val overlayIntent = Intent(context, OverlayService::class.java)

            try {
                context.startService(overlayIntent)
                android.util.Log.d("OpenAppReceiver", "Overlay service started as fallback")
            } catch (e: Exception) {
                android.util.Log.e("OpenAppReceiver", "Failed to start overlay service", e)
            }
        }
    }
}
