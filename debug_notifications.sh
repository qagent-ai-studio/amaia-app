#!/bin/bash

echo "========================================="
echo "  DIAGNÓSTICO DE NOTIFICACIONES - AMAIA"
echo "========================================="
echo ""
echo "Esperando eventos del botón BLE..."
echo "Presiona el botón y observa los logs aquí"
echo ""
echo "========================================="
echo ""

# Limpiar logs previos
adb logcat -c

# Monitorear logs filtrados por nuestra app
adb logcat | grep -E "(MkButtonBgService|NotificationManager|Notification)"
