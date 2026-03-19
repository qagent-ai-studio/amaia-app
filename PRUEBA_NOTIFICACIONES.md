# 🧪 GUÍA DE PRUEBA: Notificaciones del Botón BLE

## ✅ Cambios Aplicados

1. ✅ Agregados **logs detallados** en `showSMSSentNotification()`
2. ✅ Verificación de existencia del canal de notificaciones
3. ✅ Logs en creación del canal ALERT
4. ✅ App compilada e instalada en dispositivo

---

## 📱 PASO 1: Verificar Permisos de Notificación

### En el dispositivo Android:

1. Ve a **Configuración** → **Aplicaciones** → **Amaia**
2. Toca en **Notificaciones**
3. Verifica que:
   - ✅ **"Mostrar notificaciones"** esté ACTIVADO
   - ✅ Busca el canal **"MK Button Emergencias"**
   - ✅ Si existe, verifica que esté habilitado
   - ✅ Verifica que **NO esté en "Silencio"**

**Si el canal no existe o está deshabilitado:**
- Desinstala completamente la app
- Reinstala desde `flutter install`
- Vuelve a verificar

---

## 📋 PASO 2: Monitorear Logs en Tiempo Real

### Opción A: Usar el script de diagnóstico

En tu terminal, ejecuta:

```bash
cd /Users/danilovasquezrivera/DEV/APPS/app_amaia
./debug_notifications.sh
```

Esto mostrará SOLO los logs relevantes filtrados.

### Opción B: Ver todos los logs

```bash
adb logcat | grep MkButtonBgService
```

---

## 🔘 PASO 3: Probar el Botón BLE

1. **Asegúrate de que el servicio BLE esté activo:**
   - Abre la app Amaia
   - Ve a la sección de configuración del botón BLE
   - Conecta el botón MK Button
   - Verifica que aparezca la notificación: **"MK Button Activo - Conectado"**

2. **Cierra la app completamente:**
   - Desliza desde la parte inferior (o botón de apps recientes)
   - Desliza la app hacia arriba para cerrarla
   - La notificación **"MK Button Activo"** debe seguir visible

3. **Presiona el botón BLE físico:**
   - Presiona el botón según el tipo configurado (simple/doble)
   - Observa los logs en la terminal

---

## 🔍 PASO 4: Analizar los Logs

Busca estos mensajes en los logs:

### ✅ **LOGS ESPERADOS (Todo funciona bien):**

```
D/MkButtonBgService: Click received: single, configured: single
D/MkButtonBgService: Executing button action: sms
D/MkButtonBgService: Sending emergency SMS to: +56994633411
D/MkButtonBgService: Using location from SharedPreferences
D/MkButtonBgService: Emergency SMS sent successfully with location: -33.xxxx, -70.xxxx
D/MkButtonBgService: Immediate vibration triggered
D/MkButtonBgService: ===== showSMSSentNotification called =====
D/MkButtonBgService: Location info: 📍 Ubicación: Lat -33.xxxx, Lon -70.xxxx
D/MkButtonBgService: Emergency phone: +56994633411
D/MkButtonBgService: Building notification with channel: mk_button_alerts
D/MkButtonBgService: Notification built successfully
D/MkButtonBgService: Alert channel exists: true
D/MkButtonBgService: Alert channel importance: 4
D/MkButtonBgService: Notification posted with ID: 1001
```

### ❌ **LOGS DE PROBLEMAS:**

**Problema 1: Canal no existe**
```
D/MkButtonBgService: Alert channel exists: false
E/MkButtonBgService: ALERT_CHANNEL_ID not found! Creating it now...
D/MkButtonBgService: Creating ALERT notification channel: mk_button_alerts
```
**Solución:** El código ahora crea el canal automáticamente si no existe.

**Problema 2: No hay teléfono configurado**
```
W/MkButtonBgService: No emergency phone configured
```
**Solución:** Configura el número de emergencia en la app.

**Problema 3: Error al enviar SMS**
```
E/MkButtonBgService: Failed to send emergency SMS
```
**Solución:** Verifica permisos de SMS y cobertura de red.

**Problema 4: Canal tiene importancia baja**
```
D/MkButtonBgService: Alert channel importance: 2
```
**Solución:** El usuario desactivó las notificaciones importantes. Ve a Configuración → Notificaciones.

---

## 🐛 PASO 5: Problemas Comunes y Soluciones

### **Problema: Solo vibra, pero NO aparece notificación**

**Causas posibles:**

1. **Canal de notificación deshabilitado por el usuario:**
   - Ve a Configuración → Apps → Amaia → Notificaciones
   - Verifica que "MK Button Emergencias" esté habilitado
   - Verifica que NO esté en modo "Silencio"

2. **Permisos de notificación no otorgados (Android 13+):**
   ```bash
   adb shell pm grant com.mistatas.amaia android.permission.POST_NOTIFICATIONS
   ```

3. **Do Not Disturb activado:**
   - El canal tiene `setBypassDnd(true)`, pero verifica que funcione
   - Desactiva temporalmente "No molestar" y prueba

4. **Samsung bloqueando notificaciones:**
   - Ve a Configuración → Aplicaciones → Amaia → Batería
   - Selecciona "Sin restricciones"

### **Problema: La notificación aparece pero se oculta inmediatamente**

**Causa:** El código restaura la notificación después de 10 segundos.

**Logs esperados:**
```
D/MkButtonBgService: Restoring normal notification after 10 seconds
```

Si quieres que dure más tiempo, edita esta línea en el código:
```kotlin
}, 10000)  // Cambiar a 30000 para 30 segundos
```

---

## 📊 PASO 6: Verificar Estado del Canal de Notificación

Ejecuta este comando para ver la configuración completa:

```bash
adb shell dumpsys notification --pkg com.mistatas.amaia
```

Busca la sección de canales y verifica:
- **Importance:** Debe ser 4 o 5 (IMPORTANCE_HIGH o IMPORTANCE_MAX)
- **Sound:** Debe tener un URI de sonido configurado
- **Vibration:** Debe estar habilitado

---

## ✅ RESULTADO ESPERADO

Cuando presionas el botón BLE:

1. ✅ **Vibración inmediata** (3 pulsos)
2. ✅ **Notificación visible** con:
   - Título: "✅ SMS de Emergencia Enviado"
   - Texto: "Mensaje enviado a +56994633411"
   - Ubicación GPS en el texto expandido
3. ✅ **Sonido de notificación** (tono de alarma)
4. ✅ **Notificación se mantiene visible** durante 10 segundos
5. ✅ Después de 10 segundos, vuelve a "MK Button Activo - Conectado"

---

## 🆘 Si Sigue Sin Funcionar

Envíame los logs completos ejecutando:

```bash
./debug_notifications.sh > logs_notificaciones.txt
```

Y comparte el archivo `logs_notificaciones.txt` para análisis detallado.

---

## 📝 Notas Importantes

- El SMS **SÍ se está enviando** aunque no veas la notificación (por eso vibra)
- La notificación es solo **confirmación visual** para el usuario
- Si ves vibración, significa que el código de envío de SMS funcionó
- El problema es solo con la **visibilidad de la notificación**
