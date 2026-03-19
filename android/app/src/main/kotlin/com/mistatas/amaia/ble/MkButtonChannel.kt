package com.mistatas.amaia.ble

import android.app.NotificationManager
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.moko.ble.lib.MokoConstants
import com.moko.ble.lib.event.ConnectStatusEvent
import com.moko.ble.lib.event.OrderTaskResponseEvent
import com.moko.support.d.DMokoSupport
import com.moko.support.d.MokoBleScanner
import com.moko.support.d.OrderTaskAssembler
import com.moko.support.d.callback.MokoScanDeviceCallback
import com.moko.support.d.entity.DeviceInfo
import com.moko.support.d.entity.OrderCHAR
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

/**
 * Bridges the Flutter MethodChannel with the MKButton BLE SDK.
 */
class MkButtonChannel(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.example.app/mk_button"
    }

    private var scanner: MokoBleScanner? = null
    private var isRegistered = false
    private var isDeviceConnected = false
    private var pendingPassword: String = "123456"

    // ---------------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------------

    fun register() {
        if (!isRegistered) {
            EventBus.getDefault().register(this)
            isRegistered = true
        }
    }

    fun unregister() {
        if (isRegistered) {
            EventBus.getDefault().unregister(this)
            isRegistered = false
        }
        scanner?.stopScanDevice()
    }

    // ---------------------------------------------------------------------------
    // MethodCallHandler
    // ---------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan"                     -> handleStartScan(result)
            "stopScan"                      -> handleStopScan(result)
            "connect"                       -> handleConnect(call, result)
            "disconnect"                    -> handleDisconnect(result)
            "readDeviceInfo"                -> handleReadDeviceInfo(result)
            "readBattery"                   -> handleReadBattery(result)
            "setAdvInterval"                -> handleSetAdvInterval(call, result)
            "setTxPower"                    -> handleSetTxPower(call, result)
            "setDeviceName"                 -> handleSetDeviceName(call, result)
            "changePassword"                -> handleChangePassword(call, result)
            "enableButtonNotify"            -> handleEnableButtonNotify(call, result)
            "resetDevice"                   -> handleResetDevice(result)
            "startBackgroundService"        -> handleStartBackgroundService(call, result)
            "stopBackgroundService"         -> handleStopBackgroundService(result)
            "checkPermissions"              -> handleCheckPermissions(result)
            "requestBatteryOptimization"    -> handleRequestBatteryOptimization(result)
            "requestNotificationPermission" -> handleRequestNotificationPermission(result)
            "requestOverlayPermission"      -> handleRequestOverlayPermission(result)
            else                            -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------------------
    // Scan
    // ---------------------------------------------------------------------------

    private fun handleStartScan(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_DISABLED", "Bluetooth is not enabled", null)
            return
        }
        scanner = MokoBleScanner(context).also { s ->
            s.startScanDevice(object : MokoScanDeviceCallback {
                override fun onStartScan() {}

                override fun onScanDevice(device: DeviceInfo) {
                    val name = device.name ?: ""
                    val mac = device.mac ?: ""
                    
                    // Log TODOS los dispositivos detectados para debug
                    android.util.Log.d("MkButtonSDK", "BLE device found: name='$name' mac=$mac rssi=${device.rssi}")
                    
                    // FILTRAR: Solo mostrar dispositivos cuyo nombre empiece con "MK"
                    if (!name.startsWith("MK", ignoreCase = true)) {
                        android.util.Log.d("MkButtonSDK", "Device filtered out (name doesn't start with 'MK'): $name")
                        return
                    }
                    
                    android.util.Log.d("MkButtonSDK", "Sending MK device to Flutter: $name ($mac)")
                    val map = mapOf(
                        "mac"  to mac,
                        "name" to name,
                        "rssi" to device.rssi,
                    )
                    channel.invokeMethod("onDeviceScanned", map)
                }

                override fun onStopScan() {}
            })
        }
        result.success(null)
    }

    private fun handleStopScan(result: MethodChannel.Result) {
        scanner?.stopScanDevice()
        scanner = null
        result.success(null)
    }

    // ---------------------------------------------------------------------------
    // Connection
    // ---------------------------------------------------------------------------

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARG", "mac address is required", null)
            return
        }
        pendingPassword = call.argument<String>("password") ?: "123456"

        android.util.Log.d("MkButtonSDK", "Password received from Flutter: '$pendingPassword' length=${pendingPassword.length}")
        
        // Registrar la contraseña en el SDK ANTES de conectar
        DMokoSupport.getInstance().setPassword(pendingPassword)
        
        DMokoSupport.getInstance().connDevice(mac)
        result.success(null)
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        DMokoSupport.getInstance().disConnectBle()
        result.success(null)
    }

    // ---------------------------------------------------------------------------
    // Read device info
    // SDK real no tiene: getAdvInterval, getRadioTxPower, getLockState
    // Usamos lo que sí existe
    // ---------------------------------------------------------------------------

    private fun handleReadDeviceInfo(result: MethodChannel.Result) {
        // IMPORTANTE: El dispositivo MK Button NO tolera comandos adicionales después
        // de la inicialización. Enviar comandos de lectura (batería, nombre, etc.) causa
        // ORDER TIMEOUT y desconexión inmediata.
        // 
        // Si necesitas esta información, debes implementar una estrategia diferente:
        // 1. Obtener el nombre del dispositivo durante el escaneo BLE (antes de conectar)
        // 2. La batería puede leerse solo si es absolutamente necesario y con cuidado
        // 
        // Por ahora, este método retorna success sin hacer nada para mantener la compatibilidad
        // con el código existente.
        android.util.Log.w("MkButton", "readDeviceInfo called but disabled - MK Button doesn't support commands after init")
        result.success(null)
    }

    private fun handleReadBattery(result: MethodChannel.Result) {
        // ADVERTENCIA: Leer batería después de la inicialización puede causar desconexión
        // Este comando solo debe usarse cuando el usuario lo solicita manualmente
        android.util.Log.w("MkButton", "readBattery requested - may cause disconnection!")
        
        try {
            // Comando 0x62 = leer batería
            DMokoSupport.getInstance().sendOrder(
                OrderTaskAssembler.getBatteryPercent()
            )
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to read battery", e)
            result.error("BATTERY_READ_FAILED", e.message, null)
        }
    }

    // ---------------------------------------------------------------------------
    // Configuration commands
    // ---------------------------------------------------------------------------

    // El SDK real no expone setAdvInterval ni setRadioTxPower directamente.
    // Usamos setSlotParams para el intervalo de publicidad (slot 0).
    private fun handleSetAdvInterval(call: MethodCall, result: MethodChannel.Result) {
        val intervalMs = call.argument<Int>("intervalMs") ?: run {
            result.error("INVALID_ARG", "intervalMs is required", null)
            return
        }
        // setSlotParams(slot, enable, rssi, interval, txPower)
        // Mantenemos slot=0, enable=1, rssi=-100 (sin filtro), txPower=0
        val clamped = intervalMs.coerceIn(20, 10000)
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setSlotParams(0, 1, -100, clamped, 0)
        )
        result.success(null)
    }

    private fun handleSetTxPower(call: MethodCall, result: MethodChannel.Result) {
        val txPower = call.argument<Int>("txPower") ?: run {
            result.error("INVALID_ARG", "txPower is required", null)
            return
        }
        // setSlotParams(slot, enable, rssi, interval, txPower)
        // interval=1000ms como valor neutro, rssi=-100 (sin filtro)
        val clampedTx = txPower.coerceIn(-100, 0)
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setSlotParams(0, 1, -100, 1000, clampedTx)
        )
        result.success(null)
    }

    private fun handleSetDeviceName(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("INVALID_ARG", "name is required", null)
            return
        }
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setDeviceName(name)
        )
        result.success(null)
    }

    // El SDK usa setPassword(newPassword) y setNewPassword(newPassword)
    // Para cambiar: primero verificar con setPassword (contraseña actual), luego setNewPassword
    private fun handleChangePassword(call: MethodCall, result: MethodChannel.Result) {
        val oldPwd = call.argument<String>("oldPassword") ?: ""
        val newPwd = call.argument<String>("newPassword") ?: run {
            result.error("INVALID_ARG", "newPassword is required", null)
            return
        }
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setPassword(oldPwd),
            OrderTaskAssembler.setNewPassword(newPwd),
        )
        result.success(null)
    }

    // El SDK expone notificaciones separadas por tipo de pulsación
    private fun handleEnableButtonNotify(call: MethodCall, result: MethodChannel.Result) {
        val enable = call.argument<Boolean>("enable") ?: true
        val support = DMokoSupport.getInstance()
        if (enable) {
            support.enableSingleTriggerNotify()
            support.enableDoubleTriggerNotify()
            support.enableLongTriggerNotify()
            support.enableClickEventNotify()
        } else {
            support.disableSingleTriggerNotify()
            support.disableDoubleTriggerNotify()
            support.disableLongTriggerNotify()
            support.disableClickEventNotify()
        }
        result.success(null)
    }

    private fun handleResetDevice(result: MethodChannel.Result) {
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setDefault()
        )
        result.success(null)
    }

    // ---------------------------------------------------------------------------
    // Background Service
    // ---------------------------------------------------------------------------

    private fun handleStartBackgroundService(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARG", "mac is required", null)
            return
        }
        val password = call.argument<String>("password") ?: "Moko4321"
        val clickType = call.argument<String>("clickType") ?: "single"
        val buttonAction = call.argument<String>("buttonAction") ?: "open_app"
        val emergencyPhone = call.argument<String>("emergencyPhone")

        try {
            MkButtonBackgroundService.startService(
                context = context,
                mac = mac,
                password = password,
                clickType = clickType,
                buttonAction = buttonAction,
                emergencyPhone = emergencyPhone
            )
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to start background service", e)
            result.error("SERVICE_START_FAILED", e.message, null)
        }
    }

    private fun handleStopBackgroundService(result: MethodChannel.Result) {
        try {
            MkButtonBackgroundService.stopService(context)
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to stop background service", e)
            result.error("SERVICE_STOP_FAILED", e.message, null)
        }
    }

    // ---------------------------------------------------------------------------
    // Permissions Management
    // ---------------------------------------------------------------------------

    private fun handleCheckPermissions(result: MethodChannel.Result) {
        val permissions = mutableMapOf<String, Any>()
        
        // Check battery optimization
        permissions["batteryOptimizationDisabled"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true // No battery optimization on older versions
        }
        
        // Check notification permission
        permissions["notificationPermission"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        } else {
            true // Notifications always enabled on older versions
        }
        
        // Check overlay permission
        permissions["overlayPermission"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
        
        result.success(permissions)
    }

    private fun handleRequestBatteryOptimization(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to request battery optimization", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun handleRequestNotificationPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // For Android 13+, need to request permission at runtime
                // This will be handled by Flutter's permission_handler or similar
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            } else {
                // For older versions, open app settings
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to request notification permission", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
    
    private fun handleRequestOverlayPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to request overlay permission", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    // ---------------------------------------------------------------------------
    // EventBus — Connection status
    // ---------------------------------------------------------------------------

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onConnectStatusEvent(event: ConnectStatusEvent) {
        val connected = event.action == MokoConstants.ACTION_DISCOVER_SUCCESS
        isDeviceConnected = connected
        
        if (connected) {
            android.util.Log.d("MkButton", "Device connected, checking password requirement...")
            
            // El SDK ahora maneja automáticamente la secuencia de autenticación e inicialización
            // Solo necesitamos enviar el comando inicial para verificar si se requiere contraseña
            DMokoSupport.getInstance().writePasswordDirectly(
                byteArrayOf(0xEA.toByte(), 0x00, 0x23, 0x00)
            )
            
            // Enviar contraseña después de un delay (permite que el dispositivo responda)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                android.util.Log.d("MkButton", "Sending password: '$pendingPassword'")
                val passwordBytes = pendingPassword.toByteArray()
                val data = ByteArray(4 + passwordBytes.size)
                data[0] = 0xEA.toByte()
                data[1] = 0x01.toByte()
                data[2] = 0x55.toByte()
                data[3] = passwordBytes.size.toByte()
                passwordBytes.copyInto(data, 4)
                DMokoSupport.getInstance().writePasswordDirectly(data)
                
                // La secuencia de inicialización completa ahora se maneja automáticamente
                // en MokoBleConfig.enablePasswordNotify() cuando recibe la respuesta EB 01 55
            }, 2500)
        }
        
        channel.invokeMethod("onConnectionStatus", mapOf("connected" to connected))
    }

    // ---------------------------------------------------------------------------
    // EventBus — Task responses & notify data
    // ---------------------------------------------------------------------------

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onOrderTaskResponseEvent(event: OrderTaskResponseEvent) {
        when (event.action) {
            com.moko.ble.lib.MokoConstants.ACTION_ORDER_RESULT  -> handleOrderResult(event)
            com.moko.ble.lib.MokoConstants.ACTION_CURRENT_DATA  -> handleNotifyData(event)
        }
    }

    private fun handleOrderResult(event: OrderTaskResponseEvent) {
        val response = event.response ?: return
        val value    = response.responseValue ?: return
        val map      = mutableMapOf<String, Any?>()

        android.util.Log.d("MkButton", "handleOrderResult: orderCHAR=${response.orderCHAR}, value=${value.joinToString("") { "%02X".format(it) }}")

        when (response.orderCHAR as? OrderCHAR) {
            OrderCHAR.CHAR_PARAMS -> {
                // Formato de respuesta: EB 00 [KEY] [LEN] [DATA...]
                // Para batería (0x62): EB 00 62 01 XX donde XX es el porcentaje
                if (value.size >= 5 && (value[0].toInt() and 0xFF) == 0xEB && 
                    (value[1].toInt() and 0xFF) == 0x00 && (value[2].toInt() and 0xFF) == 0x62) {
                    // Batería está en el byte 4
                    map["batteryPercent"] = value[4].toInt() and 0xFF
                    android.util.Log.d("MkButton", "Battery parsed: ${value[4].toInt() and 0xFF}%")
                }
            }
            OrderCHAR.CHAR_MODEL_NUMBER -> {
                map["deviceName"] = String(value)
            }
            OrderCHAR.CHAR_FIRMWARE_REVISION -> {
                map["firmwareVersion"] = String(value)
            }
            OrderCHAR.CHAR_HARDWARE_REVISION -> {
                map["hardwareVersion"] = String(value)
            }
            OrderCHAR.CHAR_PASSWORD -> {
                // getVerifyPasswordEnable — 0x00 = desactivada, 0x01 = activada
                if (value.isNotEmpty()) {
                    map["isPasswordEnabled"] = value[0].toInt() != 0
                }
            }
            else -> return
        }

        if (map.isNotEmpty()) {
            channel.invokeMethod("onTaskResult", map)
        }
    }

    private fun handleNotifyData(event: OrderTaskResponseEvent) {
        val response = event.response ?: return
        val value    = response.responseValue ?: return

        val pressType = when (response.orderCHAR as? OrderCHAR) {
            OrderCHAR.CHAR_SINGLE_TRIGGER -> "single"
            OrderCHAR.CHAR_DOUBLE_TRIGGER -> "double"
            OrderCHAR.CHAR_LONG_TRIGGER   -> "long"
            OrderCHAR.CHAR_CLICK_EVENT    -> parseCHARClickEvent(value)
            else -> return
        }

        channel.invokeMethod("onButtonPress", mapOf("type" to pressType))
    }

    // CHAR_CLICK_EVENT formato: EB 02 06 01 XX donde XX es el tipo de click
    // XX = 01 (single), 02 (double), 03 (long press)
    private fun parseCHARClickEvent(value: ByteArray): String {
        if (value.size < 5) return "single"
        // El tipo de click está en el último byte (posición 4)
        return when (value[4].toInt() and 0xFF) {
            0x01 -> "single"
            0x02 -> "double"
            0x03 -> "long"
            else -> "single"
        }
    }

}