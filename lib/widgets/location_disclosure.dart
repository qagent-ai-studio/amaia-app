import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amaia/main.dart' show navigatorKey;

class LocationDisclosure {
  static const String prefsKey = 'location_disclosure_accepted';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  static Future<bool> ensureAccepted({BuildContext? context}) async {
    if (await isAccepted()) return true;

    final BuildContext? ctx = context ?? navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;

    final bool accepted = await _show(ctx);
    if (accepted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, true);
    }

    return accepted;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static Future<bool> _show(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) => const _LocationDisclosureDialog(),
    );

    return result ?? false;
  }
}

class _LocationDisclosureDialog extends StatelessWidget {
  const _LocationDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.location_on_rounded,
              color: Color.fromRGBO(20, 111, 182, 1.0), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Amaia recopila datos de ubicación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amaia recopila datos de ubicación precisa (GPS) para determinar dónde te encuentras cuando activas una alerta de emergencia, ya sea desde la aplicación o desde el botón Bluetooth vinculado, y para detectar y vincular ese botón Bluetooth cuando está cerca de tu teléfono.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 12),
            Text(
              'Estos datos se recopilan y se usan incluso cuando la aplicación está cerrada o no se está usando, para que la alerta pueda enviar tu ubicación en cualquier momento.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 12),
            Text(
              'Tu ubicación se comparte por SMS con los contactos de emergencia que registres y con la central de monitoreo de Amaia, únicamente para atender la emergencia. No se usa con fines publicitarios ni se vende a terceros.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 12),
            Text(
              'Puedes rechazar este acceso ahora y revocarlo en cualquier momento desde Ajustes del sistema > Aplicaciones > Amaia > Permisos. Si lo rechazas, la alerta de emergencia se enviará sin tu ubicación.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'No permitir',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(20, 111, 182, 1.0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Aceptar y continuar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
