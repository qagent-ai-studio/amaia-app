# Integración MK Button - Documentación Técnica

## Resumen

Este documento explica la integración del dispositivo **MK Button (BXP-B-D)** de MOKO/BeaconX Pro en la aplicación Flutter, incluyendo los desafíos encontrados y las soluciones implementadas.

## Descripción del Dispositivo

- **Modelo**: BXP-B-D
- **Fabricante**: MOKO/BeaconX Pro
- **Protocolo**: Bluetooth Low Energy (BLE)
- **Funcionalidad**: Botón BLE que envía eventos de presión (simple, doble, largo)

## Arquitectura de la Solución

### Componentes

1. **Flutter Layer** (`lib/pages/ble_button/`)
   - BLoC pattern para manejo de estado
   - Repository pattern para abstracción de comunicación
   - UI para escaneo y control del dispositivo

2. **Native Android Layer** (`android/app/src/.../ble/`)
   - `MkButtonChannel.kt`: Bridge entre Flutter y SDK nativo via MethodChannel
   - Implementación de EventBus para comunicación asíncrona

3. **MK Button SDK** (`android/mokosupport/`)
   - SDK oficial de MOKO (modificado)
   - Basado en Nordic BLE Manager

## Flujo de Conexión

### Secuencia Correcta

```
1. Escaneo BLE
   └─> Filtrar dispositivos "MK Button*"

2. Conexión
   └─> DMokoSupport.getInstance().connDevice(mac)

3. MTU Exchange (automático)
   └─> Solicitar MTU de 247 bytes

4. Habilitar Notificaciones (automático)
   └─> 0xaa07 (PASSWORD)
   └─> 0xaa01 (PARAMS)

5. Verificar Password Requirement
   └─> Enviar: EA 00 23 00
   └─> Recibir: EB 00 23 01 01

6. Autenticación
   └─> Enviar: EA 01 55 08 'Moko4321'
   └─> Recibir: EB 01 55 01 AA

7. Confirmación de Autenticación
   └─> Enviar: EA 00 57 00
   └─> Recibir: EB 00 57 01 01

8. Lectura de Configuración
   └─> Enviar: EA 00 2C 00
   └─> Recibir: EB 00 2C 07 'BXP-B-D'

9. Habilitar Notificaciones de Click Events
   └─> 0xaa08 (CLICK_EVENT)

10. DETENER - No enviar más comandos
    └─> La conexión permanece activa de forma pasiva
    └─> Los eventos de botón llegan via notificaciones
```

## Problema Crítico Identificado

### Síntoma

El dispositivo se conectaba correctamente pero se desconectaba inmediatamente después de recibir el primer evento de botón.

### Causa Raíz

El dispositivo **MK Button NO tolera comandos adicionales después de completar la secuencia de inicialización**. 

Específicamente, después de habilitar las notificaciones de click events, **NO se deben enviar más comandos** como:
- `EA 00 62 00` (Lectura de batería)
- `EA 00 51 00` (Lectura de nombre del dispositivo)
- Cualquier otro comando de lectura o escritura

### Por Qué Fallaba

En nuestra implementación inicial:

1. **Al conectar**: Se enviaba automáticamente `readDeviceInfo()` que incluía comandos de batería y nombre
2. **Después de eventos de click**: Se volvía a llamar `readDeviceInfo()`
3. **Keep-alive periódico**: Se programaba un timer para leer batería cada 60 segundos

Estos comandos adicionales causaban `ORDER TIMEOUT` en el Nordic BLE Manager, que a su vez desconectaba el dispositivo automáticamente.

### Evidencia

#### Wireshark - App Oficial BeaconX Pro (Funciona)
```
✅ Password auth
✅ EA 00 57 00 (confirm)
✅ EA 00 2C 00 (config)
✅ Enable notifications
🛑 STOP - No más comandos
✅ Conexión estable indefinidamente
```

#### Wireshark - Nuestra App (Fallaba)
```
✅ Password auth
✅ EA 00 57 00 (confirm)
✅ EA 00 2C 00 (config)
✅ Enable notifications
❌ EA 00 62 00 (battery) → ORDER TIMEOUT
❌ EA 00 51 00 (name) → ORDER TIMEOUT
❌ Desconexión inmediata
```

## Solución Implementada

### 1. Eliminar Comandos Automáticos

**Antes:**
```kotlin
// MkButtonChannel.kt
private fun handleConnect(...) {
    DMokoSupport.getInstance().connDevice(mac)
    keepAliveHandler?.postDelayed(keepAliveRunnable, 60_000) // ❌
}
```

**Después:**
```kotlin
// MkButtonChannel.kt
private fun handleConnect(...) {
    DMokoSupport.getInstance().connDevice(mac) // ✅ Solo conectar
}
```

### 2. Deshabilitar Keep-Alive

**Removido completamente:**
- `keepAliveHandler`
- `keepAliveRunnable`
- Cualquier timer o polling periódico

### 3. Deshabilitar readDeviceInfo Automático

**Flutter - BLoC**
```dart
void _onConnectionStatusChanged(...) {
  if (event.connected) {
    emit(BleButtonConnected(mac: mac, isLoading: false));
    // ❌ NO llamar: add(const DeviceInfoReadRequested());
  }
}
```

**Android - Channel**
```kotlin
private fun handleReadDeviceInfo(result: MethodChannel.Result) {
    // Retorna success sin hacer nada
    // El MK Button NO soporta comandos después de init
    result.success(null)
}
```

### 4. Modificaciones al SDK

**MokoBleConfig.java**

```java
// Deshabilitar notificaciones de CHAR_DISCONNECT
public void init() {
    requestMtu(247).then((device -> {
        enablePasswordNotify();
        // enableDisconnectNotify(); // ❌ DESHABILITADO
        enableParamsNotify();
    })).enqueue();
}

// Secuencia de inicialización simplificada
// Solo enviar comandos esenciales:
// 1. EA 00 57 00 (auth confirm)
// 2. EA 00 2C 00 (read config) - UNA SOLA VEZ
// 3. Enable click event notifications
// 4. STOP
```

**DMokoSupport.java**

```java
// Manejar respuestas retrasadas sin causar errores
public boolean orderNotify(...) {
    // Procesar 0x57, 0x2C, 0x51 como respuestas válidas
    // incluso si llegan fuera de secuencia
}
```

## Características del MK Button

### Comandos Soportados (Durante Inicialización Únicamente)

| Comando | Hex | Descripción | Cuándo Usar |
|---------|-----|-------------|-------------|
| Password Check | EA 00 23 00 | Verificar si requiere password | Al conectar |
| Send Password | EA 01 55 [len] [pass] | Enviar password | Al conectar |
| Auth Confirm | EA 00 57 00 | Confirmar autenticación | Post-password |
| Read Config | EA 00 2C 00 | Leer modelo del dispositivo | Post-auth |

### Eventos Recibidos (Vía Notificaciones)

| Característica | UUID | Evento | Formato |
|----------------|------|--------|---------|
| CLICK_EVENT | 0xaa08 | Single Press | EB 02 06 01 01 |
| CLICK_EVENT | 0xaa08 | Double Press | EB 02 06 01 02 |
| CLICK_EVENT | 0xaa08 | Long Press | EB 02 06 01 03 |
| PARAMS | 0xaa01 | Device Name (delayed) | EB 00 51 [len] [name] |

### Limitaciones Identificadas

1. **No Keep-Alive Necesario**: La conexión se mantiene estable sin enviar comandos periódicos
2. **No Lectura de Batería Post-Init**: No se puede leer la batería después de conectar
3. **No Comandos de Configuración Runtime**: No se pueden cambiar parámetros mientras está conectado
4. **Respuestas Asíncronas**: El dispositivo envía `0x51` (device name) con delay de ~3 segundos, debe ser ignorado/manejado

## Uso en Producción

### Conectar al Dispositivo

```dart
// Flutter
bleButtonBloc.add(DeviceConnectRequested(
  mac: device.mac,
  password: 'Moko4321',
));
```

### Recibir Eventos de Botón

```dart
BlocListener<BleButtonBloc, BleButtonState>(
  listener: (context, state) {
    if (state is BleButtonConnected && state.lastButtonPress != null) {
      final pressType = state.lastButtonPress!.pressType; // 'single', 'double', 'long'
      // Manejar evento
    }
  },
)
```

### Desconectar

```dart
bleButtonBloc.add(const DeviceDisconnectRequested());
```

## Mejores Prácticas

### ✅ DO

- Conectar al dispositivo y dejar la conexión idle
- Recibir eventos de botón via notificaciones BLE
- Obtener nombre del dispositivo durante el escaneo (antes de conectar)
- Desconectar limpiamente cuando el usuario lo solicite

### ❌ DON'T

- NO enviar comandos después de completar la inicialización
- NO implementar keep-alive o polling periódico
- NO leer batería automáticamente después de conectar
- NO deshabilitar/reactivar notificaciones después de la init

## Debugging

### Logs Importantes

```kotlin
// Conexión exitosa
D/MkButtonSDK: Password accepted! Starting init sequence...
D/MkButtonSDK: Device ready. Connection will stay active with notifications.

// Evento de botón recibido
D/MkButtonSDK: Click event received: eb02060102
D/MkButtonSDK: CHAR_CLICK_EVENT notification received, processing...

// ❌ PROBLEMA - Si ves esto, hay comandos extra siendo enviados
E/MkButtonSDK: !!! ORDER TIMEOUT !!! This may cause disconnection
E/MkButtonSDK: Response value: ea006200
```

### Verificar Conexión en Wireshark

1. Habilitar HCI snoop log en Android Developer Options
2. Conectar al dispositivo
3. Extraer btsnoop_hci.log
4. Abrir en Wireshark
5. Filtrar por dirección MAC del dispositivo
6. Verificar que NO haya comandos después de "EA 00 2C 00"

## Referencias

- [BeaconX Pro MK Button SDK](https://github.com/BeaconX-Pro/13-Android-MKButton-SDK)
- [Nordic BLE Library](https://github.com/NordicSemiconductor/Android-BLE-Library)
- [Bluetooth GATT Specifications](https://www.bluetooth.com/specifications/gatt/)

## Changelog

- **2026-03-03**: Solución implementada - Conexión estable lograda
  - Removido keep-alive automático
  - Deshabilitado readDeviceInfo automático
  - Documentado comportamiento del dispositivo

## Contacto de Soporte

Si se encuentran nuevos problemas, contactar a:
- **MOKO Support**: [support@mokotechnology.com](mailto:support@mokotechnology.com)
- **BeaconX Pro**: https://www.beaconxpro.com/

---

**Nota**: Este dispositivo tiene un comportamiento atípico comparado con otros dispositivos BLE. La documentación oficial del SDK no menciona estas limitaciones, lo cual causó el problema de desconexión que finalmente se resolvió mediante análisis de tráfico Wireshark y prueba-error.
