package com.mistatas.amaia.ble

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.mistatas.amaia.MainActivity

/**
 * Trampoline Activity: Se puede lanzar desde background y redirige a MainActivity
 * Esta técnica evita las restricciones de Samsung AppJumpBlockTool
 */
class TrampolineActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        android.util.Log.d("TrampolineActivity", "Trampoline launched, redirecting to MainActivity")
        
        // Redirigir inmediatamente a MainActivity
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("opened_from_button", true)
        }
        
        startActivity(mainIntent)
        finish() // Cerrar el trampoline inmediatamente
    }
}
