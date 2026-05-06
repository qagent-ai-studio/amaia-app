# Manual de Usuario — TAG MokoSmart en iOS
## App Amaia

---

## Requisitos previos

- iPhone con iOS 14.0 o superior
- Bluetooth activado
- TAG MokoSmart BXP-B-D con batería CR2032 instalada
- App Amaia instalada

---

## 1. Permisos necesarios

Al abrir la app por primera vez, iOS solicitará los siguientes permisos. **Deben aceptarse todos** para el correcto funcionamiento del TAG.

| Permiso | Para qué se usa |
|---|---|
| **Bluetooth** | Detectar, conectar y comunicarse con el TAG |
| **Notificaciones** | Mostrar alertas cuando se presiona el botón |

### Cómo otorgar los permisos manualmente (si fueron rechazados)

1. Abra **Ajustes** en su iPhone
2. Desplácese hasta encontrar **App Amaia**
3. Toque la app y active:
   - **Bluetooth** → activado
   - **Notificaciones** → activado

---

## 2. Vincular el TAG por primera vez

### Paso 1 — Encender el TAG
Presione el botón del TAG durante **3 segundos** hasta que el LED parpadee. El dispositivo queda en modo de búsqueda durante aproximadamente 30 segundos.

### Paso 2 — Abrir la app y escanear
1. Abra la app Amaia
2. En la pantalla principal, toque el botón **"Escanear"** (parte inferior) o el ícono de radar (esquina superior derecha)
3. La app comenzará a buscar dispositivos BLE cercanos

### Paso 3 — Seleccionar el TAG
1. Aparecerá en la lista el dispositivo **"MK Button"**
2. Si hay varios dispositivos, acérquese al TAG que desea vincular y seleccione el de mayor señal (RSSI)
3. Toque el dispositivo para iniciar la conexión

### Paso 4 — Ingresar contraseña
- La contraseña por defecto es **`123456`**
- Si fue configurada previamente con otra contraseña, ingrésela en este paso

### Paso 5 — Conexión exitosa
Una vez conectado, la app mostrará automáticamente la pantalla de información del dispositivo con:
- Porcentaje de batería
- Estado: **Conectado**
- Opciones de configuración y registros

---

## 3. Pantalla de información del dispositivo

| Sección | Descripción |
|---|---|
| **Batería** | Porcentaje actual. Use el ícono ↺ para actualizar manualmente |
| **Información del dispositivo** | Nombre, versión de firmware y hardware |
| **Registros** | Historial de pulsaciones del botón con fecha y hora |
| **Configurar permisos** | Verificar el estado de los permisos de la app |

---

## 4. Funcionamiento en segundo plano

### Comportamiento según el estado de la app

| Estado de la app | TAG funciona | Observaciones |
|---|---|---|
| App abierta en pantalla | ✅ Sí | Comportamiento completo |
| App en segundo plano (botón Home) | ✅ Sí | iOS despierta la app al detectar el botón |
| App completamente cerrada | ❌ No | Limitación de iOS — ver sección 5 |
| Bluetooth desactivado | ❌ No | Debe activarse en Ajustes |

### Cómo dejar la app en segundo plano correctamente

1. Con la app abierta y el TAG conectado, presione el **botón Home** del iPhone (o deslice hacia arriba en iPhone sin botón Home)
2. La app queda suspendida en memoria — el TAG sigue activo
3. **No deslice la app hacia arriba en el task switcher** para cerrarla

> **Importante:** iOS despertará la app automáticamente (~10 segundos) cuando el TAG envíe una señal al presionar el botón. Durante ese tiempo se envía la alerta y se muestra la notificación.

---

## 5. Limitación importante — App completamente cerrada

A diferencia de Android, **iOS no permite servicios BLE activos cuando el usuario cierra manualmente la app** desde el task switcher (multitarea).

### Por qué ocurre esto

iOS no dispone de servicios persistentes en segundo plano para apps de terceros. Cuando la app es terminada por el usuario, el proceso se elimina completamente y el Bluetooth deja de ser monitoreado.

### Cómo evitarlo

- Siempre use el **botón Home** para salir de la app, nunca deslice para cerrarla
- Si cierra la app por error, vuelva a abrirla para restablecer la conexión

> Esta es una limitación del sistema operativo iOS, no de la app ni del hardware del TAG.

---

## 6. Presionar el botón TAG

### Tipos de pulsación

| Tipo | Cómo hacerlo |
|---|---|
| **Pulsación simple** | Presionar y soltar rápidamente |
| **Pulsación doble** | Dos presiones rápidas consecutivas |
| **Pulsación larga** | Mantener presionado por 3 segundos |

> El tipo de pulsación configurado para activar la alerta depende de la configuración de la cuenta.

### ¿Qué ocurre al presionar?

1. El LED del TAG parpadea confirmando la acción
2. La app detecta la pulsación (aunque esté en segundo plano)
3. Se envía el SMS de alerta al número configurado
4. Aparece una notificación en el iPhone confirmando el envío

### Intervalo mínimo entre pulsaciones

El sistema tiene un intervalo mínimo de **2 segundos** entre pulsaciones para evitar envíos duplicados. Pulsaciones dentro de ese intervalo serán ignoradas.

---

## 7. Reconexión automática

Si el TAG pierde la conexión (por distancia, batería baja o reinicio del TAG), la app intentará reconectarse automáticamente siempre que:

- La app esté en segundo plano (no cerrada)
- El Bluetooth esté activado
- El TAG esté encendido y dentro del rango (~30 metros)

No es necesario realizar ninguna acción manual. Si la reconexión no ocurre, abra la app y vuelva a escanear.

---

## 8. Batería del TAG

- La batería CR2032 tiene una duración estimada de **6 a 12 meses** según el uso
- Reemplácela cuando baje del **20%**
- El porcentaje se actualiza automáticamente al conectar el TAG y manualmente con el botón ↺

> **Nota:** Puede haber una diferencia de hasta ±9% entre la lectura de iOS y Android para el mismo dispositivo. Esto es normal y se debe a la naturaleza de la batería CR2032, cuya curva de voltaje es muy plana en el rango 70–90%.

---

## 9. Desvincular el TAG

1. Abra la app Amaia
2. En la pantalla principal, mantenga presionado el dispositivo guardado
3. Seleccione **"Eliminar dispositivo"**
4. El TAG queda disponible para vincularse nuevamente desde otro teléfono

---

## 10. Verificar permisos desde la app

1. Conecte el TAG y acceda a la pantalla del dispositivo
2. Toque **"Configurar Permisos"**
3. Verifique que **Notificaciones** esté activo
4. Si algún permiso falta, tóquelo para ir directamente a los ajustes del sistema

---

## 11. Solución de problemas

| Problema | Solución |
|---|---|
| El TAG no aparece en el escaneo | Active el Bluetooth. Acerque el TAG al iPhone y enciéndalo presionando 3 segundos |
| El TAG aparece pero no conecta | Verifique la contraseña. Apague y encienda el TAG |
| El botón no envía alertas con app en segundo plano | Asegúrese de haber usado el botón Home y no haber cerrado la app |
| No llega la notificación de alerta | Verifique que las notificaciones estén habilitadas en Ajustes → App Amaia |
| La batería muestra 0% | Toque el ícono ↺ en la pantalla del dispositivo para actualizar |
| La app se desconecta sola | El TAG puede estar fuera de rango o con batería baja. Verifique ambos |

---

## 12. Consideraciones de uso

- Mantenga el iPhone con batería suficiente y Bluetooth activo durante el uso del TAG
- No cierre la app manualmente si necesita que el TAG esté operativo
- Si el iPhone se reinicia, vuelva a abrir la app para restablecer la conexión con el TAG
- En zonas con mucha interferencia Bluetooth (centros comerciales, eventos masivos), el alcance puede reducirse

---

*Manual técnico — App Amaia / TAG MokoSmart BXP-B-D / iOS*
