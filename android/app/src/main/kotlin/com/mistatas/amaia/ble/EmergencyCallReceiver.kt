package com.mistatas.amaia.ble

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/**
 * BroadcastReceiver para iniciar llamadas de emergencia.
 * 
 * Los BroadcastReceivers pueden iniciar actividades incluso cuando la app está
 * en background, evitando las restricciones de Android 10+ y Samsung Android 15.
 */
class EmergencyCallReceiver : BroadcastReceiver() {
    
    companion object {
        const val ACTION_MAKE_EMERGENCY_CALL = "com.mistatas.amaia.MAKE_EMERGENCY_CALL"
        const val EXTRA_PHONE_NUMBER = "phone_number"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_MAKE_EMERGENCY_CALL) {
            val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER)
            
            if (phoneNumber.isNullOrEmpty()) {
                android.util.Log.w("EmergencyCallReceiver", "No phone number provided")
                return
            }
            
            android.util.Log.d("EmergencyCallReceiver", "Received emergency call request for: $phoneNumber")
            
            try {
                // Crear intent de llamada con todos los flags necesarios
                val callIntent = Intent(Intent.ACTION_CALL).apply {
                    data = Uri.parse("tel:$phoneNumber")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_NO_HISTORY
                    
                    // En Android 10+ agregar flag para bypass de restricciones de background
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                    }
                }
                
                context.startActivity(callIntent)
                android.util.Log.d("EmergencyCallReceiver", "Emergency call initiated successfully from BroadcastReceiver")
            } catch (e: SecurityException) {
                android.util.Log.e("EmergencyCallReceiver", "Missing CALL_PHONE permission", e)
            } catch (e: Exception) {
                android.util.Log.e("EmergencyCallReceiver", "Failed to make emergency call from receiver", e)
            }
        }
    }
}
