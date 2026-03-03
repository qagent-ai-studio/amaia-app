import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';

class BackGroundService {
  void disableBatteryOptimization() async {
    if (Platform.isAndroid) {
      // Inicia el intento para abrir la configuración de optimización de batería
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.amaia.alive.task.periodic', // Asegúrate de que el package sea el correcto
      );
      try {
        await intent.launch();
      } on PlatformException catch (e) {
        print("Error launching intent: $e");
      }
    }
  }

  Future<void> getTasksFromNative() async {
    if (Platform.isAndroid) {
      const platform = MethodChannel('com.mistatas.amaia.task');
      try {
        final tasks = await platform.invokeMethod<List>('getTasks');
        print("Tareas registradas: $tasks");
      } on PlatformException catch (e) {
        print("Error al obtener tareas: ${e.message}");
      }
    }
  }
}
