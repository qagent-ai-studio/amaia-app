package com.mistatas.amaia.ble

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.moko.ble.lib.MokoConstants
import com.moko.ble.lib.event.ConnectStatusEvent
import com.moko.ble.lib.event.OrderTaskResponseEvent
import com.moko.support.d.DMokoSupport
import com.moko.support.d.entity.OrderCHAR
import com.mistatas.amaia.MainActivity
import com.mistatas.amaia.R
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

/**
 * Servicio en foreground que mantiene la conexión BLE activa en segundo plano
 * para poder abrir la app cuando se presione el botón MK Button
 */
class MkButtonBackgroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "mk_button_service"
        private const val ALERT_CHANNEL_ID = "mk_button_alerts" // Canal separado para alertas
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START_SERVICE = "com.mistatas.amaia.START_BLE_SERVICE"
        const val ACTION_STOP_SERVICE = "com.mistatas.amaia.STOP_BLE_SERVICE"
        const val EXTRA_MAC = "mac"
        const val EXTRA_PASSWORD = "password"
        const val EXTRA_CLICK_TYPE = "clickType"
        const val EXTRA_BUTTON_ACTION = "buttonAction" // 'open_app', 'call', 'sms'
        const val EXTRA_EMERGENCY_PHONE = "emergencyPhone"

        fun startService(context: Context, mac: String, password: String, clickType: String, 
                        buttonAction: String = "open_app", emergencyPhone: String? = null) {
            val intent = Intent(context, MkButtonBackgroundService::class.java).apply {
                action = ACTION_START_SERVICE
                putExtra(EXTRA_MAC, mac)
                putExtra(EXTRA_PASSWORD, password)
                putExtra(EXTRA_CLICK_TYPE, clickType)
                putExtra(EXTRA_BUTTON_ACTION, buttonAction)
                putExtra(EXTRA_EMERGENCY_PHONE, emergencyPhone)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, MkButtonBackgroundService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            context.stopService(intent)
        }
    }

    private var deviceMac: String? = null
    private var devicePassword: String? = null
    private var clickTypeToOpen: String = "single" // 'single', 'double', 'disabled'
    private var buttonAction: String = "open_app" // 'open_app', 'call', 'sms'
    private var emergencyPhone: String? = null
    private var isConnected = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        createAlertNotificationChannel() // Canal para alertas heads-up
        EventBus.getDefault().register(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("MkButtonBgService", "onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_SERVICE -> {
                deviceMac = intent.getStringExtra(EXTRA_MAC)
                devicePassword = intent.getStringExtra(EXTRA_PASSWORD) ?: "Moko4321"
                clickTypeToOpen = intent.getStringExtra(EXTRA_CLICK_TYPE) ?: "single"
                buttonAction = intent.getStringExtra(EXTRA_BUTTON_ACTION) ?: "open_app"
                emergencyPhone = intent.getStringExtra(EXTRA_EMERGENCY_PHONE)

                android.util.Log.d("MkButtonBgService", "Starting service: mac=$deviceMac, clickType=$clickTypeToOpen")
                
                startForeground(NOTIFICATION_ID, createNotification("Conectando..."))

                deviceMac?.let { mac ->
                    connectToDevice(mac, devicePassword!!)
                } ?: run {
                    android.util.Log.e("MkButtonBgService", "No MAC address provided")
                    stopSelf()
                }
            }
            ACTION_STOP_SERVICE -> {
                android.util.Log.d("MkButtonBgService", "Stopping service")
                disconnectAndStop()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        EventBus.getDefault().unregister(this)
        DMokoSupport.getInstance().disConnectBle()
    }

    private fun connectToDevice(mac: String, password: String) {
        android.util.Log.d("MkButtonBgService", "Connecting to device: $mac")
        
        // Configurar password antes de conectar
        DMokoSupport.getInstance().setPassword(password)
        DMokoSupport.getInstance().connDevice(mac)
    }

    private fun disconnectAndStop() {
        DMokoSupport.getInstance().disConnectBle()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onConnectStatusEvent(event: ConnectStatusEvent) {
        when (event.action) {
            MokoConstants.ACTION_DISCOVER_SUCCESS -> {
                isConnected = true
                android.util.Log.d("MkButtonBgService", "Device connected in background")
                updateNotification("Conectado - Esperando eventos")
            }
            MokoConstants.ACTION_DISCONNECTED -> {
                isConnected = false
                android.util.Log.d("MkButtonBgService", "Device disconnected, reconnecting...")
                updateNotification("Desconectado - Reconectando...")
                
                // Intentar reconectar después de 5 segundos
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    deviceMac?.let { mac ->
                        devicePassword?.let { password ->
                            connectToDevice(mac, password)
                        }
                    }
                }, 5000)
            }
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onOrderTaskResponseEvent(event: OrderTaskResponseEvent) {
        if (event.action == MokoConstants.ACTION_CURRENT_DATA) {
            val response = event.response ?: return
            
            // Verificar si es un evento de click
            if (response.orderCHAR == OrderCHAR.CHAR_CLICK_EVENT) {
                val value = response.responseValue ?: return
                
                // Parsear tipo de click: EB 02 06 01 XX
                if (value.size >= 5) {
                    val clickType = when (value[4].toInt() and 0xFF) {
                        0x01 -> "single"
                        0x02 -> "double"
                        0x03 -> "long"
                        else -> "single"
                    }
                    
                    android.util.Log.d("MkButtonBgService", "Click received: $clickType, configured: $clickTypeToOpen")
                    
                    // Verificar si este tipo de click debe ejecutar la acción
                    if (clickType == clickTypeToOpen && clickTypeToOpen != "disabled") {
                        executeButtonAction()
                    }
                }
            }
        }
    }

    private fun executeButtonAction() {
        android.util.Log.d("MkButtonBgService", "Executing button action: $buttonAction")
        
        when (buttonAction) {
            "call" -> attemptAutomaticCall()
            "sms" -> sendEmergencySMS()
            "sms_and_call" -> {
                // Ejecutar AMBAS acciones: primero SMS geolocalizado, luego intento de llamada
                sendEmergencySMS()
                
                // Intentar hacer llamada automática (funciona en Huawei, falla silenciosamente en Samsung)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    attemptAutomaticCall()
                }, 500) // Delay corto para que el SMS se envíe primero
            }
            else -> openApp() // 'open_app' por defecto
        }
    }
    
    private fun attemptAutomaticCall() {
        if (emergencyPhone.isNullOrEmpty()) return
        
        android.util.Log.d("MkButtonBgService", "Attempting automatic emergency call to: $emergencyPhone")
        
        try {
            // INTENTO 1: Llamada directa (funciona en Huawei Android 9, falla en Samsung Android 15)
            val callIntent = Intent(Intent.ACTION_CALL).apply {
                data = android.net.Uri.parse("tel:$emergencyPhone")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            startActivity(callIntent)
            android.util.Log.d("MkButtonBgService", "Automatic call initiated successfully (Huawei-compatible)")
            
        } catch (e: Exception) {
            // Si falla (Samsung Android 15), no hacer nada - solo enviar SMS es suficiente
            android.util.Log.i("MkButtonBgService", "Automatic call blocked by system (Samsung-like restrictions). SMS already sent, emergency contact notified.")
        }
    }
    
    private fun sendEmergencySMS() {
        if (emergencyPhone.isNullOrEmpty()) {
            android.util.Log.w("MkButtonBgService", "No emergency phone configured")
            return
        }
        
        android.util.Log.d("MkButtonBgService", "Sending emergency SMS to: $emergencyPhone")
        
        try {
            // Intentar primero obtener ubicación de SharedPreferences (guardada por Flutter)
            var location = getLocationFromSharedPreferences()
            
            // Si no hay ubicación guardada, intentar obtener del sistema
            if (location == null) {
                android.util.Log.d("MkButtonBgService", "No location in SharedPreferences, trying system location")
                location = getCurrentLocation()
            } else {
                android.util.Log.d("MkButtonBgService", "Using location from SharedPreferences")
            }
            
            // Construir mensaje con coordenadas GPS
            val message = if (location != null) {
                "🚨 ALERTA: Botón de emergencia presionado\n" +
                "Lat: ${location.latitude}\n" +
                "Lon: ${location.longitude}"
            } else {
                "🚨 ALERTA: Botón de emergencia presionado\n" +
                "(Ubicación no disponible)"
            }
            
            // Enviar SMS directamente usando SmsManager (SILENT, sin abrir la app de SMS)
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            
            // Si el mensaje es largo, dividirlo en partes
            val parts = smsManager.divideMessage(message)
            
            if (parts.size == 1) {
                smsManager.sendTextMessage(emergencyPhone, null, message, null, null)
            } else {
                smsManager.sendMultipartTextMessage(emergencyPhone, null, parts, null, null)
            }
            
            android.util.Log.d("MkButtonBgService", "Emergency SMS sent successfully with location: ${location?.latitude}, ${location?.longitude}")
            
            // VIBRAR INMEDIATAMENTE al enviar el SMS
            triggerImmediateVibration()
            
            // Mostrar notificación de confirmación con sonido
            showSMSSentNotification(location)
            
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Failed to send emergency SMS", e)
            showSMSErrorNotification(e.message ?: "Error desconocido")
        }
    }
    
    private fun getLocationFromSharedPreferences(): Location? {
        try {
            val sharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val geoString = sharedPreferences.getString("flutter.geo", null)
            
            if (geoString.isNullOrEmpty()) {
                android.util.Log.d("MkButtonBgService", "No geo data in SharedPreferences")
                return null
            }
            
            // El formato guardado es "latitude, longitude" (con espacio después de la coma)
            val parts = geoString.split(",").map { it.trim() }
            if (parts.size != 2) {
                android.util.Log.w("MkButtonBgService", "Invalid geo format in SharedPreferences: $geoString")
                return null
            }
            
            val latitude = parts[0].toDoubleOrNull()
            val longitude = parts[1].toDoubleOrNull()
            
            if (latitude == null || longitude == null) {
                android.util.Log.w("MkButtonBgService", "Could not parse coordinates: $geoString")
                return null
            }
            
            // Crear un objeto Location con las coordenadas de SharedPreferences
            val location = Location("SharedPreferences").apply {
                this.latitude = latitude
                this.longitude = longitude
                time = System.currentTimeMillis()
            }
            
            android.util.Log.d("MkButtonBgService", "Location from SharedPreferences: lat=$latitude, lon=$longitude")
            return location
            
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Error reading location from SharedPreferences", e)
            return null
        }
    }
    
    private fun getCurrentLocation(): Location? {
        try {
            // Verificar permisos de ubicación
            if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                android.util.Log.w("MkButtonBgService", "Location permissions not granted")
                return null
            }
            
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            
            // Verificar qué proveedores están habilitados
            val gpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val networkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            android.util.Log.d("MkButtonBgService", "GPS enabled: $gpsEnabled, Network enabled: $networkEnabled")
            
            // Intentar obtener la última ubicación conocida de todos los proveedores
            var bestLocation: Location? = null
            var bestTime: Long = 0
            
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
            
            for (provider in providers) {
                try {
                    if (locationManager.isProviderEnabled(provider)) {
                        val location = locationManager.getLastKnownLocation(provider)
                        if (location != null) {
                            android.util.Log.d("MkButtonBgService", "Location from $provider: lat=${location.latitude}, lon=${location.longitude}, time=${location.time}, accuracy=${location.accuracy}m")
                            
                            // Elegir la ubicación más reciente
                            if (location.time > bestTime) {
                                bestLocation = location
                                bestTime = location.time
                            }
                        } else {
                            android.util.Log.d("MkButtonBgService", "No last known location from $provider")
                        }
                    } else {
                        android.util.Log.d("MkButtonBgService", "Provider $provider is disabled")
                    }
                } catch (e: Exception) {
                    android.util.Log.w("MkButtonBgService", "Error getting location from $provider: ${e.message}")
                }
            }
            
            if (bestLocation != null) {
                val age = (System.currentTimeMillis() - bestLocation.time) / 1000 // segundos
                android.util.Log.d("MkButtonBgService", "Using best location: lat=${bestLocation.latitude}, lon=${bestLocation.longitude}, age=${age}s")
                return bestLocation
            }
            
            android.util.Log.w("MkButtonBgService", "No location available from any provider. Make sure GPS/Network location is enabled and the app has been granted location permissions.")
            return null
            
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Error getting location", e)
            return null
        }
    }
    
    private fun triggerImmediateVibration() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Patrón de vibración: vibrar-pausa-vibrar-pausa-vibrar
                val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
            }
            
            android.util.Log.d("MkButtonBgService", "Immediate vibration triggered")
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Failed to trigger vibration", e)
        }
    }
    
    private fun showSMSSentNotification(location: Location?) {
        android.util.Log.d("MkButtonBgService", "===== showSMSSentNotification called =====")
        
        val locationInfo = if (location != null) {
            "📍 Ubicación: Lat ${location.latitude}, Lon ${location.longitude}"
        } else {
            "⚠️ Sin ubicación GPS disponible"
        }
        
        android.util.Log.d("MkButtonBgService", "Location info: $locationInfo")
        android.util.Log.d("MkButtonBgService", "Emergency phone: $emergencyPhone")
        
        // Intent para abrir la app al tocar la notificación
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // Sonido de notificación de emergencia
        val alarmSound = android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
        
        android.util.Log.d("MkButtonBgService", "Building notification with channel: $ALERT_CHANNEL_ID")
        
        // ACTUALIZAR la notificación del servicio foreground con la información del SMS
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload_done)
            .setContentTitle("✅ SMS de Emergencia Enviado")
            .setContentText("Mensaje enviado a $emergencyPhone")
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle("✅ SMS de Emergencia Enviado")
                .bigText("📱 Destinatario: $emergencyPhone\n$locationInfo\n\n🔘 Servicio MK Button activo\nToca para abrir Amaia"))
            .setPriority(NotificationCompat.PRIORITY_MAX) // MAX para asegurar heads-up
            .setCategory(NotificationCompat.CATEGORY_ALARM) // Categoría de alarma
            .setOngoing(true) // Mantener la notificación (es el servicio foreground)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500)) // Vibración más fuerte y larga
            .setSound(alarmSound) // Sonido de notificación explícito
            .setDefaults(NotificationCompat.DEFAULT_ALL) // Todos los defaults (sonido + vibración + luces)
            .setColor(0xFF00AA00.toInt()) // Verde
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(false) // Permitir alertas múltiples
            .setContentIntent(pendingIntent)
            .build()
        
        android.util.Log.d("MkButtonBgService", "Notification built successfully")
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        
        // Verificar si el canal está habilitado
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = notificationManager.getNotificationChannel(ALERT_CHANNEL_ID)
            android.util.Log.d("MkButtonBgService", "Alert channel exists: ${channel != null}")
            android.util.Log.d("MkButtonBgService", "Alert channel importance: ${channel?.importance}")
            
            if (channel == null) {
                android.util.Log.e("MkButtonBgService", "ALERT_CHANNEL_ID not found! Creating it now...")
                createAlertNotificationChannel()
            }
        }
        
        // Usar NOTIFICATION_ID (1001) del servicio foreground en lugar de crear una nueva (3001)
        notificationManager.notify(NOTIFICATION_ID, notification)
        android.util.Log.d("MkButtonBgService", "Notification posted with ID: $NOTIFICATION_ID")
        
        // Después de 10 segundos, restaurar la notificación normal del servicio
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            android.util.Log.d("MkButtonBgService", "Restoring normal notification after 10 seconds")
            updateNotification("Conectado - Esperando eventos")
        }, 10000)
    }
    
    private fun showSMSErrorNotification(error: String) {
        // Intent para abrir la app al tocar la notificación
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // ACTUALIZAR la notificación del servicio foreground con el error
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("❌ Error al Enviar SMS de Emergencia")
            .setContentText("No se pudo enviar el mensaje a $emergencyPhone")
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle("❌ Error al Enviar SMS de Emergencia")
                .bigText("📱 Destinatario: $emergencyPhone\n⚠️ Error: $error\n\nVerifique permisos y cobertura de red.\n\n🔘 Servicio MK Button activo\nToca para abrir Amaia"))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true) // Mantener la notificación (es el servicio foreground)
            .setVibrate(longArrayOf(0, 300, 200, 300, 200, 300)) // Vibración de alerta
            .setColor(0xFFFF0000.toInt()) // Rojo
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        // Usar NOTIFICATION_ID (1001) del servicio foreground
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        // Después de 10 segundos, restaurar la notificación normal del servicio
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            updateNotification("Conectado - Esperando eventos")
        }, 10000)
    }
    
    private fun openApp() {
        android.util.Log.d("MkButtonBgService", "Opening app from background")
        
        try {
            // Enviar broadcast para abrir la app (Samsung lo bloqueará, pero intentamos)
            val broadcastIntent = Intent(OpenAppReceiver.ACTION_OPEN_APP).apply {
                setPackage(packageName)
            }
            sendBroadcast(broadcastIntent)
            android.util.Log.d("MkButtonBgService", "Broadcast sent to open app")
            
            // Mostrar notificación INMEDIATAMENTE sobre la pantalla
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("opened_from_button", true)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                this,
                1001,
                activityIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            
            // Notificación HEADS-UP usando el canal de alertas
            val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("🔘 BOTÓN PRESIONADO")
                .setContentText("⚡ TOCA PARA ABRIR AMAIA ⚡")
                .setStyle(NotificationCompat.BigTextStyle()
                    .setBigContentTitle("🔘 BOTÓN MK PRESIONADO")
                    .bigText("Toca esta notificación para abrir Amaia"))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .setDefaults(NotificationCompat.DEFAULT_ALL) // Sonido + vibración + luces
                .setOngoing(false)
                .setOnlyAlertOnce(false) // Permitir múltiples alertas
                // NO usar timeoutAfter para que permanezca hasta tocarla
                .setFullScreenIntent(pendingIntent, true)
                .build()
            
            notificationManager.notify(2001, notification)
            android.util.Log.d("MkButtonBgService", "Heads-up notification shown")
            
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Failed to open app", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MK Button Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Mantiene la conexión con el botón MK Button"
                setShowBadge(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                setSound(null, null) // Sin sonido para el canal del servicio
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createAlertNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.util.Log.d("MkButtonBgService", "Creating ALERT notification channel: $ALERT_CHANNEL_ID")
            
            val alarmSound = android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                .build()
            
            val channel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "MK Button Emergencias",
                NotificationManager.IMPORTANCE_HIGH // HIGH permite sonido y vibración
            ).apply {
                description = "Alertas de emergencia cuando se presiona el botón MK Button"
                setShowBadge(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.RED
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Bypass Do Not Disturb para emergencias
                setSound(alarmSound, audioAttributes) // Sonido de alarma
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
            
            android.util.Log.d("MkButtonBgService", "ALERT channel created with importance: ${channel.importance}")
        }
    }

    private fun createNotification(contentText: String): Notification {
        // Intent para abrir la app al tocar la notificación
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MK Button Activo")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(contentText))
    }
}
