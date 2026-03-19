#!/bin/bash

echo "========================================="
echo "   PRUEBA BOTÓN BLE - AMAIA"
echo "========================================="
echo ""
echo "📱 App instalada: cl.mistatas.amaia"
echo ""

# Limpiar logs anteriores
adb logcat -c

echo "✅ Logs limpiados"
echo ""
echo "🔘 Presiona el botón BLE ahora..."
echo "📋 Monitoreando logs en tiempo real..."
echo ""
echo "========================================="
echo ""

# Monitorear solo logs relevantes
adb logcat -s MkButtonBgService:*

