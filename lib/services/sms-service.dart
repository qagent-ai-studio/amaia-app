import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Location Channel amaia/android/app/src/main/kotlin/com/mistatas/amaia/MainActivity.kt
const platformMainActivity = MethodChannel('com.mistatas.amaia.sms');

class SmsService {
  Future<String> sms(String geo, List<String> listRecipients) async {
    String msgError = '';

    if (Platform.isAndroid) {
      if (await Permission.sms.request().isGranted) {
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
        await Permission.sms.onDeniedCallback(() {
          msgError = 'onDeniedCallback';
        }).onGrantedCallback(() {
          msgError = 'onGrantedCallback';
        }).onPermanentlyDeniedCallback(() {
          msgError = 'onPermanentlyDeniedCallback';
        }).onRestrictedCallback(() {
          msgError = 'onRestrictedCallback';
        }).onLimitedCallback(() {
          msgError = 'onLimitedCallback';
        }).onProvisionalCallback(() {
          msgError = 'onProvisionalCallback';
        }).request();

        return Future.error(msgError);
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
      String msgError = '';
      if (await Permission.sms.request().isGranted) {
        return 'Permiso validado correctamente';
      } else {
        await Permission.sms.onDeniedCallback(() {
          msgError = 'Permiso denegado';
        }).onGrantedCallback(() {
          msgError = 'onGrantedCallback';
        }).onPermanentlyDeniedCallback(() {
          msgError = 'Permanentemente denegado';
        }).onRestrictedCallback(() {
          msgError = 'Permiso restrictivo';
        }).onLimitedCallback(() {
          msgError = 'Permiso limitado';
        }).onProvisionalCallback(() {
          msgError = 'Permiso provisional';
        }).request();

        return Future.error(msgError);
      }
    }

    return 'Permiso validado correctamente';
  }
}
