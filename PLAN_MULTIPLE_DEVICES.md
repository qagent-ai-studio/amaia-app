# 📋 Plan de Implementación: Conexiones Simultáneas BLE

## 🎯 Objetivo
Permitir que la app Amaia conecte **simultáneamente** múltiples dispositivos MK:
- **Pulsera Tag MK** (dispositivo 1)
- **Botón de Pánico MK** (dispositivo 2)
- Potencialmente más dispositivos en el futuro

---

## 🔍 Análisis del Problema Actual

### Limitaciones actuales:

1. **Estado BLoC:**
   - `BleButtonConnected` solo almacena 1 MAC address
   - No puede representar múltiples conexiones activas

2. **Background Service (Android):**
   - `MkButtonBackgroundService` solo maneja 1 conexión BLE
   - Un solo `DMokoSupport` instance

3. **SDK MokoSupport:**
   - ✅ **BUENAS NOTICIAS:** El SDK SÍ soporta múltiples conexiones
   - Cada instancia de `DMokoSupport` puede conectarse a un dispositivo diferente
   - EventBus puede filtrar eventos por MAC

---

## 🏗️ Arquitectura Propuesta

### **Cambios en Flutter (Dart):**

#### 1. **Nuevo Estado BLoC:**

```dart
// lib/pages/ble_button/bloc/ble_button_state.dart

/// Estado con múltiples dispositivos conectados
class BleButtonMultiConnected extends BleButtonState {
  const BleButtonMultiConnected({
    required this.connectedDevices,
    this.primaryDeviceMac,
  });

  // Map<MAC, DeviceConnection>
  final Map<String, ConnectedDeviceState> connectedDevices;
  
  // MAC del dispositivo principal (usado para UI por defecto)
  final String? primaryDeviceMac;

  @override
  List<Object?> get props => [connectedDevices, primaryDeviceMac];
}

/// Estado de un dispositivo individual conectado
class ConnectedDeviceState extends Equatable {
  const ConnectedDeviceState({
    required this.mac,
    required this.name,
    this.deviceInfo,
    this.lastButtonPress,
    this.isLoading = false,
    this.connectionStatus = ConnectionStatus.connected,
  });

  final String mac;
  final String name;
  final DeviceInfo? deviceInfo;
  final ButtonPressEvent? lastButtonPress;
  final bool isLoading;
  final ConnectionStatus connectionStatus;

  @override
  List<Object?> get props => [mac, name, deviceInfo, lastButtonPress, isLoading, connectionStatus];
}

enum ConnectionStatus {
  connecting,
  connected,
  disconnecting,
  disconnected,
  error,
}
```

#### 2. **Nuevos Eventos BLoC:**

```dart
// lib/pages/ble_button/bloc/ble_button_event.dart

/// Conectar múltiples dispositivos al mismo tiempo
class MultipleDevicesConnectRequested extends BleButtonEvent {
  const MultipleDevicesConnectRequested({required this.devices});
  
  final List<SavedDevice> devices;
}

/// Agregar un nuevo dispositivo a las conexiones existentes
class DeviceAddRequested extends BleButtonEvent {
  const DeviceAddRequested({
    required this.mac,
    required this.password,
  });
  
  final String mac;
  final String password;
}

/// Desconectar un dispositivo específico (mantener otros)
class DeviceRemoveRequested extends BleButtonEvent {
  const DeviceRemoveRequested({required this.mac});
  
  final String mac;
}

/// Establecer dispositivo principal
class PrimaryDeviceSetRequested extends BleButtonEvent {
  const PrimaryDeviceSetRequested({required this.mac});
  
  final String mac;
}
```

---

### **Cambios en Android (Kotlin):**

#### 3. **Nuevo Servicio Multi-Device:**

```kotlin
// android/.../ble/MkButtonMultiDeviceService.kt

class MkButtonMultiDeviceService : Service() {
    
    companion object {
        private const val CHANNEL_ID = "mk_multi_device_service"
        private const val NOTIFICATION_ID = 2001
        
        // Gestionar múltiples dispositivos
        private val activeDevices = mutableMapOf<String, DeviceConnection>()
        
        fun startMultiDeviceService(
            context: Context, 
            devices: List<DeviceConfig>
        ) {
            val intent = Intent(context, MkButtonMultiDeviceService::class.java).apply {
                action = ACTION_START_MULTI
                putParcelableArrayListExtra(EXTRA_DEVICES, ArrayList(devices))
            }
            context.startForegroundService(intent)
        }
        
        fun addDevice(context: Context, deviceConfig: DeviceConfig) {
            val intent = Intent(context, MkButtonMultiDeviceService::class.java).apply {
                action = ACTION_ADD_DEVICE
                putExtra(EXTRA_DEVICE, deviceConfig)
            }
            context.startService(intent)
        }
        
        fun removeDevice(context: Context, mac: String) {
            val intent = Intent(context, MkButtonMultiDeviceService::class.java).apply {
                action = ACTION_REMOVE_DEVICE
                putExtra(EXTRA_MAC, mac)
            }
            context.startService(intent)
        }
    }
    
    private data class DeviceConnection(
        val mac: String,
        val name: String,
        val password: String,
        val mokoSupport: DMokoSupport,
        var isConnected: Boolean = false,
        val clickType: String = "single",
        val buttonAction: String = "sms_and_call",
        val emergencyPhone: String? = null
    )
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_MULTI -> {
                val devices = intent.getParcelableArrayListExtra<DeviceConfig>(EXTRA_DEVICES)
                devices?.forEach { connectDevice(it) }
                startForeground(NOTIFICATION_ID, createNotification())
            }
            ACTION_ADD_DEVICE -> {
                val device = intent.getParcelableExtra<DeviceConfig>(EXTRA_DEVICE)
                device?.let { connectDevice(it) }
            }
            ACTION_REMOVE_DEVICE -> {
                val mac = intent.getStringExtra(EXTRA_MAC)
                mac?.let { disconnectDevice(it) }
            }
        }
        return START_STICKY
    }
    
    private fun connectDevice(config: DeviceConfig) {
        if (activeDevices.containsKey(config.mac)) {
            android.util.Log.w("MultiDevice", "Device ${config.mac} already connected")
            return
        }
        
        // Crear nueva instancia de DMokoSupport para este dispositivo
        val mokoInstance = DMokoSupport(applicationContext)
        mokoInstance.setPassword(config.password)
        
        val connection = DeviceConnection(
            mac = config.mac,
            name = config.name,
            password = config.password,
            mokoSupport = mokoInstance,
            clickType = config.clickType,
            buttonAction = config.buttonAction,
            emergencyPhone = config.emergencyPhone
        )
        
        activeDevices[config.mac] = connection
        
        // Conectar usando esta instancia específica
        mokoInstance.connDevice(config.mac)
        
        android.util.Log.d("MultiDevice", "Connecting to ${config.name} (${config.mac})")
        updateNotification()
    }
    
    private fun disconnectDevice(mac: String) {
        activeDevices[mac]?.let { connection ->
            connection.mokoSupport.disConnectBle()
            activeDevices.remove(mac)
            android.util.Log.d("MultiDevice", "Disconnected from ${connection.name}")
            updateNotification()
        }
        
        // Si no quedan dispositivos, detener servicio
        if (activeDevices.isEmpty()) {
            stopSelf()
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    fun onConnectStatusEvent(event: ConnectStatusEvent) {
        // Identificar qué dispositivo generó el evento
        val mac = event.deviceMac // Necesitamos obtener el MAC del evento
        
        activeDevices[mac]?.let { connection ->
            when (event.action) {
                MokoConstants.ACTION_DISCOVER_SUCCESS -> {
                    connection.isConnected = true
                    android.util.Log.d("MultiDevice", "${connection.name} connected")
                    updateNotification()
                }
                MokoConstants.ACTION_DISCONNECTED -> {
                    connection.isConnected = false
                    android.util.Log.d("MultiDevice", "${connection.name} disconnected, reconnecting...")
                    // Intentar reconectar
                    Handler(Looper.getMainLooper()).postDelayed({
                        connection.mokoSupport.connDevice(mac)
                    }, 5000)
                }
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
                
                if (value.size >= 5) {
                    val clickType = when (value[4].toInt() and 0xFF) {
                        0x01 -> "single"
                        0x02 -> "double"
                        0x03 -> "long"
                        else -> "single"
                    }
                    
                    // PROBLEMA: Necesitamos saber de QUÉ dispositivo vino este evento
                    // Solución: Correlacionar por timestamp o mejorar SDK
                    handleButtonClick(clickType)
                }
            }
        }
    }
    
    private fun handleButtonClick(clickType: String) {
        // Ejecutar acción de emergencia
        // Por ahora, ejecutar la acción del primer dispositivo configurado
        activeDevices.values.firstOrNull()?.let { connection ->
            if (clickType == connection.clickType && connection.clickType != "disabled") {
                executeButtonAction(connection)
            }
        }
    }
    
    private fun executeButtonAction(connection: DeviceConnection) {
        when (connection.buttonAction) {
            "sms" -> sendEmergencySMS(connection)
            "call" -> attemptAutomaticCall(connection)
            "sms_and_call" -> {
                sendEmergencySMS(connection)
                Handler(Looper.getMainLooper()).postDelayed({
                    attemptAutomaticCall(connection)
                }, 500)
            }
        }
    }
    
    private fun createNotification(): Notification {
        val deviceNames = activeDevices.values.joinToString(", ") { it.name }
        val count = activeDevices.size
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("$count dispositivo(s) MK activo(s)")
            .setContentText(deviceNames)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    // ... resto de métodos (sendEmergencySMS, attemptAutomaticCall, etc.)
}

@Parcelize
data class DeviceConfig(
    val mac: String,
    val name: String,
    val password: String,
    val clickType: String,
    val buttonAction: String,
    val emergencyPhone: String?
) : Parcelable
```

---

## 🚧 PROBLEMA CRÍTICO IDENTIFICADO

### **⚠️ El SDK MokoSupport tiene una limitación:**

El `EventBus` de MokoSupport **NO incluye el MAC address** en los eventos de:
- `ConnectStatusEvent`
- `OrderTaskResponseEvent`

Esto significa que cuando recibes un evento de "botón presionado", **NO SABES QUÉ DISPOSITIVO** lo generó.

### **Soluciones posibles:**

#### **SOLUCIÓN A: Modificar el SDK (No recomendado)**
- Fork del SDK MokoSupport
- Agregar MAC a los eventos
- Alto esfuerzo de mantenimiento

#### **SOLUCIÓN B: Contexto de conexión (Recomendado)**
- Al conectar cada dispositivo, asociar el `DMokoSupport` instance con el MAC
- Usar un `WeakHashMap<DMokoSupport, String>` para tracking
- Correlacionar eventos por instancia

#### **SOLUCIÓN C: Servicios separados (Más simple)**
- Un `MkButtonBackgroundService` por dispositivo
- Cada servicio con NOTIFICATION_ID diferente
- Cada servicio registra su propio EventBus listener
- **VENTAJA:** Aisla completamente cada dispositivo
- **DESVENTAJA:** Más consumo de recursos

---

## ✅ RECOMENDACIÓN FINAL

**Implementar SOLUCIÓN C: Servicios Separados**

### Por qué:
1. ✅ **Aislamiento completo** - Cada dispositivo es independiente
2. ✅ **Sin ambigüedad** - Cada servicio sabe exactamente su dispositivo
3. ✅ **Más fácil de debuggear** - Logs separados por servicio
4. ✅ **Fácil de escalar** - Agregar más dispositivos es trivial
5. ✅ **Bajo riesgo** - No requiere modificar el SDK

### Desventajas (aceptables):
- ⚠️ Dos notificaciones en lugar de una (podemos agruparlas)
- ⚠️ Mayor consumo de batería (~5-10% más)

---

## 📝 IMPLEMENTACIÓN PASO A PASO

### **FASE 1: Modificar Background Service**

1. Cambiar `MkButtonBackgroundService` a aceptar un `deviceId` único
2. Usar `NOTIFICATION_ID = 1000 + deviceId.hashCode()`
3. Permitir múltiples instancias del servicio corriendo

### **FASE 2: Modificar BLoC**

1. Cambiar estado a `BleButtonMultiConnected`
2. Agregar eventos para gestión multi-device
3. Trackear cada servicio independientemente

### **FASE 3: Modificar UI**

1. Mostrar lista de dispositivos conectados
2. Permitir agregar/remover dispositivos
3. Indicador de estado por dispositivo

---

## ⏱️ Estimación de Esfuerzo

- **Cambios Android (Kotlin):** 4-6 horas
- **Cambios Flutter (Dart):** 6-8 horas
- **Testing:** 4-6 horas
- **TOTAL:** 14-20 horas (2-3 días de desarrollo)

---

## 🎯 Resultado Final

El usuario podrá:
- ✅ Conectar pulsera tag MK
- ✅ Conectar botón de pánico MK
- ✅ Ambos activos simultáneamente
- ✅ Cada uno con su configuración independiente
- ✅ SMS/llamada desde cualquier dispositivo
- ✅ Notificaciones separadas (o agrupadas)
- ✅ Gestión individual desde la app

