# Reporte de Integración BLE — App Amaia
**Rama activa:** `test-new-library`
**Fecha:** 2026-03-30
**Dispositivos:** MokoSmart MK B3 (botón de pánico) + MokoSmart MK W6 (tag pulsera)

---

## 1. Contexto general

App Flutter para cuidado de adultos mayores. Cuando el adulto mayor presiona un dispositivo BLE de emergencia, la app ejecuta una o más de las siguientes acciones configurables:

- Envío de SMS con coordenadas GPS al número de emergencia
- Llamada telefónica automática al número de emergencia

---

## 2. Dispositivos integrados

| MAC | Modelo | Batería | Rol |
|-----|--------|---------|-----|
| `ED:B7:2E:F9:5C:49` | MokoSmart MK B3 | LiPo (3000–4200 mV) | Botón de pánico |
| `D5:13:EF:B0:2A:A1` | MokoSmart MK W6 | CR2032 coin cell (2000–3300 mV) | Tag pulsera |

### Comportamiento del botón de pánico (MK B3)
El firmware implementa un mecanismo de seguridad anti-accionamiento accidental de 3 presiones:
1. **1ª presión:** 3 pitidos (firmware, sin notificación BLE)
2. **2ª presión:** Luz roja (firmware, sin notificación BLE)
3. **3ª presión:** Envía notificación BLE → la app ejecuta la acción configurada

### Comportamiento del tag (MK W6)
Dispositivo pasivo tipo pulsera. Envía notificación BLE en cada presión individual.

---

## 3. Arquitectura implementada

### 3.1 Capa Flutter (Dart)

| Archivo | Rol |
|---------|-----|
| `ble_button_bloc.dart` | BLoC principal: escaneo, conexión, estado |
| `ble_button_repository.dart` | Abstracción del MethodChannel nativo |
| `scan_page.dart` | Lista de dispositivos escaneados y guardados |
| `device_page.dart` | Configuración del dispositivo conectado |
| `database_helper.dart` | SQLite local (versión 4) |
| `saved_device.dart` | Modelo de dispositivo guardado |

### 3.2 Capa Android (Kotlin)

| Archivo | Rol |
|---------|-----|
| `MkButtonChannel.kt` | Puente Flutter ↔ SDK nativo. Gestiona la conexión en foreground via `DMokoSupport.getInstance()` |
| `MkButtonBackgroundService.kt` | Foreground Service Android. Gestiona múltiples dispositivos BLE simultáneamente en background |

### 3.3 SDK MokoSmart (Java — modificado)

| Archivo | Modificaciones realizadas |
|---------|--------------------------|
| `DMokoSupport.java` | Constructor público con MAC, `getMokoBleManager()` reutiliza instancia, `0x01` interceptado en `orderNotify` |
| `MokoBleConfig.java` | `startKeepAlive()` expuesto como `public`, primer keep-alive con delay de 15s |
| `ConnectStatusEvent.java` | Campo `macAddress` añadido |
| `OrderTaskResponseEvent.java` | Campos `macAddress` y `deviceName` añadidos |

### 3.4 Persistencia

- **SQLite** (`mk_button_devices.db`): dispositivos guardados, historial de clicks, configuración de acción
- **SharedPreferences** (`mk_button_config`): configuración por MAC (`_clickType`, `_buttonAction`, `_emergencyPhone`, `_deviceName`, `_password`, `_batteryPercent`). Sobrevive reinicios del servicio.

---

## 4. Flujo de operación

### App en foreground (configuración)
```
ScanPage → toca dispositivo → DeviceConnectRequested
  → remueve del background service (REMOVE_DEVICE)
  → espera 1500ms (BLE cleanup)
  → conecta via DMokoSupport singleton
  → navega a DevicePage

DevicePage dispose() → DeviceDisconnectRequested
  → desconecta singleton
  → reinicia background service para TODOS los dispositivos guardados
```

### App en background (emergencia)
```
MkButtonBackgroundService (foreground service Android)
  → DMokoSupport(context, mac) por cada dispositivo
  → onConnectStatusEvent → inicializa en T+3000ms, isInitialized=true en T+3500ms
  → click event recibido → verifica isInitialized + MAC
  → ejecuta: SMS + llamada + abre app según configuración
  → start_sticky: al reiniciar, lee SharedPrefs y reconstituye conexiones
```

### Reconexión automática
```
Desconexión detectada → backoff exponencial: 5s, 10s, 20s... (máx 300s, 10 intentos)
Cada intento: un único Runnable por MAC (pendingReconnects map)
Al reconectar exitosamente: reconnectAttempts = 0
```

---

## 5. Opciones configurables por dispositivo

Almacenadas en SQLite y SharedPreferences:

| Campo | Opciones | Descripción |
|-------|----------|-------------|
| `clickToOpenApp` | `single` / `double` / `disabled` | Tipo de click que activa la acción |
| `buttonAction` | `open_app` / `call` / `sms` / `sms_and_call` | Acción al recibir el click configurado |
| `emergencyPhone` | número de teléfono | Destinatario del SMS y/o llamada |
| `password` | string | Contraseña BLE del dispositivo (default: `123456`) |

### Mensaje SMS enviado
```
🚨 ALERTA: [nombre del dispositivo] presionado
🔋 Batería: XX%
Lat: XX.XXXXXX
Lon: XX.XXXXXX
```
*(la batería aparece solo si hay una lectura previa)*

---

## 6. Modificaciones al SDK y pruebas determinantes

### 6.1 Multi-dispositivo — EventBus sin MAC
**Problema:** Los eventos `ConnectStatusEvent` y `OrderTaskResponseEvent` del SDK original no incluyen el MAC address. Con múltiples dispositivos conectados es imposible saber qué dispositivo generó cada evento.

**Prueba determinante:** Al conectar dos dispositivos simultáneamente, el background service procesaba clicks del dispositivo A como si fueran del dispositivo B.

**Fix:** Se añadió `macAddress` a ambas clases de evento. `DMokoSupport.onDeviceConnected()` actualiza `currentDeviceMac` desde el GATT y lo incluye en cada evento publicado al EventBus.

---

### 6.2 Acumulación de clientes GATT (error status=147)
**Problema:** `DMokoSupport.getMokoBleManager()` creaba un nuevo `MokoBleConfig` (y por tanto un nuevo cliente GATT registrado con UUID único) en **cada llamada a `connDevice()`**. Cada reconexión acumulaba un cliente GATT adicional. El stack BLE de Android tiene un límite de ~8 clientes simultáneos. Al agotarse, toda nueva conexión fallaba con `status=147 (GATT_ERROR)`.

Evidencia en logcat:
```
onClientRegistered() - clientIf=212 (intento 1)
onClientConnectionState() - status=147 clientIf=212 connected=false
onClientRegistered() - clientIf=213 (intento 2)
onClientConnectionState() - status=147 clientIf=213 connected=false
onClientRegistered() - clientIf=214 (intento 3)
...
```

**Prueba determinante:** El botón de pánico, al desconectarse más seguido por su firmware de 3 presiones, acumulaba más intentos fallidos y llenaba los slots GATT antes que el tag.

**Fix en `DMokoSupport.getMokoBleManager()`:**
```java
// ANTES (creaba nuevo MokoBleConfig en cada connDevice):
mBleConfig = new MokoBleConfig(mContext, this);

// DESPUÉS (reutiliza la instancia existente):
if (mBleConfig == null) {
    mBleConfig = new MokoBleConfig(mContext, this);
}
return mBleConfig;
```

---

### 6.3 Loop infinito de reconexiones
**Problema:** Cada `ACTION_DISCONNECTED` creaba un `new Handler()` nuevo. Si el dispositivo se desconectaba y reconectaba rápido, múltiples handlers acumulaban Runnables. Al dispararse simultáneamente, llamaban `connDevice()` al mismo tiempo. `connDevice()` desconecta si ya hay una conexión activa, lo que generaba un nuevo `ACTION_DISCONNECTED`, reiniciando el ciclo.

**Prueba determinante:** Logcat mostrando "Reconnecting in 5000ms" múltiples veces para el mismo MAC sin que el dispositivo se desconectara.

**Fix:** Un único `reconnectHandler` a nivel de servicio + `pendingReconnects: Map<MAC, Runnable>`. Antes de agregar un nuevo Runnable, se cancela el anterior para el mismo MAC:
```kotlin
pendingReconnects.remove(mac)?.let { reconnectHandler.removeCallbacks(it) }
reconnectHandler.postDelayed(runnable, delay)
```

---

### 6.4 Condición de carrera foreground/background al conectar
**Problema:** Al iniciar una conexión foreground, el background service llama `disConnectBle()` al dispositivo. El BLE stack Android puede tardar >1500ms en procesar el GATT disconnect. Si el evento `ACTION_DISCONNECTED` llega después de que `foregroundMac` fue asignado en `handleConnect`, `MkButtonChannel` lo interpreta como una desconexión real del foreground → emite `BleButtonDisconnected` → cancela el proceso de conexión.

**Prueba determinante:** El usuario iniciaba la conexión y la UI regresaba al estado "desconectado" antes de completar, sin mostrar error.

**Fix en `MkButtonChannel.onConnectStatusEvent()`:**
```kotlin
val wasConnected = isDeviceConnected
isDeviceConnected = connected

// Ignorar desconexiones si nunca estuvimos conectados en foreground
if (!connected && !wasConnected) return
```

---

### 6.5 Batería mostraba 0% en MK W6
**Problema:** El tag MK W6 usa pila CR2032 (coin cell). Su voltaje en uso normal es ~2950 mV. La fórmula anterior asumía batería LiPo: `(mV - 3000) / 1200 * 100` → resultado negativo → coercionado a 0%.

Adicionalmente, el comando `0x62` (porcentaje directo) no genera respuesta en el MK W6. Solo responde al comando `0x4A` (voltaje en mV).

**Prueba determinante:** Logcat mostrando `Battery voltage: 2950mV → 0%`.

**Fix — fórmula dual según tipo de batería:**
```kotlin
val percent = if (mV >= 3700) {
    // LiPo (MK B3 botón): rango 3000–4200 mV
    ((mV - 3000).toFloat() / 1200f * 100f).toInt().coerceIn(0, 100)
} else {
    // CR2032 (MK W6 tag): rango 2000–3300 mV
    ((mV - 2000).toFloat() / 1300f * 100f).toInt().coerceIn(0, 100)
}
```
Resultado para 2950 mV: **73%**

Adicionalmente, la batería se persiste en SharedPrefs (`${mac}_batteryPercent`) para incluirla en el SMS de emergencia.

---

### 6.6 Keep-alive contaminaba cola de tareas
**Problema:** El keep-alive envía comandos via `writeDirectly` (sin crear tarea en el queue del SDK). El dispositivo responde con `EB 00 01 XX` en `CHAR_PARAMS`. `orderNotify` no interceptaba la respuesta del key `0x01`, por lo que llegaba a `orderResponseValid`. Si había una tarea pendiente (ej. lectura de batería), el validator la daba por respondida incorrectamente → ORDER TIMEOUT.

**Fix:** Añadir `0x01` al bloque de keys interceptados en `DMokoSupport.orderNotify`:
```java
if (key == 0x57 || key == 0x2C || key == 0x51 || key == 0x01) {
    return true; // consumido, no llega al queue
}
```

---

### 6.7 Config perdida al reconectar (SMS/llamada no ejecutaba)
**Problema:** Al conectar un dispositivo en foreground, se llama `removeDeviceFromBackgroundService()` → el map `deviceActionConfigs` en `MkButtonChannel` pierde la entrada del MAC. Al recibir un click mientras el foreground está activo, `config` era `null` → la acción no se ejecutaba.

**Fix:** En `onConnectStatusEvent(ACTION_DISCOVER_SUCCESS)`, si el MAC no está en `deviceActionConfigs`, se restaura la config desde SharedPrefs:
```kotlin
if (!deviceActionConfigs.containsKey(connectedMac)) {
    val prefs = context.getSharedPreferences("mk_button_config", ...)
    val clickType = prefs.getString("${connectedMac}_clickType", null)
    // ... restaurar ForegroundActionConfig
}
```

---

### 6.8 Servicio no procesaba clicks al reiniciarse (START_STICKY)
**Problema:** Android puede matar y reiniciar un `Service` con `START_STICKY`. Al reiniciarse, el Intent es `null` y `deviceStates` está vacío → el servicio arranca pero no procesa ningún click.

**Fix:** En el `else` branch de `onStartCommand` (intent sin acción conocida), llamar `restoreDevicesFromPrefs()` que lee `mk_button_config` en SharedPrefs y reconstituye todas las conexiones.

---

## 7. Lo que el SDK del proveedor NO resuelve (construido por nosotros)

| Funcionalidad | Estado en MKBleLibSource | Implementado en app_amaia |
|---------------|--------------------------|---------------------------|
| Multi-dispositivo simultáneo | ❌ Singleton, una conexión | ✅ `Map<MAC, DeviceState>` |
| MAC en eventos EventBus | ❌ Sin identificador | ✅ Campo `macAddress` en eventos |
| Reconexión automática | ❌ No existe | ✅ Backoff exponencial |
| Persistencia de config | ❌ No existe | ✅ SharedPreferences por MAC |
| Keep-alive documentado | ❌ Sin documentación oficial | ✅ Deducido, implementado |
| Soporte coin cell (CR2032) | ❌ Sin distinción de batería | ✅ Fórmula dual de voltaje |

---

## 8. Pendiente — Preguntas abiertas al proveedor

### P1 — Comportamiento BLE durante la secuencia de 3 presiones
¿El MK B3 desconecta o interrumpe la conexión GATT durante la secuencia de 3 presiones? ¿Las presiones 1 y 2 generan alguna notificación BLE, o solo la 3ª?

**Impacto:** Si el firmware desconecta BLE durante la secuencia, cada uso del botón genera un ciclo de reconexión. Con el bug de GATT anterior ya corregido, esto debería ser manejable, pero necesitamos confirmar si es comportamiento esperado.

---

### P2 — Documentación completa del protocolo GATT
¿Existe documentación de todos los comandos y respuestas? (formato `EA 00 XX YY` → `EB 00 XX ...`)

**Impacto:** Los siguientes comandos fueron deducidos por observación y podrían estar mal interpretados:

| Key | Uso que le damos | Estado |
|-----|-----------------|--------|
| `0x4A` | Voltaje de batería | Funciona en MK W6 y MK B3 |
| `0x62` | Porcentaje directo batería | MK W6 no responde |
| `0x01` | Keep-alive / ping | Respuesta interceptada pero propósito no confirmado |
| `0x51` | Keep-alive (nombre?) | No confirmado |
| `0x2C` | Keep-alive (config?) | No confirmado |
| `0x57` | Init post-autenticación | Funciona, propósito exacto no documentado |
| `0x23` | Check si requiere contraseña | Funciona por observación |

---

### P3 — Batería: rango de voltaje oficial para MK W6
¿El MK W6 usa CR2032? ¿Cuál es el rango de voltaje nominal (mínimo funcional y máximo cargado)?

**Impacto:** Estamos usando 2000–3300 mV por deducción. Un rango incorrecto afecta la precisión del porcentaje mostrado al usuario.

---

### P4 — Soporte oficial para múltiples dispositivos simultáneos
MKBleLibSource fue entregado como solución multi-dispositivo, pero contiene un singleton (`EmptyMokoSupport.getInstance()`) que gestiona una sola conexión. Construimos el sistema multi-dispositivo completo desde cero y encontramos un bug en `getMokoBleManager()` que creaba un nuevo cliente GATT en cada reconexión (status=147). ¿Existe una versión del SDK con soporte multi-dispositivo oficial, o una guía de integración?

---

### P5 — Parámetros BLE recomendados para uso prolongado en background
¿Cuáles son los valores recomendados de connection interval, supervision timeout y slave latency para mantener ambos dispositivos conectados en background por períodos de varias horas?

**Impacto:** El MK B3 se desconecta con `status=19 (GATT_CONN_TERMINATE_PEER_USER)`, lo cual suele ocurrir cuando el connection interval no es compatible con el firmware del dispositivo.

---

### P6 — Flujo de autenticación y códigos de error
¿El flujo `EA 00 23 00` → `EA 01 55 XX [bytes]` es el correcto y documentado? ¿Existe un código de respuesta para contraseña incorrecta?

**Impacto:** Actualmente no detectamos si la autenticación falla. Un dispositivo con contraseña cambiada quedaría en loop de reconexión sin error visible.

---

### P7 — Intervalo y propósito exacto del keep-alive
¿El intervalo de 15 segundos es adecuado? ¿Los keys `0x01`, `0x51` y `0x2C` del keep-alive tienen efectos secundarios en el firmware?

**Impacto:** Encontramos que la respuesta de `0x01` contaminaba la cola de tareas del SDK, lo que sugiere que el keep-alive tiene comportamiento no documentado.

---

## 9. Pendiente técnico interno

| Tarea | Prioridad |
|-------|-----------|
| Prueba de estabilidad a largo plazo (>1 hora, 2 dispositivos en background) | Alta |
| Verificar SMS + llamada con botón de pánico tras fix de condición de carrera | Alta |
| Confirmar que la batería del MK W6 muestra ~73% (no 0%) tras fix de fórmula | Alta |
| UI para configurar cada dispositivo de forma independiente (tipo de click, acción) | Media |
| Manejar contraseña incorrecta con mensaje de error visible al usuario | Media |
| Confirmar comportamiento del botón si se presiona dentro de los 3.5s post-conexión | Baja |


## 10. Cobertura alcance

| Actividad | Estado |
|-------|-----------|
| Integración del botón físico con la App AMAIA mediante una comunicación inalámbrica de corto alcance (preferentemente Bluetooth Low Energy – BLE). | Listo |
| La App (Android/iOS) debe detectar y enlazarse con el botón SOS físico | Solo Android |
| La App debe registrar internamente el evento (timestamp, ID de dispositivo, estado de batería, etc.) para auditoría | Definir como lo usarán |
| El sistema debe funcionar aun cuando la App esté en segundo plano o bloqueada, garantizando respuesta inmediata | Listo |
| La conexión debe ser segura y estable, con reconexión automática si se pierde el vínculo Bluetooth. Debe mostrar una notificación persistente o solicitar reactivación inmediata | Listo con conexión automática |
| Para el emparejamiento y administración de dispositivos, deberá tener una pantalla en la App para vincular/desvincular el botón físico. Además, tener visualización del estado de conexión y nivel de batería del dispositivo | Listo |
| Para la gestión de batería del dispositivo físico, se debe analizar el nivel y generar alertas para rangos menores a <15%. Este debe enviar una alerta SMS a AMAIA y notificar al beneficiario/red de apoyo cuando el nivel esté bajo | Implementado en api Alive |
