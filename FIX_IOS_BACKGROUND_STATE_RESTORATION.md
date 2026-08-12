# Fix: detección del botón BLE en iOS con la app terminada (CoreBluetooth State Restoration)

**Estado:** ✅ Validado en dispositivo físico (iPhone 12 mini, iOS 18.1.1) el 2026-08-12.

## Problema

En iOS, el botón de emergencia BXP-B-D dejaba de detectar pulsaciones cuando la app
ya no estaba corriendo. Lo más grave: cuando el sistema operativo mataba la app en
segundo plano por presión de memoria (algo que iOS hace de forma rutinaria), el botón
quedaba inoperativo de forma silenciosa, sin aviso al usuario.

Para una app de emergencias esto es crítico: el adulto mayor podía presionar el botón
y no ocurrir nada.

## Causa raíz

El único mecanismo oficial de iOS para relanzar una app terminada ante un evento BLE
es **CoreBluetooth State Restoration**, que requiere:

1. Inicializar el `CBCentralManager` con `CBCentralManagerOptionRestoreIdentifierKey`.
2. Implementar `centralManager(_:willRestoreState:)`.

La versión del SDK `MKBeaconXDButton` que se usaba (commit `0c56ac6`) no soportaba
State Restoration. Se confirmó con el proveedor (MokoSmart), que agregó el soporte en
el commit `544268d` ("Add support for restoration", 2026-06-09).

## Solución

### 1. Actualización del SDK

`Podfile.lock` pasó del commit `0c56ac6` al `544268d`. El SDK ahora inicializa el
`CBCentralManager` con el restore identifier, implementa `willRestoreState`, y expone
`enableStateRestorationWithIdentifier:`, `restorationDelegate` y
`isLaunchedFromStateRestoration`.

### 2. Detección del relanzamiento

**`ios/Runner/AppDelegate.swift`** — se detecta el relanzamiento por BLE con la API
oficial de Apple y se activa State Restoration antes de cualquier operación BLE:

```swift
let relaunchedForBluetooth = launchOptions?[.bluetoothCentrals] != nil
MkButtoniOSService.shared.configureStateRestoration(relaunchedForBluetooth: relaunchedForBluetooth)
```

No se usa `MKBXDCentralManager.isLaunchedFromStateRestoration()` porque **siempre
devuelve `false`** (ver "Bugs del SDK" más abajo).

### 3. Reconstrucción del estado

**`ios/Runner/MkButtoniOSService.swift`**:

- `configureStateRestoration(relaunchedForBluetooth:)` llama
  `enableStateRestoration(withIdentifier:)` con el Bundle ID y registra el
  `restorationDelegate`. En arranques normales sale por el `guard` y no altera nada.
- Se persiste el MAC del dispositivo activo en `UserDefaults` (clave
  `mk_active_bg_mac`) al iniciar el background service, y se limpia al detenerlo.
  Permite reconstruir la configuración tras un cold start.
- `reloadActiveConfigFromDefaults()` reconstruye `deviceConfig` desde `UserDefaults`.
- Se llama `scheduleReconnect()` directamente en el arranque por restauración, sin
  depender del delegate del SDK (que no siempre se invoca — ver bug 2).

### 4. Ventana de pulsación durante la restauración

**Este es el fix que hace que la alerta efectivamente salga.**

La pulsación que despierta la app llega ~87 ms después del arranque, cuando
`isInitialized` todavía es `false`. Los guards de `handleButtonPress` y
`onLongConnectionModeData` la descartaban en silencio.

Ese guard no se puede eliminar: existe para bloquear el click buffereado que el
firmware envía al habilitar notificaciones. La solución es una ventana acotada:

```swift
private var restorationPressWindow = false
```

- Se abre en `configureStateRestoration`, solo en la rama de relanzamiento por BLE.
- Se cierra al inicio de `enableNotificationsAfterDelay()` — es decir, **antes** de
  habilitar notificaciones, que es justo cuando llega el click buffereado.
- Los guards pasan a ser `isInitialized || restorationPressWindow`.

Separación temporal efectiva:

| Momento | Evento | Ventana | Resultado |
|---|---|---|---|
| t≈0,087 s | pulsación real | abierta | ✅ pasa |
| t≈0,8 s | re-auth exitosa | se cierra | — |
| t≈3,5 s | click buffereado del firmware | cerrada | ✅ bloqueado |
| t≈4,0 s | `isInitialized = true` | — | operación normal |

El debounce de 2 s en `handleButtonPress` da protección adicional.

### 5. `@objc` en el delegate de restauración

El protocolo `mk_bxd_stateRestorationDelegate` declara su método como `@optional`, y
el SDK lo invoca tras un `respondsToSelector:`. Sin `@objc` explícito, Swift no lo
expone al runtime de Objective-C, el SDK lo salta en silencio y el compilador no
avisa (precisamente por ser opcional):

```swift
@objc func mk_bxd_didRestoreState(withPeripherals peripherals: [CBPeripheral]) {
```

## Restricción de plataforma: la ventana de ~10 segundos

iOS otorga solo unos **10 segundos de ejecución** al relanzar la app por un evento
BLE. Verificado en los logs: tras el despertar, la app no vuelve a emitir actividad
hasta el siguiente evento.

Consecuencia de diseño: **los temporizadores de reconexión (5 s, 30 s, backoff
exponencial) no alcanzan a correr**. La alerta debe procesarse en el instante del
despertar; no se puede depender de reconectar primero y actuar después. Por eso la
ventana del punto 4 es imprescindible y no un mero refinamiento.

## Alcance y límite

| Escenario | Antes | Después |
|---|---|---|
| App en primer plano | ✅ | ✅ |
| App suspendida (background reciente) | ⚠️ | ✅ |
| **Sistema mata la app por memoria** | ❌ | ✅ |
| Usuario cierra la app a mano (swipe up) | ❌ | ❌ (límite de iOS) |

El cierre manual del usuario **no tiene solución en iOS** por diseño de Apple: al
forzar el cierre, el sistema deshabilita el relanzamiento por State Restoration. La
mitigación es educativa: indicar al usuario/cuidador no cerrar la app manualmente.

## Bugs detectados en el SDK del proveedor

Los tres afectan a cualquier integrador. Reportados a MokoSmart.

1. **`isLaunchedFromStateRestoration()` siempre devuelve `false`.** En
   `MKBXDCentralManager.m:106-111` se lee la bandera `MKBXD_WAS_TERMINATED` y se
   escribe en `NO`, pero ningún punto del SDK la escribe en `YES`.

2. **`willRestoreState` no notifica si `peripherals.count == 0`.** En
   `MKBXDBaseCentralManager.m:114`, la llamada a `restorationCompletion` está dentro
   de ese `if`. Si iOS restaura solo un scan (caso habitual con el TAG fuera de
   rango), `mk_bxd_didRestoreStateWithPeripherals:` nunca se invoca.

3. **El delegate `@optional` falla en silencio desde Swift.** Requiere `@objc`
   explícito en la implementación. Debería declararse `@required` o documentarse.

## Verificación

### Metodología

Xcode "Stop" **no mata la app** cuando no fue Xcode quien la lanzó: queda suspendida
y produce falsos positivos. El método fiable:

```bash
# 1. Abrir la app desde el ícono (NO con flutter run, que reinstala)
# 2. Anotar PID y UUID de contenedor
xcrun devicectl device info processes --device "iPhone de Danilo" | grep -i "Runner.app/Runner"

# 3. Matar el proceso
xcrun devicectl device process terminate --device "iPhone de Danilo" --pid <PID> --kill

# 4. Verificar que no queda proceso
xcrun devicectl device info processes --device "iPhone de Danilo" | grep -i "Runner.app/Runner"

# 5. Esperar 2-3 min, presionar el botón, volver a consultar el PID
```

Criterio de éxito: **PID distinto con el mismo UUID de contenedor**. Si el contenedor
cambia hubo reinstalación y la prueba no vale.

Logs con **Console.app** (dispositivo en la barra lateral, filtro `MK`). En macOS 26
`log stream --device-name` ya no existe. Si los logs salen duplicados, hay procesos
`idevicesyslog` huérfanos de sesiones previas de `flutter run`; eliminarlos.

### Resultado (2026-08-12)

```
PID:        961  →  993
Contenedor: 14179CB9-2187-4B1E-989A-86AFEEBE496E  (sin cambios)
```

Proceso terminado y verificado como muerto. Sin interacción con el teléfono. Al
presionar el botón:

```
[MKBXD] State restoration enabled with identifier: cl.mistatas.amaia.want
[MK] launched from state restoration
[MK] reloadActiveConfigFromDefaults: restored config for mac=ED:B7:2E:F9:5C:49
[MKBXD] willRestoreState called - System is restoring Bluetooth state
[MKBXD] Restoring 1 previously connected peripherals
[MK] handleButtonPress ... restorationWindow=true ...
[MK] callEmergencyApi phone=... apiUrl=https://www.mistatas.cl/api/callback.ios.php
```

Alerta enviada y notificación mostrada, con la app previamente terminada.

## Nota sobre CocoaPods

`ios/MKBeaconXDButton.podspec` apunta a `:branch => 'Developer'` sin fijar commit; el
pin vive solo en `Podfile.lock`. Un `pod update` deriva al HEAD de la rama y cambia el
SDK en silencio. Además `Pods/` no está en git, así que al cambiar de rama queda
desincronizado con el lock.

Para forzar una versión concreta: fijar `:commit` en el podspec temporalmente, correr
`pod update MKBeaconXDButton --no-repo-update`, y restaurar el podspec.

## Archivos modificados

- `ios/Podfile.lock` (commit del SDK)
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/MkButtoniOSService.swift`
