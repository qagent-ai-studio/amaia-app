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
    private var foregroundMac: String? = null
    private var connectedAt: Long = 0
    private var expectingConnect = false
    private var connectRetries = 0
    private val connectionTimeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private data class ForegroundActionConfig(
        val clickType: String,
        val buttonAction: String,
        val emergencyPhone: String?,
        val deviceName: String
    )
    private val deviceActionConfigs = mutableMapOf<String, ForegroundActionConfig>()

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
            "prepareConnect"                -> handlePrepareConnect(call, result)
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
            "startBackgroundService"            -> handleStartBackgroundService(call, result)
            "stopBackgroundService"             -> handleStopBackgroundService(result)
            "removeDeviceFromBackgroundService" -> handleRemoveDeviceFromBackgroundService(call, result)
            "executeEmergencyAction"            -> handleExecuteEmergencyAction(call, result)
            "triggerBuzzer"                 -> handleTriggerBuzzer(call, result)
            "stopBuzzer"                    -> handleStopBuzzer(result)
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

                    if (!name.startsWith("MK", ignoreCase = true)) return

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

    private fun handlePrepareConnect(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run { result.success(null); return }
        foregroundMac = mac
        expectingConnect = true
        connectRetries = 0
        connectionTimeoutHandler.removeCallbacksAndMessages(null)
        connectionTimeoutHandler.postDelayed({
            if (expectingConnect) {
                expectingConnect = false
                isDeviceConnected = false
                android.util.Log.e("MkButton", "Connection timeout (20s) for $mac — reporting failure to Flutter")
                channel.invokeMethod("onConnectionStatus", mapOf("connected" to false))
            }
        }, 20_000L)
        android.util.Log.d("MkButton", "prepareConnect($mac) — expectingConnect=true")
        result.success(null)
    }

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARG", "mac address is required", null)
            return
        }
        pendingPassword = call.argument<String>("password") ?: "123456"
        if (foregroundMac != mac) {
            foregroundMac = mac
        }
        DMokoSupport.getInstance().setPassword(pendingPassword)
        android.util.Log.d("MkButton", "handleConnect($mac) — calling forceConnDevice (expectingConnect=$expectingConnect retries=$connectRetries)")
        DMokoSupport.getInstance().forceConnDevice(mac)
        result.success(null)
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        foregroundMac = null
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
        try {
            DMokoSupport.getInstance().sendOrder(
                OrderTaskAssembler.getBattery()
            )
            result.success(null)
        } catch (e: Exception) {
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

    private fun handleTriggerBuzzer(call: MethodCall, result: MethodChannel.Result) {
        val durationMs = call.argument<Int>("durationMs") ?: 3000
        val intervalMs = call.argument<Int>("intervalMs") ?: 0
        val clamped = durationMs.coerceIn(1, 6000)
        val clampedInterval = intervalMs.coerceIn(0, 100)
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setRemoteBuzzerNotifyAlarmParams(clamped, clampedInterval)
        )
        result.success(null)
    }

    private fun handleStopBuzzer(result: MethodChannel.Result) {
        DMokoSupport.getInstance().sendOrder(
            OrderTaskAssembler.setDismissAlarm()
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
        val deviceType = call.argument<String>("deviceType") ?: "button"
        val deviceName = call.argument<String>("deviceName") ?: "Dispositivo MK"

        deviceActionConfigs[mac] = ForegroundActionConfig(
            clickType = clickType,
            buttonAction = buttonAction,
            emergencyPhone = emergencyPhone,
            deviceName = deviceName
        )
        context.getSharedPreferences("mk_button_config", Context.MODE_PRIVATE).edit()
            .putString("${mac}_clickType", clickType)
            .putString("${mac}_buttonAction", buttonAction)
            .putString("${mac}_emergencyPhone", emergencyPhone ?: "")
            .putString("${mac}_deviceName", deviceName)
            .putString("${mac}_password", password)
            .apply()
        try {
            MkButtonBackgroundService.startService(
                context = context,
                mac = mac,
                password = password,
                clickType = clickType,
                buttonAction = buttonAction,
                emergencyPhone = emergencyPhone,
                deviceType = deviceType,
                deviceName = deviceName
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

    private fun handleExecuteEmergencyAction(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARG", "mac is required", null)
            return
        }
        val buttonAction = call.argument<String>("buttonAction") ?: run {
            result.error("INVALID_ARG", "buttonAction is required", null)
            return
        }
        val emergencyPhone = call.argument<String>("emergencyPhone")
        val deviceName = call.argument<String>("deviceName") ?: "Dispositivo MK"
        MkButtonBackgroundService.executeEmergencyAction(context, mac, buttonAction, emergencyPhone, deviceName)
        result.success(null)
    }

    private fun handleRemoveDeviceFromBackgroundService(call: MethodCall, result: MethodChannel.Result) {
        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARG", "mac is required", null)
            return
        }
        try {
            MkButtonBackgroundService.removeDevice(context, mac)
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("MkButton", "Failed to remove device from background service", e)
            result.error("SERVICE_REMOVE_FAILED", e.message, null)
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
        val eventMac = event.macAddress
        if (eventMac != null && eventMac != foregroundMac) return

        val connected = event.action == MokoConstants.ACTION_DISCOVER_SUCCESS

        if (connected) {
            connectionTimeoutHandler.removeCallbacksAndMessages(null)
            expectingConnect = false
            isDeviceConnected = true
            connectedAt = System.currentTimeMillis()
            val connectedMac = eventMac ?: foregroundMac
            if (connectedMac != null && !deviceActionConfigs.containsKey(connectedMac)) {
                val prefs = context.getSharedPreferences("mk_button_config", Context.MODE_PRIVATE)
                val clickType = prefs.getString("${connectedMac}_clickType", null)
                val buttonAction = prefs.getString("${connectedMac}_buttonAction", null)
                if (clickType != null && buttonAction != null) {
                    val ep = prefs.getString("${connectedMac}_emergencyPhone", "")?.takeIf { it.isNotEmpty() }
                    val dn = prefs.getString("${connectedMac}_deviceName", "Dispositivo MK") ?: "Dispositivo MK"
                    deviceActionConfigs[connectedMac] = ForegroundActionConfig(clickType, buttonAction, ep, dn)
                    android.util.Log.d("MkButton", "Config restored from SharedPrefs for $connectedMac: clickType=$clickType buttonAction=$buttonAction")
                } else {
                    android.util.Log.w("MkButton", "No SharedPrefs config found for $connectedMac")
                }
            }
            android.util.Log.d("MkButton", "Device connected, checking password requirement...")
            DMokoSupport.getInstance().writePasswordDirectly(
                byteArrayOf(0xEA.toByte(), 0x00, 0x23, 0x00)
            )
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.postDelayed({
                android.util.Log.d("MkButton", "Sending password: '$pendingPassword'")
                val passwordBytes = pendingPassword.toByteArray()
                val data = ByteArray(4 + passwordBytes.size)
                data[0] = 0xEA.toByte()
                data[1] = 0x01.toByte()
                data[2] = 0x55.toByte()
                data[3] = passwordBytes.size.toByte()
                passwordBytes.copyInto(data, 4)
                DMokoSupport.getInstance().writePasswordDirectly(data)

                handler.postDelayed({
                    try {
                        DMokoSupport.getInstance().sendOrder(
                            OrderTaskAssembler.getBattery()
                        )
                    } catch (_: Exception) {}
                }, 1500)
            }, 2500)
        } else {
            if (expectingConnect) {
                val retryMac = foregroundMac ?: return
                if (connectRetries < 3) {
                    connectRetries++
                    android.util.Log.d("MkButton", "Disconnect during connect phase, retry $connectRetries/3 for $retryMac in 200ms")
                    connectionTimeoutHandler.postDelayed({
                        if (expectingConnect) {
                            android.util.Log.d("MkButton", "forceConnDevice retry $connectRetries for $retryMac")
                            DMokoSupport.getInstance().forceConnDevice(retryMac)
                        }
                    }, 200L)
                } else {
                    android.util.Log.w("MkButton", "Max retries reached for $retryMac")
                }
                return
            }
            isDeviceConnected = false
        }

        channel.invokeMethod("onConnectionStatus", mapOf("connected" to connected))
    }

    // ---------------------------------------------------------------------------
    // EventBus — Task responses & notify data
    // ---------------------------------------------------------------------------

    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onOrderTaskResponseEvent(event: OrderTaskResponseEvent) {
        val eventMac = event.macAddress
        if (eventMac != null && eventMac != foregroundMac) return

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
                if (value.size >= 3 && (value[0].toInt() and 0xFF) == 0xEB && (value[1].toInt() and 0xFF) == 0x00) {
                    val key = value[2].toInt() and 0xFF
                    when (key) {
                        0x4A -> {
                            if (value.size >= 6) {
                                val mV = ((value[4].toInt() and 0xFF) shl 8) or (value[5].toInt() and 0xFF)
                                val percent = if (mV >= 3700) {
                                    ((mV - 3000).toFloat() / 1200f * 100f).toInt().coerceIn(0, 100)
                                } else {
                                    ((mV - 2000).toFloat() / 1300f * 100f).toInt().coerceIn(0, 100)
                                }
                                map["batteryPercent"] = percent
                                android.util.Log.d("MkButton", "Battery voltage: ${mV}mV → $percent%")
                                foregroundMac?.let { mac ->
                                    context.getSharedPreferences("mk_button_config", Context.MODE_PRIVATE)
                                        .edit().putInt("${mac}_batteryPercent", percent).apply()
                                }
                            }
                        }
                        0x62 -> {
                            if (value.size >= 5) {
                                map["batteryPercent"] = value[4].toInt() and 0xFF
                                android.util.Log.d("MkButton", "Battery percent: ${value[4].toInt() and 0xFF}%")
                            }
                        }
                    }
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

        val elapsed = System.currentTimeMillis() - connectedAt
        if (elapsed < 5000) {
            android.util.Log.d("MkButton", "Click ignored — within 5s cooldown after connect ($elapsed ms)")
            return
        }

        val mac = foregroundMac
        val config = if (mac != null) deviceActionConfigs[mac] else null
        android.util.Log.d("MkButton", "handleNotifyData: mac=$mac pressType=$pressType config=${config?.buttonAction}/${config?.clickType}")
        if (config == null) {
            android.util.Log.w("MkButton", "No config for mac=$mac, deviceActionConfigs keys=${deviceActionConfigs.keys}")
        } else if (pressType != config.clickType) {
            android.util.Log.w("MkButton", "pressType=$pressType != config.clickType=${config.clickType}")
        } else if (config.buttonAction !in listOf("call", "sms", "sms_and_call")) {
            android.util.Log.w("MkButton", "buttonAction=${config.buttonAction} not in emergency list")
        } else {
            android.util.Log.d("MkButton", "Executing emergency action: ${config.buttonAction}")
            MkButtonBackgroundService.executeEmergencyAction(
                context, mac!!, config.buttonAction, config.emergencyPhone, config.deviceName
            )
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