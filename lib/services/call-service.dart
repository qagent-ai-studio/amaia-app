import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  Future<void> call({required String phoneNumber}) async {
    if (Platform.isAndroid) {
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
        if (!status.isGranted) {
          return Future.error('Permiso de llamada no concedido');
        }
      }

      AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$phoneNumber',
      );

      try {
        await intent.launch();
      } catch (error) {
        return Future.error(error);
      }
    } else {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );

      try {
        await launchUrl(launchUri);
      } catch (error) {
        print(error);
        return Future.error(error);
      }
    }
  }

  Future<String> checkCall() async {
    var status = await Permission.phone.status;

    if (Platform.isAndroid) {
      if (!status.isGranted) {
        status = await Permission.phone.request();
        if (!status.isGranted) {
          return Future.error('Permiso de llamada no concedido');
        }
      }
    }

    return 'Permiso validado correctamente';
  }
}
