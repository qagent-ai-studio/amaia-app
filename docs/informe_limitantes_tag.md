# Informe de Limitantes Técnicas — TAG MokoSmart BXP-B-D
## App Amaia — Android e iOS

**Fecha:** 2026-05-02
**Dispositivo:** MokoSmart BeaconXD Button (BXP-B-D)
**SDK:** MKBeaconXDButton (iOS) / MokoSupport-D (Android)

---

## 1. Funcionamiento en segundo plano

### Android

| Escenario | Estado | Observaciones |
|---|---|---|
| App abierta | ✅ Funciona | Comportamiento normal |
| App suspendida (Home) | ✅ Funciona | Foreground Service activo |
| App completamente cerrada | ✅ Funciona | Foreground Service persiste |
| Bluetooth desactivado | ❌ No funciona | Sin solución posible |
| Optimización de batería activa | ⚠️ Inestable | El fabricante puede matar el servicio |

**Mecanismo:** Android permite servicios en primer plano (Foreground Services) que persisten aunque el usuario cierre la app. La app Amaia usa este mecanismo para mantener la conexión BLE activa en todo momento.

**Limitante principal:** Los fabricantes de teléfonos (Samsung, Xiaomi, Huawei, Oppo, entre otros) aplican capas adicionales de optimización de batería que pueden interrumpir el servicio sin previo aviso. El usuario debe configurar manualmente la app como "Sin restricciones" en los ajustes de batería de su teléfono.

---

### iOS

| Escenario | Estado | Observaciones |
|---|---|---|
| App abierta | ✅ Funciona | Comportamiento normal |
| App suspendida (Home) | ✅ Funciona | CoreBluetooth + background mode activo |
| App completamente cerrada | ❌ No funciona | Proceso terminado por el sistema |
| Bluetooth desactivado | ❌ No funciona | Sin solución posible |

**Mecanismo:** iOS utiliza el background mode `bluetooth-central`, que permite a CoreBluetooth despertar la app brevemente (~10 segundos) cuando llega un evento BLE mientras la app está suspendida.

**Limitante principal:** iOS no dispone de un equivalente a los Foreground Services de Android. Cuando el usuario cierra la app manualmente (deslizando desde el task switcher), el proceso es terminado completamente y ningún servicio BLE puede continuar operando.

---

## 2. Limitante: App cerrada en iOS — Análisis técnico

Esta es la limitante más relevante del producto en iOS y fue analizada en profundidad durante el desarrollo.

### Mecanismo oficial de Apple: CoreBluetooth State Restoration

Apple dispone de un mecanismo llamado **State Restoration** que permite al sistema operativo relanzar una app en background cuando detecta un dispositivo BLE conocido. Los requisitos son:

1. Inicializar `CBCentralManager` con `CBCentralManagerOptionRestoreIdentifierKey`
2. Implementar el método delegado `centralManager(_:willRestoreState:)`
3. El background mode `bluetooth-central` debe estar habilitado (ya configurado en la app)

### Respuesta del proveedor MokoSmart

Se consultó directamente al proveedor si el SDK `MKBeaconXDButton` soporta State Restoration. La respuesta fue:

> *"Our SDK currently does not include this functionality, nor have we conducted in-depth research into it at this time."*

El proveedor confirmó que el SDK **no implementa State Restoration**, lo que imposibilita el funcionamiento con app cerrada usando las herramientas actuales.

### Alternativas evaluadas

| Alternativa | Evaluación |
|---|---|
| **WorkManager / BGTaskScheduler** | ❌ No apto. Estas herramientas ejecutan tareas periódicas según disponibilidad del sistema, no en tiempo real. No garantizan respuesta inmediata ante un evento BLE |
| **ADV Scanning mejorado** | ⚠️ Mejora la robustez con app suspendida, pero no resuelve el caso de app cerrada |
| **State Restoration propio** | ⚠️ Posible técnicamente, pero requiere construir un módulo CoreBluetooth paralelo al SDK del proveedor. Trabajo considerable sin garantía de estabilidad |
| **Arquitectura servidor + Push Notification** | ✅ Solución robusta pero requiere infraestructura externa. El TAG se conectaría a un gateway que envía push notifications independientemente del estado de la app |

### Conclusión iOS — App cerrada

> La app debe permanecer activa en background (botón Home) para garantizar el funcionamiento del TAG en iOS. Esta es una **limitación del sistema operativo iOS**, no de la implementación ni del hardware del TAG.

---

## 3. Limitante: Precisión de la batería

### Diferencia entre plataformas

Durante las pruebas se observó una diferencia de hasta 9 puntos porcentuales entre la lectura de batería en Android (72%) e iOS (81%) para el mismo dispositivo.

### Causa técnica

La batería CR2032 tiene una curva de descarga extremadamente plana en el rango 70–90%. Una diferencia de apenas **9.6 mV de voltaje** produce una brecha de 9 puntos porcentuales en la conversión a porcentaje.

| Porcentaje | Voltaje |
|---|---|
| 81% | 2.9183 V |
| 72% | 2.9087 V |
| **Diferencia** | **0.0096 V** |

**Factores que contribuyen:**
- Momento de lectura distinto (el radio BLE consume corriente al conectar)
- Temperatura ambiente
- Diferencias de interpolación en la tabla de conversión de cada SDK

### Decisión adoptada

Se decidió mantener el comportamiento actual en ambas plataformas, aceptando una variación de ±9% como tolerable para el contexto de uso del producto (alertas de emergencia).

---

## 4. Limitante: Detección del botón — Solo GATT vs ADV

### Situación inicial

La detección del botón dependía exclusivamente de una conexión GATT activa (característica AA08). Si la conexión GATT se interrumpía transitoriamente, el evento del botón se perdía.

### Mejora implementada

Se implementó detección paralela vía **ADV scanning**:
- El dispositivo se configura con "Alarm mode" y "Stay advertising before trigger"
- El TAG emite paquetes ADV con un bit de trigger cuando se presiona el botón
- La app detecta este bit via scanning, sin necesidad de conexión GATT activa

### Limitante residual

La detección ADV requiere que la app esté activa (suspendida o en primer plano). Si la app está completamente cerrada en iOS, el scanning se detiene y los paquetes ADV no son recibidos.

---

## 5. Limitante: Dependencia del fabricante del teléfono (Android)

### Problema

Los fabricantes de teléfonos Android aplican sus propias capas de optimización de batería que pueden interrumpir el Foreground Service de la app, incluso cuando el usuario lo ha configurado correctamente.

### Fabricantes con mayor restricción conocida

| Fabricante | Nivel de restricción | Configuración requerida |
|---|---|---|
| Xiaomi / MIUI | 🔴 Alto | Ajustes de inicio manual + batería sin restricciones |
| Huawei / EMUI | 🔴 Alto | Inicio de aplicaciones en gestión manual |
| Samsung OneUI | 🟡 Medio | Batería sin restricciones |
| Oppo / ColorOS | 🟡 Medio | Inicio automático habilitado |
| Google Pixel | 🟢 Bajo | Batería sin restricciones |

### Situación sin solución definitiva

No existe una solución técnica universal que garantice el funcionamiento en todos los fabricantes. El comportamiento depende de la versión de Android, el modelo del teléfono y las actualizaciones del sistema operativo del fabricante.

---

## 6. Limitante: Conexión Bluetooth — Dependencias del sistema

### Condiciones que interrumpen el servicio en ambas plataformas

| Condición | Android | iOS |
|---|---|---|
| Bluetooth desactivado por el usuario | ❌ Servicio detenido | ❌ Servicio detenido |
| Modo avión activado | ❌ Servicio detenido | ❌ Servicio detenido |
| Reinicio del teléfono | ⚠️ Reinicia automáticamente | ⚠️ Requiere abrir la app |
| Teléfono sin batería | ❌ Sin funcionamiento | ❌ Sin funcionamiento |
| TAG sin batería | ❌ Sin funcionamiento | ❌ Sin funcionamiento |
| Distancia mayor a ~30m | ⚠️ Conexión inestable | ⚠️ Conexión inestable |

---

## 7. Resumen comparativo

| Limitante | Android | iOS |
|---|---|---|
| App completamente cerrada | ✅ Funciona | ❌ No funciona |
| Optimización de batería del fabricante | ⚠️ Configurable por el usuario | N/A |
| Precisión de la batería (±9%) | Presente | Presente |
| Dependencia de conexión GATT | Mitigado con ADV | Mitigado con ADV |
| Reinicio del teléfono | ✅ Recupera automáticamente | ⚠️ Requiere abrir app |
| Soporte State Restoration SDK | N/A | ❌ No soportado por proveedor |

---

## 8. Recomendaciones para el usuario final

1. **No cerrar la app manualmente** en iOS. Usar el botón Home para dejarla en segundo plano.
2. **Configurar la app como "Sin restricciones"** en los ajustes de batería del teléfono (Android).
3. **Mantener el Bluetooth activado** en todo momento.
4. **Mantener la batería del TAG** por encima del 20%.
5. **Verificar periódicamente** que el servicio esté activo desde la sección "Configurar Permisos" dentro de la app.

---

*Documento técnico generado para el equipo de desarrollo y producto — App Amaia.*
