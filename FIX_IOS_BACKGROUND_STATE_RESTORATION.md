# Fix: detección del botón BLE en iOS con la app cerrada (CoreBluetooth State Restoration)

## Problema

En iOS, el botón de emergencia BXP-B-D dejaba de detectar pulsaciones cuando la app
ya no estaba corriendo en primer plano. Lo más grave: cuando el sistema operativo
mataba la app en segundo plano por presión de memoria (algo que iOS hace de forma
rutinaria), el botón quedaba inoperativo de forma silenciosa, sin aviso al usuario.

Para una app de emergencias esto es crítico: el adulto mayor podía presionar el botón
y no ocurrir nada.

## Causa raíz

El único mecanismo oficial de iOS para relanzar una app terminada ante un evento BLE
es **CoreBluetooth State Restoration**, que requiere:

1. Inicializar el `CBCentralManager` con `CBCentralManagerOptionRestoreIdentifierKey`.
2. Implementar `centralManager(_:willRestoreState:)`.

La versión del SDK `MKBeaconXDButton` que se usaba (commit `0c56ac6`) **no soportaba
State Restoration**: creaba su `CBCentralManager` sin opciones y no implementaba
`willRestoreState`. Sin eso, iOS nunca relanzaba la app.

Se confirmó con el proveedor (MokoSmart), que posteriormente agregó el soporte al SDK
en el commit `544268d` ("Add support for restoration", 2026-06-09), disponible en la
rama `Developer` del repositorio
[14-iOS-MKButton-SDK](https://github.com/BeaconX-Pro/14-iOS-MKButton-SDK).

## Solución

### 1. Actualización del SDK

Se actualizó el pod `MKBeaconXDButton` para traer el código con State Restoration:

```
cd ios && pod update MKBeaconXDButton --no-repo-update
```

`Podfile.lock` pasó del commit `0c56ac6` al `544268d`. El SDK ahora:

- Inicializa el `CBCentralManager` con `CBCentralManagerOptionRestoreIdentifierKey`.
- Implementa `centralManager:willRestoreState:` para recuperar los peripherals.
- Expone nueva API pública en `MKBXDCentralManager`:
  - `+ enableStateRestorationWithIdentifier:`
  - `restorationDelegate` (protocolo `mk_bxd_stateRestorationDelegate`)
  - `+ isLaunchedFromStateRestoration`
  - `+ setStateRestorationCompletion:`

### 2. Activación en la app

**`ios/Runner/AppDelegate.swift`** — se activa State Restoration lo más temprano
posible en `didFinishLaunchingWithOptions`, antes de cualquier operación BLE:

```swift
MkButtoniOSService.shared.configureStateRestoration()
```

**`ios/Runner/MkButtoniOSService.swift`** — cambios:

- `configureStateRestoration()`: llama `enableStateRestoration(withIdentifier:)` con el
  Bundle ID, registra el `restorationDelegate`, y si la app fue relanzada por el sistema
  (`isLaunchedFromStateRestoration()`) reconstruye la configuración del dispositivo.
- Se persiste el MAC del dispositivo activo en `UserDefaults`
  (clave `mk_active_bg_mac`) al iniciar el background service, y se limpia al detenerlo.
  Esto permite reconstruir la configuración tras un cold start, cuando el estado en
  memoria se perdió.
- `reloadActiveConfigFromDefaults()`: reconstruye `deviceConfig` desde `UserDefaults`.
- Implementación de `mk_bxd_stateRestorationDelegate`: al recibir los peripherals
  recuperados por el sistema, re-autentica con la contraseña y re-habilita las
  notificaciones reutilizando `enableNotificationsAfterDelay()`.

El flujo nativo de emergencia (`callEmergencyApi`) ya era 100% nativo y lee los datos
de `UserDefaults` (`flutter.phone`, `flutter.geo`, `flutter.URL_SMS_IOS`), por lo que
funciona aunque el motor Flutter no esté corriendo al ser relanzada la app.

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

## Requisitos previos (ya presentes)

- `Info.plist` con `UIBackgroundModes` incluyendo `bluetooth-central`.

## Verificación

- `flutter build ios --debug --no-codesign` compila correctamente contra el SDK
  actualizado.
- Prueba en dispositivo físico: conectar el botón, dejar la app en segundo plano,
  forzar presión de memoria (o esperar a que iOS termine la app), presionar el botón
  y verificar que la app se relanza y envía la alerta. Buscar en consola los logs
  `[MK] launched from state restoration` y `[MK] didRestoreState: re-auth success`.

## Archivos modificados

- `ios/Podfile.lock` (commit del SDK)
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/MkButtoniOSService.swift`
