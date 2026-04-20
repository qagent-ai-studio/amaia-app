package com.mistatas.amaia.ble

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

class EmergencyCallActivity : Activity() {

    companion object {
        const val EXTRA_PHONE_NUMBER = "phone_number"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER)

        if (phoneNumber != null) {
            android.util.Log.d("EmergencyCall", "Making emergency call to: $phoneNumber")

            try {
                val callIntent = Intent(Intent.ACTION_CALL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(callIntent)
                android.util.Log.d("EmergencyCall", "Emergency call initiated successfully")
            } catch (e: Exception) {
                android.util.Log.e("EmergencyCall", "Failed to make emergency call", e)
            }
        } else {
            android.util.Log.w("EmergencyCall", "No phone number provided")
        }

        finish()
    }
}
