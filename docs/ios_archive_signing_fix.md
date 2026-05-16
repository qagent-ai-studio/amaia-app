# iOS Archive — Resolución de errores de signing y CocoaPods

## Contexto

Al intentar hacer `flutter run` y luego `Product → Archive` en Xcode para el bundle ID `cl.mistatas.amaia.want`, se presentaron tres errores en secuencia.

---

## Error 1 — No provisioning profile found

### Mensaje
```
No profiles for 'cl.mistatas.amaia.want' were found: Xcode couldn't find any iOS App
Development provisioning profiles matching 'cl.mistatas.amaia.want'. Automatic signing
is disabled and unable to generate a profile. To enable automatic signing, pass
-allowProvisioningUpdates to xcodebuild.
```

### Causa
El Bundle ID fue cambiado de `cl.mistatas.amaia.want` (nuevo) y no existía ningún perfil de provisioning asociado. Cuando Flutter invoca `xcodebuild` desde la terminal, no pasa el flag `-allowProvisioningUpdates`, por lo que el signing automático no puede generar el perfil nuevo.

### Solución
1. Abrir `ios/Runner.xcworkspace` directamente en Xcode.
2. Seleccionar el target **Runner** → pestaña **Signing & Capabilities**.
3. Confirmar que **Automatically manage signing** está activado y el Team correcto (`4V8K9DVLAF`) está seleccionado.
4. Xcode genera el perfil automáticamente al conectarse con Apple.
5. Una vez resuelto en la UI, `flutter run` funciona con normalidad.

---

## Error 2 — Conflicto de signing al hacer Archive

### Mensaje
```
Runner has conflicting provisioning settings. Runner is automatically signed for
development, but a conflicting code signing identity Apple Distribution has been
manually specified. Set the code signing identity value to "Apple Development" in the
build settings editor, or switch to manual signing in the Signing & Capabilities editor.
```

### Causa
Se intentó cambiar manualmente `CODE_SIGN_IDENTITY` a `"Apple Distribution"` en la configuración Release del `project.pbxproj`, pensando que Archive lo requería. Pero con `CODE_SIGN_STYLE = Automatic`, Xcode gestiona el certificado internamente y rechaza cualquier valor manual que contradiga su flujo.

### Solución
Mantener `CODE_SIGN_IDENTITY = "Apple Development"` en todas las configuraciones (Debug, Release, Profile) cuando el signing es automático. Xcode selecciona el certificado de distribución por sí solo al momento del Archive.

Configuración correcta en `project.pbxproj` para el target Runner:
```
CODE_SIGN_IDENTITY = "Apple Development";
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = 4V8K9DVLAF;
```

---

## Error 3 — Framework 'Pods_Runner' not found

### Mensaje
```
Framework 'Pods_Runner' not found
Linker command failed with exit code 1 (use -v to see invocation)
```

### Causa
Los pods no estaban instalados o estaban desactualizados. Esto ocurre típicamente cuando:
- Se hace `flutter clean` sin reinstalar pods.
- Se cambia de rama y el `Podfile.lock` queda desincronizado.
- Se abre `Runner.xcodeproj` en vez de `Runner.xcworkspace`.

### Solución
Ejecutar la siguiente secuencia desde la raíz del proyecto:

```bash
flutter clean
flutter pub get
cd ios && rm -rf Pods Podfile.lock && pod install
```

Luego abrir siempre el workspace, nunca el proyecto directamente:

```bash
open ios/Runner.xcworkspace
```

En Xcode, limpiar el build antes de archivar:

**Product → Clean Build Folder (⇧⌘K)**

Finalmente: **Product → Archive**.

---

## Reglas generales para evitar estos problemas

| Situación | Acción correcta |
|---|---|
| Cambio de Bundle ID | Abrir Xcode → Signing & Capabilities y dejar que genere el perfil antes de usar terminal |
| Signing automático activo | Nunca especificar `CODE_SIGN_IDENTITY = "Apple Distribution"` manualmente |
| Abrir el proyecto en Xcode | Siempre usar `Runner.xcworkspace`, nunca `Runner.xcodeproj` |
| Después de `flutter clean` | Ejecutar `flutter pub get` + `pod install` antes de abrir Xcode |
| Build o Archive falla con Pods | Borrar `Pods/` y `Podfile.lock` y reinstalar con `pod install` |
