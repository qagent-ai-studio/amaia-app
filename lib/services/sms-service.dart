import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const platformMainActivity = MethodChannel('com.mistatas.amaia.sms');

class SmsService {
  Future<String> sms(String geo, List<String> listRecipients) async {
    if (Platform.isAndroid) {
      final status = await _requestSmsPermission();

      if (status.isGranted) {
        try {
          final result = await platformMainActivity.invokeMethod('sendSMS', {
            'message': 'ALERTAMOVIL GEO=$geo ORIGIN=DIAL',
            'recipients': listRecipients,
          });

          return result.toString();
        } catch (e) {
          return Future.error("Error al enviar SMS: $e");
        }
      } else {
        return Future.error(_smsPermissionError(status));
      }
    } else if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('phone') ?? '';

      var url = Uri.parse(dotenv.env['URL_SMS_IOS'] as String);
      var headers = {'Content-Type': 'application/json'};
      var payload = jsonEncode(
          <String, String>{"phone": phone, "body": "ALERTAMOVIL ORIGIN=DIAL", "geo": geo});

      var response = await http.post(
        url,
        body: payload,
        headers: headers,
        encoding: Encoding.getByName("utf-8"),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return "ok";
      } else {
        return Future.error("error api ios");
      }
    } else {
      return "plataforma no válida";
    }
  }

  Future<String> smsFromCallbackDispatcher(
      String msg, List<String> listRecipients) async {
    if (Platform.isAndroid) {
      try {
        final result = await platformMainActivity.invokeMethod('sendSMS', {
          'message': msg,
          'recipients': listRecipients,
        });

        return result.toString();
      } catch (e) {
        return Future.error("Error al enviar SMS: $e");
      }
    } else {
      return 'ok';
    }
  }

  Future<String> checkSms() async {
    if (Platform.isAndroid) {
      final status = await _requestSmsPermission();

      if (status.isGranted) {
        return 'Permiso validado correctamente';
      } else {
        return Future.error(_smsPermissionError(status));
      }
    }

    return 'Permiso validado correctamente';
  }

  Future<PermissionStatus> _requestSmsPermission() async {
    final status = await Permission.sms.request();

    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }

    return status;
  }

  String _smsPermissionError(PermissionStatus status) {
    if (status.isPermanentlyDenied) {
      return 'El permiso de SMS fue denegado permanentemente. '
          'Actívalo en Ajustes > Permisos > SMS.';
    }

    if (status.isRestricted) {
      return 'El permiso de SMS está restringido por el sistema. '
          'Actívalo en Ajustes > Permisos > SMS.';
    }

    if (status.isLimited) {
      return 'El permiso de SMS fue otorgado de forma limitada.';
    }

    if (status.isProvisional) {
      return 'El permiso de SMS es provisional.';
    }

    return 'El permiso de SMS fue denegado.';
  }
}
