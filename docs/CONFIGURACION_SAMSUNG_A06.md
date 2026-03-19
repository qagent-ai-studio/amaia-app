# 📱 Configuración de Amaia en Samsung A06 (Android 15 / One UI 8.0)

## ✅ Solución Confirmada para Botón de Emergencia BLE

**Fecha de descubrimiento:** 12 de marzo de 2026  
**Dispositivo probado:** Samsung A06 (Android 15, One UI 8.0)  
**Estado:** ✅ **FUNCIONA COMPLETAMENTE**

---

## 🎯 Resumen Ejecutivo

El botón de emergencia BLE **SÍ funciona correctamente** en Samsung A06 con Android 15 (One UI 8.0) cuando se configura adecuadamente. No se requieren modificaciones en el código ni soluciones complejas como CompanionDeviceManager.

**Funcionalidades confirmadas:**
- ✅ Envío de SMS con ubicación GPS desde app cerrada
- ✅ Llamada telefónica automática desde app cerrada
- ✅ Vibración de confirmación
- ✅ Servicio BLE activo en segundo plano 24/7

---

## 📋 Configuración Obligatoria (Paso a Paso)

### **REQUISITO 1: Actualizar a One UI 8.0**

**¿Por qué?**  
One UI 7.x y versiones anteriores **bloquean completamente** las llamadas desde background sin excepciones. One UI 8.0 introduce un nuevo sistema de permisos que permite apps de emergencia.

**Cómo actualizar:**
1. Ve a **Configuración** → **Actualización de software**
2. Toca **Descargar e instalar**
3. Si dice "One UI 8.0 disponible", instálala
4. Reinicia el dispositivo

**Verificar versión:**
- **Configuración** → **Acerca del teléfono** → **Información de software**
- Busca: **Versión de One UI: 8.0** o superior

---

### **REQUISITO 2: Activar "Mostrar sobre otras apps"**

**¿Por qué?**  
Este permiso (`SYSTEM_ALERT_WINDOW`) le indica a Samsung que Amaia es una app de confianza que puede:
- Realizar llamadas de emergencia desde background
- Mostrar alertas críticas
- Operar cuando la app está cerrada

**Pasos:**

1. Ve a **Configuración** → **Aplicaciones**
2. Busca y selecciona **Amaia**
3. Toca en el menú **⋮** (tres puntos) en la esquina superior derecha
4. Selecciona **Aplicaciones especiales** o **Acceso especial**
5. Busca **"Mostrar sobre otras apps"** o **"Aparecer encima"**
6. Busca **Amaia** en la lista
7. Activa el interruptor para **permitir**

**Verificación:**
- Debe aparecer como: **Amaia: Permitido** ✅

---

### **REQUISITO 3: Desactivar optimización de batería (Opcional pero recomendado)**

**¿Por qué?**  
Garantiza que el servicio BLE se mantenga activo 24/7 sin interrupciones.

**Pasos:**

1. Ve a **Configuración** → **Aplicaciones**
2. Selecciona **Amaia**
3. Toca **Batería**
4. Selecciona **Sin restricciones**

**Alternativa:**
1. Ve a **Configuración** → **Batería y cuidado del dispositivo**
2. Toca **Batería**
3. Toca el menú **⋮** → **Ajustes**
4. Busca **"Aplicaciones no monitoreadas"** o **"Optimización de batería"**
5. Cambia el filtro a **"Todas las aplicaciones"**
6. Busca **Amaia** y selecciona **No optimizar**

---

### **REQUISITO 4: Configurar permisos de notificación**

**¿Por qué?**  
Para recibir confirmación visual cuando se envía el SMS de emergencia.

**Pasos:**

1. Ve a **Configuración** → **Aplicaciones** → **Amaia**
2. Toca **Notificaciones**
3. Verifica que **"Mostrar notificaciones"** esté **ACTIVADO** ✅
4. Busca el canal **"MK Button Emergencias"**
5. Verifica que **NO esté en modo "Silencio"**
6. Configura como: **Alertas** o **Hacer sonido y mostrar**

---

## 🧪 Cómo Probar que Funciona

### **Prueba 1: Con app abierta**

1. Abre la app Amaia
2. Ve a la sección de botón BLE
3. Conecta el botón MK Button
4. Verifica que aparezca la notificación: **"MK Button Activo - Conectado"**
5. Presiona el botón físico
6. Debes recibir:
   - ✅ Vibración (3 pulsos)
   - ✅ SMS enviado al número de emergencia
   - ✅ Llamada telefónica iniciada

### **Prueba 2: Con app cerrada (CRÍTICA)**

1. Abre la app Amaia
2. Conecta el botón BLE
3. **Cierra completamente la app:**
   - Desliza desde abajo (botón de apps recientes)
   - Desliza Amaia hacia arriba para cerrar
   - Verifica que la notificación **"MK Button Activo"** siga visible
4. **Presiona el botón físico BLE**
5. Debes recibir:
   - ✅ Vibración inmediata (3 pulsos)
   - ✅ SMS enviado con ubicación GPS
   - ✅ **Llamada telefónica iniciada automáticamente** ⭐ (ESTO ES NUEVO)
   - ✅ Notificación de confirmación (si está configurada)

**Si la llamada NO se inicia:**
- Verifica que completaste el **REQUISITO 2** (Mostrar sobre otras apps)
- Verifica que estás en **One UI 8.0** o superior

---

## 🔍 Diagnóstico de Problemas

### **Problema 1: La llamada NO se inicia desde app cerrada**

**Síntomas:**
- El SMS sí se envía ✅
- La vibración funciona ✅
- Pero NO se abre el marcador telefónico ❌

**Solución:**
1. Verifica que el permiso **"Mostrar sobre otras apps"** esté activado
2. Verifica que estás en **One UI 8.0** (no funciona en 7.x)
3. Reinicia la app después de otorgar el permiso

**Comando de verificación (vía USB):**
```bash
adb shell appops get cl.mistatas.amaia SYSTEM_ALERT_WINDOW
```
Debe devolver: `SYSTEM_ALERT_WINDOW: allow`

---

### **Problema 2: El servicio BLE se detiene después de un tiempo**

**Síntomas:**
- El botón funciona al principio
- Después de horas, deja de responder
- La notificación "MK Button Activo" desaparece

**Solución:**
1. Configura **"Sin restricciones"** en Batería (REQUISITO 3)
2. Ve a **Configuración** → **Batería y cuidado del dispositivo** → **Memoria**
3. Toca **Aplicaciones no utilizadas** 
4. Asegúrate de que Amaia **NO esté en la lista de apps pausadas**

---

### **Problema 3: No aparece la opción "Mostrar sobre otras apps"**

**Síntomas:**
- No encuentras la opción en el menú de Amaia
- Aparece deshabilitada (gris)

**Solución:**
1. **Actualiza a One UI 8.0** (REQUISITO 1)
2. Reinicia el dispositivo
3. Intenta nuevamente después del reinicio
4. Si sigue sin aparecer, otorga el permiso vía USB:

```bash
adb shell appops set cl.mistatas.amaia SYSTEM_ALERT_WINDOW allow
```

---

### **Problema 4: Notificación de confirmación no aparece**

**Síntomas:**
- El SMS se envía ✅
- La llamada funciona ✅
- La vibración funciona ✅
- Pero NO aparece notificación de "SMS enviado" ❌

**Solución:**
1. Verifica el **REQUISITO 4** (Permisos de notificación)
2. Ve a **Configuración** → **Aplicaciones** → **Amaia** → **Notificaciones**
3. Busca el canal **"MK Button Emergencias"**
4. Verifica que:
   - Esté **activado** ✅
   - **NO esté en "Silencio"** 
   - Tenga configuración de **"Alertas"** o **"Hacer sonido"**

---

## 📊 Tabla de Compatibilidad

| Dispositivo | Versión Android | Versión One UI | ¿Funciona? | Requisitos |
|-------------|----------------|---------------|------------|------------|
| Samsung A06 | Android 15 | One UI 8.0 | ✅ **SÍ** | Req. 1, 2, 3, 4 |
| Samsung A06 | Android 14 | One UI 7.x | ❌ **NO** | Actualizar a One UI 8.0 |
| Huawei P20 Lite | Android 9 | EMUI 9.1 | ✅ **SÍ** | Solo Req. 3, 4 |
| Otros Android | Android 13+ | Stock Android | ✅ **Probablemente SÍ** | Req. 2, 3, 4 |

---

## 🎯 Conclusión

La solución para Samsung A06 (Android 15) es **SIMPLE y NO requiere cambios de código**:

**Fórmula ganadora:**
1. ✅ One UI 8.0 (actualización del sistema)
2. ✅ Permiso "Mostrar sobre otras apps" activado
3. ✅ Foreground Service activo (ya implementado en el código)

**NO se necesita:**
- ❌ CompanionDeviceManager
- ❌ WakeLock permanente
- ❌ Refactorización del código BLE
- ❌ Root ni modificaciones del sistema

---

## 📝 Checklist de Instalación para Usuario Final

Imprimir y entregar al beneficiario:

```
□ Actualizar Samsung A06 a One UI 8.0
□ Instalar app Amaia
□ Conectar botón BLE en la app
□ Ir a Configuración → Aplicaciones → Amaia → Menú ⋮ → Aplicaciones especiales
□ Activar "Mostrar sobre otras apps"
□ Ir a Configuración → Aplicaciones → Amaia → Batería
□ Seleccionar "Sin restricciones"
□ Ir a Configuración → Aplicaciones → Amaia → Notificaciones
□ Verificar que todo esté activado
□ Probar botón con app cerrada
□ Confirmar que se envía SMS + llamada
```

---

## 🆘 Soporte

Si después de seguir todos los pasos el botón NO funciona:
1. Captura pantalla de **Configuración → Aplicaciones → Amaia → Permisos**
2. Captura pantalla de **Configuración → Aplicaciones → Amaia → Batería**
3. Anota versión exacta: **Configuración → Acerca del teléfono → Información de software**
4. Contacta a soporte técnico con esta información

---

**Documento creado:** 12 de marzo de 2026  
**Última actualización:** 12 de marzo de 2026  
**Versión:** 1.0  
**Estado:** Solución confirmada y probada ✅
