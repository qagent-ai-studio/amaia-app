package com.mistatas.amaia

import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Helper para detectar y solicitar permisos críticos en Samsung A06 (One UI 8.0)
 */
object PermissionHelper {
    
    /**
     * Verifica si el dispositivo es Samsung
     */
    fun isSamsungDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("samsung")
    }
    
    /**
     * Obtiene la versión de One UI (solo Samsung)
     * Retorna 0 si no es Samsung o no se puede determinar
     */
    fun getOneUIVersion(): Int {
        if (!isSamsungDevice()) return 0
        
        return try {
            // Usar reflexión para acceder a SEM_PLATFORM_INT (solo existe en Samsung)
            val buildVersionClass = Build.VERSION::class.java
            val semPlatformInt = buildVersionClass.getDeclaredField("SEM_PLATFORM_INT")
            semPlatformInt.getInt(null)
        } catch (e: Exception) {
            // Si falla la reflexión, asumir versión según Android
            // Android 15 (API 35) generalmente viene con One UI 8.0 en Samsung
            when (Build.VERSION.SDK_INT) {
                35 -> 80000 // Android 15 = One UI 8.0
                34 -> 70000 // Android 14 = One UI 7.0
                33 -> 60000 // Android 13 = One UI 6.0
                else -> 0
            }
        }
    }
    
    /**
     * Verifica si One UI es 8.0 o superior
     */
    fun isOneUI8OrHigher(): Boolean {
        val version = getOneUIVersion()
        return version >= 80000
    }
    
    /**
     * Verifica si la app tiene permiso de "Mostrar sobre otras apps"
     */
    fun hasOverlayPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true // No requerido en Android < 6
        }
    }
    
    /**
     * Solicita permiso de "Mostrar sobre otras apps" con diálogo explicativo
     */
    fun requestOverlayPermission(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return // No necesario en Android < 6
        }
        
        if (hasOverlayPermission(context)) {
            return // Ya tiene el permiso
        }
        
        val message = if (isSamsungDevice() && isOneUI8OrHigher()) {
            "Para que el botón de emergencia funcione correctamente en tu Samsung, " +
            "necesitamos el permiso 'Mostrar sobre otras apps'.\n\n" +
            "Esto permite que la app:\n" +
            "• Realice llamadas de emergencia automáticas\n" +
            "• Envíe SMS con tu ubicación\n" +
            "• Funcione aunque la app esté cerrada\n\n" +
            "En la siguiente pantalla, busca 'Amaia' y activa el permiso."
        } else {
            "Para garantizar que el botón de emergencia funcione correctamente, " +
            "necesitamos el permiso 'Mostrar sobre otras apps'.\n\n" +
            "En la siguiente pantalla, busca 'Amaia' y activa el permiso."
        }
        
        AlertDialog.Builder(context)
            .setTitle("Permiso Requerido")
            .setMessage(message)
            .setPositiveButton("Configurar") { _, _ ->
                openOverlaySettings(context)
            }
            .setNegativeButton("Más tarde", null)
            .setCancelable(false)
            .show()
    }
    
    /**
     * Abre la configuración de "Mostrar sobre otras apps"
     */
    private fun openOverlaySettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}")
            )
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        }
    }
    
    /**
     * Verifica si la app está excluida de optimización de batería
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true // No aplica en Android < 6
        }
    }
    
    /**
     * Solicita exclusión de optimización de batería
     */
    fun requestBatteryOptimizationExemption(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return // No necesario en Android < 6
        }
        
        if (isIgnoringBatteryOptimizations(context)) {
            return // Ya está excluido
        }
        
        val message = "Para que el botón de emergencia esté siempre activo, " +
                "necesitamos desactivar la optimización de batería.\n\n" +
                "Esto garantiza que:\n" +
                "• El servicio BLE no se detenga\n" +
                "• El botón responda inmediatamente\n" +
                "• La app funcione 24/7\n\n" +
                "En la siguiente pantalla, selecciona 'Sin restricciones' o 'No optimizar'."
        
        AlertDialog.Builder(context)
            .setTitle("Optimización de Batería")
            .setMessage(message)
            .setPositiveButton("Configurar") { _, _ ->
                openBatteryOptimizationSettings(context)
            }
            .setNegativeButton("Más tarde", null)
            .setCancelable(false)
            .show()
    }
    
    /**
     * Abre la configuración de optimización de batería
     */
    private fun openBatteryOptimizationSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:${context.packageName}")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            try {
                context.startActivity(intent)
            } catch (e: Exception) {
                // Fallback: abrir configuración general de batería
                val fallbackIntent = Intent(Settings.ACTION_SETTINGS)
                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(fallbackIntent)
            }
        }
    }
    
    /**
     * Muestra advertencia si el dispositivo Samsung tiene One UI < 8.0
     */
    fun showOneUIUpdateWarningIfNeeded(context: Context) {
        if (!isSamsungDevice()) {
            return // No es Samsung, no mostrar advertencia
        }
        
        if (isOneUI8OrHigher()) {
            return // Ya tiene One UI 8.0+
        }
        
        val message = "Tu dispositivo Samsung necesita actualización a One UI 8.0 " +
                "para garantizar el funcionamiento completo del botón de emergencia.\n\n" +
                "Sin esta actualización, es posible que:\n" +
                "• Las llamadas automáticas no funcionen\n" +
                "• El botón no responda con la app cerrada\n\n" +
                "Actualiza tu dispositivo desde:\n" +
                "Configuración → Actualización de software"
        
        AlertDialog.Builder(context)
            .setTitle("Actualización Recomendada")
            .setMessage(message)
            .setPositiveButton("Entendido", null)
            .setIcon(android.R.drawable.ic_dialog_info)
            .show()
    }
    
    /**
     * Verifica TODOS los permisos críticos y solicita los faltantes
     * Debe llamarse al conectar el botón BLE por primera vez
     */
    fun checkAndRequestAllCriticalPermissions(context: Context) {
        // 1. Verificar si es Samsung antiguo
        showOneUIUpdateWarningIfNeeded(context)
        
        // 2. Verificar permiso de overlay (crítico para llamadas en Samsung)
        if (!hasOverlayPermission(context)) {
            requestOverlayPermission(context)
            return // Solicitar uno a la vez
        }
        
        // 3. Verificar optimización de batería
        if (!isIgnoringBatteryOptimizations(context)) {
            requestBatteryOptimizationExemption(context)
            return
        }
        
        // TODO: Verificar permisos de notificación (Android 13+)
        // TODO: Verificar permiso de llamadas (CALL_PHONE)
        // TODO: Verificar permiso de SMS (SEND_SMS)
    }
    
    /**
     * Obtiene información de diagnóstico del dispositivo
     */
    fun getDeviceDiagnosticInfo(context: Context): String {
        return buildString {
            appendLine("=== DIAGNÓSTICO DEL DISPOSITIVO ===")
            appendLine("Fabricante: ${Build.MANUFACTURER}")
            appendLine("Modelo: ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            
            if (isSamsungDevice()) {
                appendLine("One UI: ${getOneUIVersion() / 10000}.${(getOneUIVersion() % 10000) / 1000}")
                appendLine("One UI 8.0+: ${if (isOneUI8OrHigher()) "✅ SÍ" else "❌ NO"}")
            }
            
            appendLine("\n=== PERMISOS ===")
            appendLine("Mostrar sobre otras apps: ${if (hasOverlayPermission(context)) "✅ Otorgado" else "❌ Falta"}")
            appendLine("Optimización batería: ${if (isIgnoringBatteryOptimizations(context)) "✅ Excluido" else "❌ Optimizado"}")
        }
    }
}
