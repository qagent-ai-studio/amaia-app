# Sistema BLE — Documentación Técnica Interna

> **Propósito:** Documento de referencia para IA o desarrollador que trabaje en este proyecto en el futuro. Evita re-analizar el código desde cero.
>
> **Última actualización:** 2026-05-12
> **Rama activa:** `test-new-library-3`

---

## 1. Qué hace el sistema BLE

La app conecta un botón/tag BLE MokoSmart (MK B3 / MK W6) al teléfono Android. Cuando el usuario presiona el botón:

1. Si la app está en **foreground**: Flutter recibe el evento, registra un log y ejecuta la acción (SMS + llamada)
2. Si la app está en **background o cerrada**: Un Android `ForegroundService` mantiene la conexión BLE y ejecuta la acción directamente en Kotlin

El servicio de background también puede **abrir la app** cuando el botón se presiona (configuración `clickToOpenApp`).

---

## 2. Arquitectura general

```
Flutter (Dart)
├── BleButtonBloc               ← lógica de negocio
├── BleButtonRepositoryImpl     ← MethodChannel hacia Android
└── Páginas: ScanPage, DevicePage, PermissionsPage, LogsPage

Android (Kotlin) — mismo proceso que Flutter
├── MkButtonChannel             ← MethodChannel handler, conexión foreground
│   └── DMokoSupport.getInstance()  ← singleton del SDK (foreground)
└── MkButtonBackgroundService   ← ForegroundService, conexión background
    └── DMokoSupport(ctx, mac)  ← instancias separadas por dispositivo

SDK MokoSmart (Java, módulo :mokosupport)
├── DMokoSupport                ← wrapper del NRF BleManager
├── MokoBleConfig               ← keep-alive, notificaciones BLE
└── Eventos vía GreenRobot EventBus
    ├── ConnectStatusEvent      ← ACTION_DISCOVER_SUCCESS / ACTION_DISCONNECTED
    └── OrderTaskResponseEvent  ← ACTION_ORDER_RESULT / ACTION_CURRENT_DATA
```

### Separación foreground/background

| | Foreground (MkButtonChannel) | Background (MkButtonBackgroundService) |
|---|---|---|
| Instancia SDK | `DMokoSupport.getInstance()` (singleton) | `DMokoSupport(ctx, mac)` (nueva por device) |
| Propósito | Configuración, lectura de parámetros | Mantener conexión BLE 24/7 |
| Ciclo de vida | Mientras la UI está activa | `START_STICKY`, siempre corriendo |
| Eventos EventBus | `@Subscribe ThreadMode.MAIN` | `@Subscribe ThreadMode.MAIN` |

**Ambos reciben todos los eventos EventBus** — la separación se hace con flags:
- `foregroundMacs` (companion object en `MkButtonBackgroundService`): set de MACs gestionados por foreground. El background ignora clicks de MACs en este set.
- `foregroundMac` (en `MkButtonChannel`): la MAC actualmente conectada en foreground. El channel ignora eventos de otras MACs.

---

## 3. Archivos clave

### Kotlin / Android

| Archivo | Propósito |
|---------|-----------|
| `ble/MkButtonChannel.kt` | MethodChannel handler. Maneja conectar/desconectar/leer/configurar un dispositivo en foreground. También gestiona permisos Android. |
| `ble/MkButtonBackgroundService.kt` | ForegroundService. Gestiona múltiples dispositivos BLE en background. `DeviceState` por MAC, reconexión con backoff. |
| `MainActivity.kt` | Registra `MkButtonChannel` en `onCreate`, lo desregistra en `onDestroy`. |

### Flutter / Dart

| Archivo | Propósito |
|---------|-----------|
| `pages/ble_button/bloc/ble_button_bloc.dart` | BLoC principal. Todos los eventos y estados BLE. |
| `pages/ble_button/data/ble_button_repository.dart` | Abstracción sobre MethodChannel. Streams para eventos del canal. |
| `pages/ble_button/data/device_storage.dart` | SQLite — dispositivos guardados, logs de presiones, conteo de clicks. |
| `pages/ble_button/presentation/scan_page.dart` | Lista de dispositivos guardados + escaneo. |
| `pages/ble_button/presentation/device_page.dart` | Configuración de dispositivo conectado. |
| `pages/ble_button/presentation/permissions_page.dart` | Permisos Android (batería, notificaciones, overlay). |
| `lib/config_page.dart` | Provee `BleButtonBloc` mediante `BlocProvider` y navega a `ScanPage`. |

### Configuración

| Archivo | Propósito |
|---------|-----------|
| `.env` | `RECIPIENTS_CALL_EMERGENCY`, `LIST_RECIPIENTS_SMS_EMERGENCY` |
| `android/app/proguard-rules.pro` | Reglas R8 para release — **crítico para EventBus** |
| `android/app/build.gradle` | `proguardFiles` apunta al archivo anterior |

---

## 4. Flujo de conexión en foreground

```
Usuario toca dispositivo en ScanPage
  → DeviceConnectRequested(mac, password)
  → _onDeviceConnectRequested en BLoC
  → repo.prepareConnect(mac)        ← MkButtonChannel.foregroundMac = mac
  → repo.connect(mac, password)     ← DMokoSupport.getInstance().forceConnDevice(mac)
  → [EventBus ACTION_DISCOVER_SUCCESS]
  → MkButtonChannel.onConnectStatusEvent
      → foregroundMacs.add(mac)
      → writePasswordDirectly(...)    ← autenticación en 2 pasos
      → [delay 2500ms]
      → writePasswordDirectly(...)    ← envía password real
      → [delay 1500ms]
      → getBattery()
  → channel.invokeMethod("onConnectionStatus", connected=true)
  → BLoC: _onConnectionStatusChanged(connected=true)
      → _startDeviceInBackground(device)
      → emit(BleButtonConnected)
```

### _startDeviceInBackground

Llama `startBackgroundService` que envía `ACTION_START_SERVICE` al background service. El background service verifica:
```kotlin
val alreadyInForeground = mac in foregroundMacs
// Si true: isConnected=true sintético, NO llama connDevice
// Si false: llama state.support.connDevice(mac)
```

---

## 5. Flujo de eliminación de dispositivo

**El flujo más complejo y el que más bugs tuvo.**

```dart
// _onSavedDeviceDeleteRequested en BLoC:
emit(BleButtonScanning(savedDevices: []));
await DeviceStorage.instance.deleteDevice(event.mac);    // 1. Borra SQLite
await _repo.removeDeviceFromBackgroundService(mac, clearConfig: true);  // 2. Limpia todo
add(ScanStarted());                                       // 3. Reinicia escaneo
```

### MkButtonChannel.handleRemoveDeviceFromBackgroundService

```kotlin
// ORDEN CRÍTICO — no cambiar sin entender las razones
deviceActionConfigs.remove(mac)
foregroundMac = null              // ← null ANTES de disConnectBle para que el
                                  //   onConnectStatusEvent no procese el evento de disconnect
isDeviceConnected = false
MkButtonBackgroundService.pendingRemovals.add(mac)  // ← ANTES de disConnectBle
DMokoSupport.getInstance().disConnectBle()           // ← foreground disconnect
// Limpiar SharedPrefs con .commit() (síncrono)
MkButtonBackgroundService.foregroundMacs.remove(mac)
MkButtonBackgroundService.removeDevice(context, mac, clearPrefs = true)  // intent async
```

### MkButtonBackgroundService — ACTION_REMOVE_DEVICE

```kotlin
pendingReconnects.remove(mac)?.let { reconnectHandler.removeCallbacks(it) }
clearDevicePrefs(mac)
foregroundMacs.remove(mac)
pendingRemovals.add(mac)   // asegura que esté aunque el channel no lo haya puesto
if (!state.isConnected) {
    deviceStates.remove(mac)
    pendingRemovals.remove(mac)
} else {
    state.support.disConnectBle()
    // Timeout de seguridad: si ACTION_DISCONNECTED nunca llega (ver sección de bugs)
    reconnectHandler.postDelayed({
        if (mac in pendingRemovals) {
            pendingRemovals.remove(mac)
            val removed = deviceStates.remove(mac)
            removed?.support?.disConnectBle()  // intento final de cerrar GATT
            if (deviceStates.isEmpty()) disconnectAndStop()
        }
    }, 1500)
}
```

---

## 6. Bugs resueltos — causas raíz y fixes

### Bug 1: Dispositivo "tomado" después de eliminar (el más complejo)

**Síntoma:** Al eliminar un TAG de la lista, el dispositivo seguía conectado (3 parpadeos LED = GATT abierto). No aparecía en el escaneo BLE. Presionar el botón seguía disparando SMS/llamadas.

**Causa raíz 1 — Race condition EventBus vs Intent:**

EventBus es **síncrono** en `ThreadMode.MAIN`. Cuando el channel llama `disConnectBle()`, el evento `ACTION_DISCONNECTED` se procesa **antes** de que el intent `ACTION_REMOVE_DEVICE` llegue al background service. En ese momento, `pendingRemovals` no tenía la MAC → background intentaba reconectar.

**Fix:** `pendingRemovals.add(mac)` en el channel **ANTES** de llamar `disConnectBle()`.

**Causa raíz 2 — foregroundMac no se limpiaba al desconectar:**

Cuando el dispositivo se desconectaba (por rango o timeout), el channel ponía `isDeviceConnected = false` pero NO limpiaba `foregroundMac`. Cuando el background service reconectaba independientemente, el EventBus `ACTION_DISCOVER_SUCCESS` llegaba al channel con el mismo MAC → el channel lo trataba como reconexión foreground → `foregroundMacs.add(mac)`, enviaba password y getBattery via el singleton.

Esto hacía que el singleton intentara conectarse también, quedando en estado `CONNECTING`. Al eliminar, `disConnectBle()` sobre un GATT en CONNECTING producía `cancelOpen()` en lugar de un disconnect limpio, y el `ACTION_DISCONNECTED` del EventBus llegaba con `macAddress = null`.

**Fix:**
```kotlin
// En onConnectStatusEvent ACTION_DISCONNECTED del channel:
isDeviceConnected = false
foregroundMac?.let { MkButtonBackgroundService.foregroundMacs.remove(it) }
foregroundMac = null   // ← LO CRÍTICO: limpiar para no confundir eventos del background
```

**Causa raíz 3 — ACTION_DISCONNECTED llega con macAddress = null:**

Cuando el disconnect viene de `cancelOpen()` (GATT en CONNECTING, no CONNECTED), el evento EventBus tiene `macAddress = null`. El background service hacía `val mac = event.macAddress ?: return` → limpieza nunca ocurría → force-remove después de timeout.

**Fix:** Manejar el evento null-mac explícitamente:
```kotlin
if (event.macAddress == null && event.action == MokoConstants.ACTION_DISCONNECTED) {
    pendingRemovals.toList().forEach { pendingMac ->
        val pendingState = deviceStates.remove(pendingMac) ?: return@forEach
        pendingRemovals.remove(pendingMac)
        pendingReconnects.remove(pendingMac)?.let { reconnectHandler.removeCallbacks(it) }
        pendingState.support.disConnectBle()
    }
    if (deviceStates.isEmpty() && pending.isNotEmpty()) disconnectAndStop()
    return
}
```

**Causa raíz 4 — Ventana de tiempo donde el background ejecuta acciones:**

Entre `pendingRemovals.add(mac)` y la limpieza final (que puede tomar 1-4s), si el usuario presionaba el botón, el background service procesaba el click y ejecutaba SMS/llamada.

**Fix:** Check al inicio de `onOrderTaskResponseEvent`:
```kotlin
if (mac in foregroundMacs) return
if (mac in pendingRemovals) return   // ← ignora todos los clicks de dispositivos en eliminación
```

---

### Bug 2: SMS/llamada duplicada por doble notificación BLE

**Síntoma:** Cada presión del botón generaba 2 registros en la DB.

**Causa raíz:** El SDK del dispositivo envía 2 notificaciones BLE por presión física:
- `CHAR_CLICK_EVENT` — el evento principal
- `CHAR_SINGLE_TRIGGER` / `CHAR_DOUBLE_TRIGGER` / `CHAR_LONG_TRIGGER` — trigger específico

**Fix 1:** En `MkButtonChannel.handleNotifyData`, solo procesar `CHAR_CLICK_EVENT`:
```kotlin
val pressType = when (response.orderCHAR as? OrderCHAR) {
    OrderCHAR.CHAR_CLICK_EVENT -> parseCHARClickEvent(value)
    else -> return  // ignorar CHAR_SINGLE_TRIGGER, etc.
}
```

**Fix 2:** Cooldown de 2 segundos tanto en channel como en background service:
```kotlin
val now = System.currentTimeMillis()
if (now - lastButtonPressAt < 2000) return
lastButtonPressAt = now
```

**Fix 3:** Cooldown de 5 segundos post-conexión (el dispositivo envía un click buffereado al habilitar notificaciones):
```kotlin
if (now - connectedAt < 5000) return
```

---

### Bug 3: Batería no se cargaba automáticamente al entrar a DevicePage

**Causa raíz:** La corrección del bug de eliminación había roto `ACTION_DISCOVER_SUCCESS` del background: cuando el foreground se conectaba, el evento llegaba al background y, si la MAC estaba en `pendingRemovals` (de una operación previa), llamaba `disConnectBle()` interrumpiendo la secuencia de autenticación + batería.

**Fix:** El cleanup de `pendingRemovals` en `ACTION_DISCOVER_SUCCESS` ya no llama `disConnectBle()` si el dispositivo fue reconectado por el foreground — el flag `alreadyInForeground` indica que la conexión es sintética (el background nunca llamó `connDevice()`). Solo se llama `disConnectBle()` cuando el background reconectó realmente.

---

### Bug 4: Permisos no se actualizaban en tiempo real (iOS-style workaround)

**Síntoma:** Al conceder un permiso Android, el indicador verde no aparecía hasta salir y volver a entrar.

**Fix:** `PermissionsPage` implementa `WidgetsBindingObserver` y re-verifica permisos en `didChangeAppLifecycleState == resumed`:
```dart
class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }
}
```

---

### Bug 5: Release APK — EventBus no funcionaba (R8/ProGuard)

**Síntoma:** Con `flutter run` (debug) todo funcionaba. Con el APK generado, `ACTION_DISCONNECTED` nunca llegaba al background service → el force-remove siempre disparaba a los 1.5s.

**Causa raíz:** R8 (el minificador de Android en release) elimina métodos que detecta como "no referenciados". Los métodos `@Subscribe` de EventBus son invocados por reflexión, así que R8 los borra.

**Fix:** Crear `android/app/proguard-rules.pro`:
```
-keepattributes *Annotation*
-keepclassmembers class ** {
    @org.greenrobot.eventbus.Subscribe <methods>;
}
-keep enum org.greenrobot.eventbus.ThreadMode { *; }
-keep class com.moko.** { *; }
-keep class no.nordicsemi.** { *; }
-keep class com.moko.ble.lib.event.** { *; }
-keep class com.moko.support.d.** { *; }
-keep class com.mistatas.amaia.ble.MkButtonChannel { *; }
-keep class com.mistatas.amaia.ble.MkButtonBackgroundService { *; }
```

Y en `android/app/build.gradle`:
```groovy
buildTypes {
    release {
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

---

## 7. Comportamiento del SDK EventBus — patrones importantes

### EventBus es síncrono en MAIN thread

```kotlin
DMokoSupport.getInstance().disConnectBle()
// El evento ACTION_DISCONNECTED YA SE PROCESÓ antes de que llegue la próxima línea
MkButtonBackgroundService.removeDevice(...)  // el intent se procesa DESPUÉS (async)
```

Esto significa que cualquier flag que necesite estar listo ANTES del procesamiento del evento debe setearse ANTES de llamar `disConnectBle()`.

### macAddress puede ser null

Cuando el GATT está en estado `CONNECTING` (no `CONNECTED`) y se llama `disConnectBle()`, el resultado es `cancelOpen()`. El evento `ACTION_DISCONNECTED` resultante tiene `macAddress = null`. Siempre hay que manejar este caso.

### Ambos subscribers reciben todos los eventos

`MkButtonChannel` y `MkButtonBackgroundService` están ambos suscritos a EventBus. Cada evento llega a los dos. Los dos tienen lógica para ignorar MACs que no les corresponden:
- Channel: `if (eventMac != null && eventMac != foregroundMac) return`
- Background: `if (mac in foregroundMacs) return` (en `onOrderTaskResponseEvent`)

---

## 8. Estado de pendingRemovals

`pendingRemovals` es un `mutableSetOf<String>()` en el **companion object** de `MkButtonBackgroundService` — es decir, es **estático** y accesible desde `MkButtonChannel`.

Se agrega una MAC a `pendingRemovals` cuando:
1. `MkButtonChannel.handleRemoveDeviceFromBackgroundService` — **antes** de `disConnectBle()`
2. `MkButtonBackgroundService ACTION_REMOVE_DEVICE` — en el handler del intent

Se elimina cuando:
1. `ACTION_DISCONNECTED` con MAC en `pendingRemovals` → cleanup exitoso
2. `ACTION_DISCONNECTED` con MAC null → cleanup de todos los `pendingRemovals`
3. `ACTION_DISCOVER_SUCCESS` con MAC en `pendingRemovals` → el background reconectó mientras se eliminaba
4. `ACTION_REMOVE_DEVICE` cuando `!state.isConnected` → cleanup inmediato
5. Timeout de 1500ms en `ACTION_REMOVE_DEVICE` → force cleanup
6. `onDestroy` → `pendingRemovals.clear()`

---

## 9. Reconexión del background service

```
ACTION_DISCONNECTED (mac, isConnected=false)
  → mac NOT in pendingRemovals
  → reconnectAttempts++
  → delay = min(5000 * 2^(attempts-1), 300_000)  // exponential backoff
  → postDelayed: state.support.connDevice(mac)
  → [si éxito] ACTION_DISCOVER_SUCCESS
      → cancelar pendingReconnect
      → isConnected=true, isInitialized=false
      → [delay 3000ms] enableClickEventNotify(), etc.
      → [delay 500ms] isInitialized=true
      → [delay 15000ms] startKeepAlive()
```

Clicks ignorados mientras `!state.isInitialized` — evita el click buffereado que el firmware envía al conectar.

---

## 10. Ciclo de vida del background service

- `onCreate`: registra EventBus, `bluetoothReceiver`
- `onStartCommand ACTION_START_SERVICE`: agrega dispositivo a `deviceStates`, conecta
- `onStartCommand ACTION_REMOVE_DEVICE`: desconecta y elimina dispositivo
- `onStartCommand ACTION_EXECUTE_EMERGENCY`: ejecuta SMS/llamada sin guardar log (ya lo hace Flutter)
- `onStartCommand null` (restart por START_STICKY): `restoreDevicesFromPrefs()` → lee `mk_button_config` SharedPrefs
- `onDestroy`: desconecta todo, limpia

### SharedPrefs mk_button_config

Cada dispositivo guarda: `${mac}_clickType`, `${mac}_buttonAction`, `${mac}_emergencyPhone`, `${mac}_smsPhone`, `${mac}_deviceName`, `${mac}_password`, `${mac}_batteryPercent`

Clave global: `mk_pending_logs` — array JSON de logs generados en background, importados al iniciar la app.

---

## 11. Gotchas para el futuro

1. **No limpiar foregroundMac en disconnect rompe todo.** Si `foregroundMac` queda seteado después de que el foreground se desconecta, el channel interpreta reconexiones del background como si fueran foreground, y el singleton intenta conectarse también.

2. **ProGuard debe tener reglas de EventBus.** Sin ellas, en release `@Subscribe` methods son eliminados y ningún evento BLE llega a los handlers. Todo funciona en debug (`flutter run`) pero falla en APK.

3. **El orden importa en el delete.** `pendingRemovals.add(mac)` debe ir ANTES de `disConnectBle()`. Si va después, EventBus procesa el `ACTION_DISCONNECTED` antes de que la MAC esté en `pendingRemovals`, y el background programa una reconexión.

4. **`cancelOpen()` vs `disconnect()`.** Si el GATT no está en CONNECTED (está en CONNECTING o DISCONNECTED), `disConnectBle()` llama `cancelOpen()` y el EventBus llega con `macAddress = null`. El código tiene un handler especial para este caso.

5. **`isConnected = true` puede ser sintético.** Cuando `alreadyInForeground = true`, el background service no llama `connDevice()` pero sí pone `isConnected = true`. Esa instancia de `DMokoSupport` en el background nunca tiene un GATT real. Llamar `disConnectBle()` sobre ella es no-op.

6. **Doble notificación BLE.** El firmware envía `CHAR_CLICK_EVENT` + `CHAR_SINGLE/DOUBLE/LONG_TRIGGER` por cada presión. Solo procesar `CHAR_CLICK_EVENT`. Además, aplicar cooldown de 2s para duplicados.

7. **Cooldown 5s post-conexión.** El firmware envía un click buffereado al habilitar notificaciones. Ignorar clicks en los primeros 5s post-conexión (tanto en foreground como en background).

8. **START_STICKY + null intent.** Cuando Android mata y reinicia el servicio, `onStartCommand` recibe `intent = null`. La rama `else` llama `restoreDevicesFromPrefs()` para restaurar el estado.

---

## 12. Dispositivos físicos de prueba

| MAC | Nombre | Tipo | Dispositivo físico |
|-----|--------|------|-------------------|
| `D5:13:EF:B0:2A:A1` | MK Button | Tag (MK W6) | Pulsera de pánico |
| `ED:B7:2E:F9:5C:49` | MK Button | Botón (MK B3) | Botón de pánico |

Ambos usan password `123456` por defecto.

---

## 13. Números de emergencia (.env)

```
RECIPIENTS_CALL_EMERGENCY=+56991534353
LIST_RECIPIENTS_SMS_EMERGENCY=+56991534353
```

---

## 14. Estructura del SMS de emergencia

```
ALERTAMOVIL GEO=<base64(lat, lng)> ORIGIN=MK-BUTTON BATTERY=<percent>
```

Si no hay ubicación: `GEO=LocationNotAvailable`
