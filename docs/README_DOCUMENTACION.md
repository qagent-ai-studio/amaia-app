# 📚 Documentación de Configuración - Amaia App

Este directorio contiene toda la documentación necesaria para la configuración de la app Amaia en los dispositivos de los usuarios finales.

---

## 📄 Documentos Disponibles

### 1. **GUIA_CONFIGURACION_USUARIOS.html** ⭐ DOCUMENTO PRINCIPAL
**Propósito:** Guía completa paso a paso para el personal técnico de Mistatas  
**Formato:** HTML (convertible a PDF)  
**Páginas:** 5 páginas  
**Contenido:**
- ✅ 8 pasos detallados con instrucciones específicas
- ✅ Requisitos por marca y modelo de dispositivo
- ✅ Configuración crítica para Samsung A06 (One UI 8.0)
- ✅ Solución de problemas comunes
- ✅ Checklist completo de verificación
- ✅ Sección de soporte técnico

**Cómo usar:**
1. Abrir en navegador web (Chrome, Safari, Firefox)
2. Imprimir a PDF: `Ctrl/Cmd + P` → Guardar como PDF
3. Distribuir al personal técnico
4. Seguir paso a paso durante instalación

---

### 2. **CHECKLIST_RAPIDO_CONFIGURACION.html** 📋 VERSIÓN COMPACTA
**Propósito:** Checklist imprimible de 1 página para llevar a campo  
**Formato:** HTML (convertible a PDF)  
**Páginas:** 1 página  
**Contenido:**
- ✅ Checklist resumido de todos los pasos
- ✅ Espacio para datos del beneficiario
- ✅ Espacio para firmas (técnico y beneficiario)
- ✅ Recordatorios críticos resaltados
- ✅ Pruebas obligatorias

**Cómo usar:**
1. Imprimir una copia por cada instalación
2. Marcar cada checkbox al completar el paso
3. Completar datos del dispositivo
4. Obtener firma del beneficiario
5. Archivar como evidencia de instalación correcta

---

### 3. **CONFIGURACION_SAMSUNG_A06.md** 📖 DOCUMENTACIÓN TÉCNICA
**Propósito:** Documentación técnica detallada del descubrimiento de la solución  
**Formato:** Markdown  
**Contenido:**
- ✅ Análisis técnico de One UI 8.0
- ✅ Explicación del permiso SYSTEM_ALERT_WINDOW
- ✅ Tabla de compatibilidad de dispositivos
- ✅ Diagnóstico técnico paso a paso
- ✅ Comandos ADB para verificación

**Cómo usar:**
- Lectura para equipo técnico avanzado
- Referencia para entender por qué funciona la solución
- Base de conocimiento interna

---

### 4. **ACTUALIZACION_REPORTE_SOLUCION_CONFIRMADA.md** 📊 REPORTE EJECUTIVO
**Propósito:** Actualización del reporte técnico original con la solución encontrada  
**Formato:** Markdown  
**Contenido:**
- ✅ Resumen ejecutivo de la solución
- ✅ Comparación: Propuesta CompanionDeviceManager vs. Solución Real
- ✅ Impacto en tiempo y presupuesto
- ✅ Decisión técnica final
- ✅ Próximos pasos

**Cómo usar:**
- Presentar al cliente (Mistatas)
- Justificar decisión de NO implementar CompanionDeviceManager
- Demostrar ahorro de tiempo (8-12 días)

---

## 🎯 Flujo de Uso Recomendado

### Para Personal Técnico (Instaladores):

1. **Antes de ir a campo:**
   - Leer `GUIA_CONFIGURACION_USUARIOS.html` completa
   - Imprimir varias copias de `CHECKLIST_RAPIDO_CONFIGURACION.html`
   - Llevar APK de Amaia actualizado
   - Llevar botones MK Button con baterías cargadas

2. **Durante la instalación:**
   - Usar `CHECKLIST_RAPIDO_CONFIGURACION.html` como guía
   - Marcar cada paso al completarlo
   - Si hay problemas, consultar `GUIA_CONFIGURACION_USUARIOS.html` (sección "Solución de Problemas")

3. **Después de la instalación:**
   - Completar datos del dispositivo en el checklist
   - Obtener firma del beneficiario
   - Archivar checklist como evidencia

### Para Equipo de Soporte Técnico:

1. **Cuando un usuario reporta problemas:**
   - Consultar `CONFIGURACION_SAMSUNG_A06.md` (sección "Diagnóstico de Problemas")
   - Verificar permisos usando comandos ADB documentados
   - Seguir soluciones paso a paso

2. **Para entender la solución técnica:**
   - Leer `ACTUALIZACION_REPORTE_SOLUCION_CONFIRMADA.md`
   - Entender por qué NO se necesita CompanionDeviceManager

---

## 🖨️ Cómo Convertir HTML a PDF

### Opción 1: Desde el Navegador (Recomendado)

1. Abrir el archivo HTML en Chrome, Safari o Firefox
2. Presionar `Ctrl + P` (Windows/Linux) o `Cmd + P` (Mac)
3. En "Destino", seleccionar **"Guardar como PDF"**
4. **IMPORTANTE:** En "Más opciones", activar **"Gráficos de fondo"** para ver colores y estilos
5. Click en "Guardar"

### Opción 2: Usando Terminal (Mac/Linux)

```bash
# Navegar al directorio de docs
cd /Users/danilovasquezrivera/DEV/APPS/app_amaia/docs

# Convertir GUIA_CONFIGURACION_USUARIOS.html a PDF
# Requiere tener instalado wkhtmltopdf
wkhtmltopdf GUIA_CONFIGURACION_USUARIOS.html GUIA_CONFIGURACION_USUARIOS.pdf

# Convertir CHECKLIST_RAPIDO_CONFIGURACION.html a PDF
wkhtmltopdf CHECKLIST_RAPIDO_CONFIGURACION.html CHECKLIST_RAPIDO_CONFIGURACION.pdf
```

### Opción 3: Herramientas Online

- https://www.ilovepdf.com/html_to_pdf
- https://cloudconvert.com/html-to-pdf

---

## 📊 Resumen de Configuración Crítica

### Para dispositivos Samsung (Android 15 / One UI 8.0):

| Configuración | Ubicación | Estado Requerido |
|---------------|-----------|------------------|
| **Versión One UI** | Configuración → Acerca del teléfono | **8.0 o superior** ⭐ |
| **Mostrar sobre otras apps** | Apps → Amaia → ⋮ → Apps especiales | **PERMITIDO** 🔴 |
| **Optimización batería** | Apps → Amaia → Batería | **Sin restricciones** |
| **Permisos de ubicación** | Apps → Amaia → Permisos | **Permitir siempre** |
| **Notificaciones** | Apps → Amaia → Notificaciones | **Activado** |

### Para otros dispositivos (Huawei, etc.):

| Configuración | Estado Requerido |
|---------------|------------------|
| **Optimización batería** | Sin restricciones |
| **Permisos de ubicación** | Permitir siempre |
| **Notificaciones** | Activado |

---

## ✅ Resultado Esperado

Cuando la configuración está completa, el botón de emergencia debe:

1. ✅ **Vibrar** inmediatamente (3 pulsos) al presionar el botón BLE
2. ✅ **Enviar SMS** con ubicación GPS al número configurado
3. ✅ **Iniciar llamada telefónica** automáticamente ⭐ (crítico en Samsung)
4. ✅ **Funcionar con app cerrada** (prueba más importante)
5. ✅ Mantener servicio BLE activo 24/7

---

## 🆘 Soporte

Si después de seguir toda la documentación el botón NO funciona:

**Recopilar:**
1. Captura de pantalla: Configuración → Aplicaciones → Amaia → Permisos
2. Captura de pantalla: Configuración → Aplicaciones → Amaia → Batería
3. Marca y modelo del dispositivo
4. Versión de Android y One UI (si es Samsung)

**Contactar:**
- Soporte técnico de Mistatas
- Adjuntar documentación de pasos realizados
- Adjuntar checklist completado

---

## 📌 Notas Importantes

### ⚠️ Crítico para Samsung:
- Sin **One UI 8.0**, el botón NO hará llamadas automáticas
- Sin permiso **"Mostrar sobre otras apps"**, el botón NO hará llamadas automáticas
- Estos dos requisitos son **OBLIGATORIOS** para Samsung A06

### ✅ Buenas noticias:
- NO se requieren cambios en el código de la app
- NO se necesita CompanionDeviceManager
- La solución actual funciona perfectamente con la configuración correcta
- Ahorro de 8-12 días de desarrollo

---

## 📅 Control de Versiones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 12/03/2026 | Documentación inicial completa |

---

## 👥 Audiencia

- **GUIA_CONFIGURACION_USUARIOS.html**: Personal técnico instalador
- **CHECKLIST_RAPIDO_CONFIGURACION.html**: Personal técnico en campo
- **CONFIGURACION_SAMSUNG_A06.md**: Equipo de soporte técnico
- **ACTUALIZACION_REPORTE_SOLUCION_CONFIRMADA.md**: Cliente (Mistatas), gerencia

---

**Última actualización:** 12 de marzo de 2026  
**Mantenido por:** Equipo de desarrollo Amaia  
**Estado:** ✅ Documentación completa y lista para uso
