# Manual de Usuario — TAG MokoSmart en Android
## App Amaia

---

## Requisitos previos

- Teléfono Android con Bluetooth 4.0 o superior
- Android 8.0 (Oreo) o superior
- TAG MokoSmart BXP-B-D con batería CR2032 instalada
- App Amaia instalada

---

## 1. Permisos necesarios

Al abrir la app por primera vez, se solicitarán los siguientes permisos. **Todos son obligatorios** para el correcto funcionamiento del TAG.

| Permiso | Para qué se usa |
|---|---|
| **Bluetooth** | Detectar y conectar el TAG |
| **Ubicación** | Requerido por Android para el escaneo BLE |
| **Notificaciones** | Mostrar alertas cuando se presiona el botón |
| **Ejecutar en segundo plano** | Mantener la conexión con el TAG aunque la app esté cerrada |

> **Importante:** En la configuración de la app, asegúrese de que el permiso de ubicación esté configurado como **"Permitir siempre"**, no solo "Mientras se usa la app".

---

## 2. Vincular el TAG por primera vez

### Paso 1 — Encender el TAG
Presione el botón del TAG durante **3 segundos** hasta que el LED parpadee. El dispositivo queda en modo de búsqueda.

### Paso 2 — Iniciar escaneo en la app
1. Abra la app Amaia
2. En la pantalla principal, toque el ícono de **radar** (esquina superior derecha)
3. La app comenzará a buscar dispositivos BLE cercanos

### Paso 3 — Seleccionar el TAG
1. Aparecerá una lista con los dispositivos encontrados
2. Identifique su TAG por el nombre **"MK Button"**
3. Toque el dispositivo para iniciar la vinculación

### Paso 4 — Ingresar contraseña
- La contraseña por defecto es **`123456`**
- Si el dispositivo fue configurado previamente con otra contraseña, ingrésela

### Paso 5 — Conexión exitosa
Una vez conectado, la app mostrará la pantalla de información del dispositivo con:
- Porcentaje de batería
- Estado de la conexión
- Opciones de configuración

---

## 3. Pantalla de información del dispositivo

Después de vincular el TAG, verá la siguiente información:

| Sección | Descripción |
|---|---|
| **Batería** | Porcentaje actual de la batería CR2032. Use el ícono ↺ para actualizar |
| **Información del dispositivo** | Nombre, firmware, hardware |
| **Registros** | Historial de pulsaciones del botón |
| **Configurar permisos** | Verificar que todos los permisos estén activos |

---

## 4. Funcionamiento en segundo plano

### ¿Cómo funciona?

A diferencia de iOS, en Android el TAG **sí funciona con la app completamente cerrada**. Esto es posible gracias a un **Servicio en Primer Plano** (Foreground Service) que corre de manera continua en el sistema.

Al vincularse por primera vez, la app activa automáticamente este servicio. Verá una notificación persistente en la barra de notificaciones que indica que el servicio está activo.

### Estados de la app y comportamiento del TAG

| Estado de la app | Funciona el TAG |
|---|---|
| App abierta | ✅ Sí |
| App en segundo plano (Home) | ✅ Sí |
| App completamente cerrada | ✅ Sí |
| Bluetooth desactivado | ❌ No |
| Teléfono apagado | ❌ No |

---

## 5. Optimización de batería — Configuración importante

Android puede detener el servicio en segundo plano para ahorrar batería. Para evitarlo:

### Samsung
1. Ajustes → Aplicaciones → App Amaia
2. Batería → **Sin restricciones**

### Xiaomi / MIUI
1. Ajustes → Aplicaciones → App Amaia
2. Ahorro de batería → **Sin restricciones**
3. Adicionalmente: Ajustes → Batería → Inicio de aplicaciones → App Amaia → **Gestión manual** → activar los tres interruptores

### Huawei
1. Ajustes → Aplicaciones → App Amaia
2. Inicio de aplicaciones → **Gestión manual** → activar "Ejecutar en segundo plano"

### Google Pixel / Android estándar
1. Ajustes → Aplicaciones → App Amaia
2. Batería → **Sin restricciones**

> **Recomendación general:** Abra la app Amaia, vaya a **"Configurar Permisos"** y siga las instrucciones para su modelo de teléfono.

---

## 6. Presionar el botón TAG

### Tipos de pulsación

| Tipo | Cómo hacerlo |
|---|---|
| **Pulsación simple** | Presionar y soltar rápidamente |
| **Pulsación doble** | Dos presiones rápidas consecutivas |
| **Pulsación larga** | Mantener presionado por 3 segundos |

> La app debe estar configurada con el tipo de pulsación que desea usar como alerta de emergencia.

### ¿Qué ocurre al presionar?

1. El LED del TAG parpadea confirmando la acción
2. La app detecta la pulsación (aunque esté cerrada)
3. Se envía el SMS de alerta al número configurado
4. Aparece una notificación en el teléfono confirmando el envío

---

## 7. Reconexión automática

Si el TAG pierde la conexión (por distancia, batería baja, reinicio del TAG), la app intentará **reconectarse automáticamente** en intervalos crecientes.

No es necesario hacer ninguna acción manual. Si la reconexión tarda más de lo esperado, puede abrir la app para forzar la reconexión.

---

## 8. Batería del TAG

- La batería CR2032 tiene una duración estimada de **6 a 12 meses** dependiendo del uso
- Cuando la batería baje de **20%**, se recomienda reemplazarla
- El porcentaje se actualiza cada vez que se conecta el TAG o al usar el botón ↺ en la app

---

## 9. Desvincular el TAG

1. Abra la app Amaia
2. En la pantalla principal, mantenga presionado el dispositivo guardado
3. Seleccione **"Eliminar dispositivo"**
4. El TAG queda disponible para vincularse nuevamente

---

## 10. Solución de problemas

| Problema | Solución |
|---|---|
| El TAG no aparece en el escaneo | Asegúrese de que el Bluetooth y la ubicación estén activados. Acerque el TAG al teléfono |
| El TAG aparece pero no conecta | Verifique la contraseña. Intente apagar y encender el TAG |
| El botón no envía alertas | Verifique los permisos de la app y la optimización de batería |
| La notificación del servicio desaparece | Android detuvo el servicio. Abra la app para reactivarlo |
| La batería del TAG muestra 0% | Toque el ícono ↺ en la pantalla del dispositivo para actualizar |

---

*Manual técnico — App Amaia / Proyecto MokoSmart TAG*
