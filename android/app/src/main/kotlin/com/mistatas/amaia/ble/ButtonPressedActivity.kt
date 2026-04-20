package com.mistatas.amaia.ble

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.mistatas.amaia.MainActivity

class ButtonPressedActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        android.util.Log.d("ButtonPressedActivity", "Overlay activity shown, opening MainActivity")

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("opened_from_button", true)
        }

        startActivity(mainIntent)
        finish()
    }
}
