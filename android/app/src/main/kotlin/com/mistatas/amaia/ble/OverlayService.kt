package com.mistatas.amaia.ble

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import com.mistatas.amaia.MainActivity
import com.mistatas.amaia.R

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showOverlay()
        return START_NOT_STICKY
    }

    private fun showOverlay() {

        if (overlayView != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        overlayView = LayoutInflater.from(this).inflate(R.layout.overlay_button_pressed, null)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        val content = overlayView?.findViewById<LinearLayout>(R.id.overlay_content)
        content?.setOnClickListener {
            openApp()
        }

        val button = overlayView?.findViewById<View>(R.id.open_button)
        button?.setOnClickListener {
            openApp()
        }

        try {
            windowManager?.addView(overlayView, params)
            android.util.Log.d("OverlayService", "Overlay shown successfully")
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Failed to show overlay", e)
            stopSelf()
        }
    }

    private fun openApp() {
        android.util.Log.d("OverlayService", "Opening app from overlay")

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("opened_from_button", true)
        }

        try {
            startActivity(intent)
            removeOverlay()
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Failed to open app", e)
        }
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
        stopSelf()
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }
}
