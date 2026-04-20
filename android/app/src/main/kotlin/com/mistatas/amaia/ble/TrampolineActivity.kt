package com.mistatas.amaia.ble

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.mistatas.amaia.MainActivity

class TrampolineActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        android.util.Log.d("TrampolineActivity", "Trampoline launched, redirecting to MainActivity")

        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("opened_from_button", true)
        }

        startActivity(mainIntent)
        finish()
    }
}
