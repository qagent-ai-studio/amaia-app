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

class MkButtonBackgroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "mk_button_service"
        private const val ALERT_CHANNEL_ID = "mk_button_alerts"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START_SERVICE = "com.mistatas.amaia.START_BLE_SERVICE"
        const val ACTION_STOP_SERVICE = "com.mistatas.amaia.STOP_BLE_SERVICE"
        const val ACTION_REMOVE_DEVICE = "com.mistatas.amaia.REMOVE_BLE_DEVICE"
        const val ACTION_EXECUTE_EMERGENCY = "com.mistatas.amaia.EXECUTE_EMERGENCY"
        const val EXTRA_MAC = "mac"
        const val EXTRA_PASSWORD = "password"
        const val EXTRA_CLICK_TYPE = "clickType"
        const val EXTRA_BUTTON_ACTION = "buttonAction"
        const val EXTRA_EMERGENCY_PHONE = "emergencyPhone"
        const val EXTRA_DEVICE_TYPE = "deviceType"
        const val EXTRA_DEVICE_NAME = "deviceName"

        fun startService(
            context: Context,
            mac: String,
            password: String,
            clickType: String,
            buttonAction: String = "open_app",
            emergencyPhone: String? = null,
            deviceType: String = "button",
            deviceName: String = "Dispositivo MK"
        ) {
            val intent = Intent(context, MkButtonBackgroundService::class.java).apply {
                action = ACTION_START_SERVICE
                putExtra(EXTRA_MAC, mac)
                putExtra(EXTRA_PASSWORD, password)
                putExtra(EXTRA_CLICK_TYPE, clickType)
                putExtra(EXTRA_BUTTON_ACTION, buttonAction)
                putExtra(EXTRA_EMERGENCY_PHONE, emergencyPhone)
                putExtra(EXTRA_DEVICE_TYPE, deviceType)
                putExtra(EXTRA_DEVICE_NAME, deviceName)
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

        fun removeDevice(context: Context, mac: String) {
            val intent = Intent(context, MkButtonBackgroundService::class.java).apply {
                action = ACTION_REMOVE_DEVICE
                putExtra(EXTRA_MAC, mac)
            }
            context.startService(intent)
        }

        fun executeEmergencyAction(
            context: Context,
            mac: String,
            buttonAction: String,
            emergencyPhone: String?,
            deviceName: String
        ) {
            val intent = Intent(context, MkButtonBackgroundService::class.java).apply {
                action = ACTION_EXECUTE_EMERGENCY
                putExtra(EXTRA_MAC, mac)
                putExtra(EXTRA_BUTTON_ACTION, buttonAction)
                putExtra(EXTRA_EMERGENCY_PHONE, emergencyPhone)
                putExtra(EXTRA_DEVICE_NAME, deviceName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private data class DeviceConfig(
        val mac: String,
        val password: String,
        val clickTypeToOpen: String,
        val buttonAction: String,
        val emergencyPhone: String?,
        val deviceName: String
    )

    private data class DeviceState(
        val config: DeviceConfig,
        val support: DMokoSupport,
        var isConnected: Boolean = false,
        var isInitialized: Boolean = false,
        var reconnectAttempts: Int = 0
    )

    private val deviceStates = mutableMapOf<String, DeviceState>()
    private val reconnectHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val pendingReconnects = mutableMapOf<String, Runnable>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        createAlertNotificationChannel()
        EventBus.getDefault().register(this)
        android.util.Log.d("MkButtonBgService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("MkButtonBgService", "onStartCommand: action=${intent?.action}")

        when (intent?.action) {
            ACTION_START_SERVICE -> {
                val mac = intent.getStringExtra(EXTRA_MAC) ?: run {
                    android.util.Log.e("MkButtonBgService", "No MAC address provided")
                    if (deviceStates.isEmpty()) stopSelf()
                    return START_STICKY
                }

                if (deviceStates.isEmpty()) {
                    startForeground(NOTIFICATION_ID, createNotification("Conectando..."))
                }

                if (deviceStates.containsKey(mac)) {
                    android.util.Log.d("MkButtonBgService", "Device already tracked: $mac")
                    return START_STICKY
                }

                val config = DeviceConfig(
                    mac = mac,
                    password = intent.getStringExtra(EXTRA_PASSWORD) ?: "Moko4321",
                    clickTypeToOpen = intent.getStringExtra(EXTRA_CLICK_TYPE) ?: "single",
                    buttonAction = intent.getStringExtra(EXTRA_BUTTON_ACTION) ?: "open_app",
                    emergencyPhone = intent.getStringExtra(EXTRA_EMERGENCY_PHONE),
                    deviceName = intent.getStringExtra(EXTRA_DEVICE_NAME) ?: "Dispositivo MK"
                )

                val support = DMokoSupport(applicationContext, mac)
                support.setPassword(config.password)
                deviceStates[mac] = DeviceState(config = config, support = support)
                support.connDevice(mac)

                android.util.Log.d("MkButtonBgService", "Device added: $mac (${config.deviceName}). Total: ${deviceStates.size}")
            }
            ACTION_STOP_SERVICE -> {
                android.util.Log.d("MkButtonBgService", "Stopping service")
                disconnectAndStop()
            }
            ACTION_REMOVE_DEVICE -> {
                val mac = intent.getStringExtra(EXTRA_MAC) ?: return START_STICKY
                android.util.Log.d("MkButtonBgService", "Removing device: $mac")
                pendingReconnects.remove(mac)?.let { reconnectHandler.removeCallbacks(it) }
                deviceStates.remove(mac)?.support?.disConnectBle()
                android.util.Log.d("MkButtonBgService", "Device removed. Remaining: ${deviceStates.size}")
                if (deviceStates.isEmpty()) disconnectAndStop()
            }
            ACTION_EXECUTE_EMERGENCY -> {
                val mac = intent.getStringExtra(EXTRA_MAC) ?: return START_STICKY
                val buttonAction = intent.getStringExtra(EXTRA_BUTTON_ACTION) ?: return START_STICKY
                val emergencyPhone = intent.getStringExtra(EXTRA_EMERGENCY_PHONE)
                val deviceName = intent.getStringExtra(EXTRA_DEVICE_NAME) ?: "Dispositivo"
                if (deviceStates.isEmpty()) {
                    startForeground(NOTIFICATION_ID, createNotification("Activo"))
                }
                val config = DeviceConfig(
                    mac = mac,
                    password = "",
                    clickTypeToOpen = "single",
                    buttonAction = buttonAction,
                    emergencyPhone = emergencyPhone,
                    deviceName = deviceName
                )
                executeButtonAction(config)
            }
            else -> {
                startForeground(NOTIFICATION_ID, createNotification("Activo"))
                if (deviceStates.isEmpty()) {
                    restoreDevicesFromPrefs()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        EventBus.getDefault().unregister(this)
        reconnectHandler.removeCallbacksAndMessages(null)
        pendingReconnects.clear()
        deviceStates.values.forEach { it.support.disConnectBle() }
        deviceStates.clear()
        android.util.Log.d("MkButtonBgService", "Service destroyed")
    }

    private fun restoreDevicesFromPrefs() {
        val prefs = applicationContext.getSharedPreferences("mk_button_config", Context.MODE_PRIVATE)
        val allKeys = prefs.all.keys
        val macs = allKeys.mapNotNull { key ->
            if (key.endsWith("_clickType")) key.removeSuffix("_clickType") else null
        }
        for (mac in macs) {
            val clickType = prefs.getString("${mac}_clickType", null) ?: continue
            if (clickType == "disabled") continue
            val buttonAction = prefs.getString("${mac}_buttonAction", "open_app") ?: continue
            val emergencyPhone = prefs.getString("${mac}_emergencyPhone", "")?.takeIf { it.isNotEmpty() }
            val deviceName = prefs.getString("${mac}_deviceName", "Dispositivo MK") ?: "Dispositivo MK"
            val password = prefs.getString("${mac}_password", "123456") ?: "123456"
            android.util.Log.d("MkButtonBgService", "Restoring device from prefs: $mac ($deviceName)")
            val config = DeviceConfig(mac, password, clickType, buttonAction, emergencyPhone, deviceName)
            val support = DMokoSupport(applicationContext, mac)
            support.setPassword(config.password)
            deviceStates[mac] = DeviceState(config = config, support = support)
            support.connDevice(mac)
        }
        if (deviceStates.isEmpty()) {
            android.util.Log.d("MkButtonBgService", "No devices to restore, stopping service")
            stopSelf()
        }
    }

    private fun disconnectAndStop() {
        deviceStates.values.forEach { it.support.disConnectBle() }
        deviceStates.clear()
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
        val mac = event.macAddress ?: return
        val state = deviceStates[mac] ?: return

        when (event.action) {
            MokoConstants.ACTION_DISCOVER_SUCCESS -> {
                pendingReconnects.remove(mac)?.let { reconnectHandler.removeCallbacks(it) }
                cancelDeviceLostNotification(mac)
                state.isConnected = true
                state.reconnectAttempts = 0
                android.util.Log.d("MkButtonBgService", "Connected: ${state.config.deviceName} ($mac)")

                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                handler.postDelayed({
                    if (!deviceStates.containsKey(mac)) return@postDelayed
                    state.support.enableClickEventNotify()
                    state.support.enableSingleTriggerNotify()
                    state.support.enableDoubleTriggerNotify()
                    state.support.enableLongTriggerNotify()
                    android.util.Log.d("MkButtonBgService", "Notifications enabled: ${state.config.deviceName}")

                    handler.postDelayed({
                        if (!deviceStates.containsKey(mac)) return@postDelayed
                        state.isInitialized = true
                        android.util.Log.d("MkButtonBgService", "Device ready: ${state.config.deviceName}")
                        handler.postDelayed({
                            if (deviceStates.containsKey(mac) && state.isConnected) {
                                state.support.startKeepAlive()
                            }
                        }, 15000)
                    }, 500)
                }, 3000)

                val connectedCount = deviceStates.count { it.value.isConnected }
                updateNotification("$connectedCount dispositivo(s) conectado(s)")
            }
            MokoConstants.ACTION_DISCONNECTED -> {
                val wasInitialized = state.isInitialized
                state.isConnected = false
                state.isInitialized = false
                android.util.Log.d("MkButtonBgService", "Disconnected: ${state.config.deviceName} ($mac)")

                if (wasInitialized) {
                    showDeviceLostNotification(state.config)
                }

                val connectedCount = deviceStates.count { it.value.isConnected }
                updateNotification(if (connectedCount > 0) "$connectedCount dispositivo(s) conectado(s)" else "Reconectando...")

                if (state.reconnectAttempts < 10) {
                    state.reconnectAttempts++
                    val delay = minOf(5000L * (1L shl (state.reconnectAttempts - 1)), 300_000L)
                    android.util.Log.d("MkButtonBgService", "Reconnecting ${state.config.deviceName} in ${delay}ms (attempt ${state.reconnectAttempts})")
                    pendingReconnects.remove(mac)?.let { reconnectHandler.removeCallbacks(it) }
                    val runnable = Runnable {
                        pendingReconnects.remove(mac)
                        if (deviceStates.containsKey(mac) && !state.isConnected) {
                            state.support.connDevice(mac)
                        }
                    }
                    pendingReconnects[mac] = runnable
                    reconnectHandler.postDelayed(runnable, delay)
                } else {
                    android.util.Log.w("MkButtonBgService", "Max reconnect attempts for ${state.config.deviceName}")
                }
            }
        }
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onOrderTaskResponseEvent(event: OrderTaskResponseEvent) {
        if (event.action != MokoConstants.ACTION_CURRENT_DATA) return
        val mac = event.macAddress ?: return
        val response = event.response ?: return
        val value = response.responseValue ?: return

        when (response.orderCHAR as? OrderCHAR) {
            OrderCHAR.CHAR_CLICK_EVENT -> {
                if (value.size < 5) return
                val clickType = when (value[4].toInt() and 0xFF) {
                    0x01 -> "single"
                    0x02 -> "double"
                    0x03 -> "long"
                    else -> "single"
                }
                val state = deviceStates[mac]
                if (state != null) {
                    if (!state.isInitialized) {
                        android.util.Log.w("MkButtonBgService", "Ignoring click from ${state.config.deviceName} - not initialized yet")
                        return
                    }
                    android.util.Log.d("MkButtonBgService", "Click from ${state.config.deviceName} ($mac): $clickType")
                    if (clickType == state.config.clickTypeToOpen && state.config.clickTypeToOpen != "disabled") {
                        executeButtonAction(state.config)
                    }
                } else {
                    val prefs = applicationContext.getSharedPreferences("mk_button_config", Context.MODE_PRIVATE)
                    val storedClickType = prefs.getString("${mac}_clickType", null) ?: return
                    if (storedClickType == "disabled" || clickType != storedClickType) return
                    val buttonAction = prefs.getString("${mac}_buttonAction", "open_app") ?: return
                    val emergencyPhone = prefs.getString("${mac}_emergencyPhone", "")?.takeIf { it.isNotEmpty() }
                    val deviceName = prefs.getString("${mac}_deviceName", "Dispositivo MK") ?: "Dispositivo MK"
                    android.util.Log.d("MkButtonBgService", "Click (SharedPrefs fallback) from $mac: $clickType → $buttonAction")
                    executeButtonAction(DeviceConfig(mac, "", storedClickType, buttonAction, emergencyPhone, deviceName))
                }
            }
            else -> {}
        }
    }

    private fun executeButtonAction(config: DeviceConfig) {
        android.util.Log.d("MkButtonBgService", "Executing ${config.buttonAction} for ${config.deviceName}")
        when (config.buttonAction) {
            "call" -> attemptImmediateCall(config)
            "sms" -> sendEmergencySMS(config)
            "sms_and_call" -> {
                attemptImmediateCall(config)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    sendEmergencySMS(config)
                }, 500)
            }
            else -> openApp()
        }
    }

    private fun attemptImmediateCall(config: DeviceConfig) {
        if (config.emergencyPhone.isNullOrEmpty()) return
        android.util.Log.d("MkButtonBgService", "Calling ${config.emergencyPhone} for ${config.deviceName}")
        try {
            val callIntent = Intent(Intent.ACTION_CALL).apply {
                data = android.net.Uri.parse("tel:${config.emergencyPhone}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(callIntent)
        } catch (e: Exception) {
            android.util.Log.i("MkButtonBgService", "Call blocked by system: ${e.message}")
        }
    }

    private fun sendEmergencySMS(config: DeviceConfig) {
        if (config.emergencyPhone.isNullOrEmpty()) {
            android.util.Log.w("MkButtonBgService", "No emergency phone for ${config.deviceName}")
            return
        }
        android.util.Log.d("MkButtonBgService", "Sending SMS for ${config.deviceName} to ${config.emergencyPhone}")
        try {
            val location = getLocationFromSharedPreferences() ?: getCurrentLocation()
            val batteryPercent = applicationContext
                .getSharedPreferences("mk_button_config", Context.MODE_PRIVATE)
                .getInt("${config.mac}_batteryPercent", -1)
            val geoValue = if (location != null) {
                val coords = "${location.latitude}, ${location.longitude}"
                android.util.Base64.encodeToString(coords.toByteArray(Charsets.UTF_8), android.util.Base64.NO_WRAP)
            } else {
                "LocationNotAvailable"
            }
            val batteryValue = if (batteryPercent >= 0) batteryPercent.toString() else "unknown"
            val message = "ALERTAMOVIL GEO=$geoValue ORIGIN=MK-BUTTON BATTERY=$batteryValue"

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            if (parts.size == 1) {
                smsManager.sendTextMessage(config.emergencyPhone, null, message, null, null)
            } else {
                smsManager.sendMultipartTextMessage(config.emergencyPhone, null, parts, null, null)
            }
            android.util.Log.d("MkButtonBgService", "SMS sent for ${config.deviceName}")
            triggerImmediateVibration()
            showSMSSentNotification(config, location)
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "SMS failed for ${config.deviceName}", e)
            showSMSErrorNotification(config, e.message ?: "Error desconocido")
        }
    }

    private fun getLocationFromSharedPreferences(): Location? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val geoString = prefs.getString("flutter.geo", null) ?: return null
            val parts = geoString.split(",").map { it.trim() }
            if (parts.size != 2) return null
            val lat = parts[0].toDoubleOrNull() ?: return null
            val lon = parts[1].toDoubleOrNull() ?: return null
            Location("SharedPreferences").apply {
                latitude = lat
                longitude = lon
                time = System.currentTimeMillis()
            }
        } catch (e: Exception) { null }
    }

    private fun getCurrentLocation(): Location? {
        return try {
            if (ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            var best: Location? = null
            for (p in providers) {
                try {
                    if (lm.isProviderEnabled(p)) {
                        val loc = lm.getLastKnownLocation(p)
                        if (loc != null && (best == null || loc.time > best.time)) best = loc
                    }
                } catch (_: Exception) {}
            }
            best
        } catch (e: Exception) { null }
    }

    private fun triggerImmediateVibration() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), intArrayOf(0, 255, 0, 255, 0, 255), -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
            }
        } catch (_: Exception) {}
    }

    private fun showSMSSentNotification(config: DeviceConfig, location: Location?) {
        val locationInfo = if (location != null) "📍 Lat ${location.latitude}, Lon ${location.longitude}" else "⚠️ Sin ubicación GPS"
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent ?: Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload_done)
            .setContentTitle("✅ SMS de Emergencia Enviado")
            .setContentText("${config.deviceName} → ${config.emergencyPhone}")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("📱 Destinatario: ${config.emergencyPhone}\n$locationInfo\n\nDispositivo: ${config.deviceName}"))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setColor(0xFF00AA00.toInt())
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(false)
            .setContentIntent(pendingIntent)
            .build()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            val connectedCount = deviceStates.count { it.value.isConnected }
            updateNotification("$connectedCount dispositivo(s) conectado(s)")
        }, 10000)
    }

    private fun showSMSErrorNotification(config: DeviceConfig, error: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent ?: Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("❌ Error SMS de Emergencia")
            .setContentText("${config.deviceName}: $error")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setColor(0xFFFF0000.toInt())
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .build()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            val connectedCount = deviceStates.count { it.value.isConnected }
            updateNotification("$connectedCount dispositivo(s) conectado(s)")
        }, 10000)
    }

    private fun openApp() {
        try {
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("opened_from_button", true)
            }
            val pendingIntent = PendingIntent.getActivity(this, 1001, activityIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("🔘 BOTÓN PRESIONADO")
                .setContentText("Toca para abrir Amaia")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setOngoing(false)
                .setFullScreenIntent(pendingIntent, true)
                .build()
            getSystemService(NotificationManager::class.java).notify(2001, notification)
        } catch (e: Exception) {
            android.util.Log.e("MkButtonBgService", "Failed to open app", e)
        }
    }

    private fun showDeviceLostNotification(config: DeviceConfig) {
        val notifId = 4000 + config.mac.hashCode() and 0xFFFF
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, notifId, launchIntent ?: Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("📡 Dispositivo fuera de rango")
            .setContentText("${config.deviceName} se desconectó")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("${config.deviceName} salió del rango Bluetooth.\nReconectando automáticamente..."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOngoing(false)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setColor(0xFFFF6600.toInt())
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .build()
        getSystemService(NotificationManager::class.java).notify(notifId, notification)
        android.util.Log.d("MkButtonBgService", "Device lost notification shown for ${config.deviceName}")
    }

    private fun cancelDeviceLostNotification(mac: String) {
        val notifId = 4000 + mac.hashCode() and 0xFFFF
        getSystemService(NotificationManager::class.java).cancel(notifId)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "MK Button Service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Mantiene la conexión BLE activa"
                enableVibration(false)
                setSound(null, null)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createAlertNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val alarmSound = android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
            val audioAttributes = android.media.AudioAttributes.Builder()
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                .build()
            val channel = NotificationChannel(ALERT_CHANNEL_ID, "MK Button Emergencias", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Alertas de emergencia"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.RED
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
                setSound(alarmSound, audioAttributes)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent ?: Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MK Button Activo")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, createNotification(contentText))
    }
}
