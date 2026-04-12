import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:amaia/services/call-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amaia/services/geolocation-service.dart';
import 'package:amaia/services/sms-service.dart';
import 'package:vibration/vibration.dart';
import 'dart:developer';

class SendSmsPage extends StatelessWidget {
  const SendSmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff67e0a4),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: _SendSms(),
      ),
    );
  }
}

class _SendSms extends StatefulWidget {
  const _SendSms();

  @override
  State<_SendSms> createState() => _SendSmsState();
}

class _SendSmsState extends State<_SendSms>
    with SingleTickerProviderStateMixin {
  String phoneAgent = dotenv.env['RECIPIENTS_CALL_EMERGENCY'] as String;
  List<String> recipients =
      dotenv.env['LIST_RECIPIENTS_SMS_EMERGENCY']?.split(',') as List<String>;
  bool isButtonDisabled = false;
  bool statusSendAll = false;
  String _name = '';
  GeolocationService locationStream = GeolocationService();

  @override
  void initState() {
    super.initState();
    _getNameFromStoreLocal();
    callPeriodStream();
  }

  @override
  void dispose() {
    locationStream.stopLocationUpdates();
    super.dispose();
  }

  void callPeriodStream() async {
    try {
      await locationStream.requestLocationPermission();
      locationStream.pediodStreamGeo();
    } catch (error) {
      _alertSnackBar(type: 'error', msg: error.toString());
    }
  }

  _alertSnackBar({required String type, required String msg}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: type == 'success' ? Colors.green : Colors.red,
          content: Text(msg),
          duration: const Duration(milliseconds: 5000),
          width: 280.0, // Width of the SnackBar.
          padding: const EdgeInsets.symmetric(
              horizontal: 10, // Inner padding for SnackBar content.
              vertical: 15),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          elevation: 3,
        ),
      );
    }
  }

  Future<void> _getNameFromStoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name')!;
    });
  }

  Future<void> _playNotificationSoundAndVibrate() async {
    try {
      // Verificar si el dispositivo tiene vibración
      bool? hasVibrator = await Vibration.hasVibrator();

      if (hasVibrator == true) {
        // Patrón de vibración: vibrar, pausar, vibrar
        // [duración vibración, pausa, duración vibración]
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500],
          intensities: [0, 255, 0, 255],
        );
      }

      // Reproducir sonido de notificación del sistema usando HapticFeedback
      // Esto da feedback táctil y auditivo en dispositivos compatibles
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Si hay error con sonido o vibración, continuar sin interrumpir
      debugPrint('Error al reproducir sonido o vibración: $e');
    }
  }

  Future<void> _sendSMS() async {
    setState(() {
      statusSendAll = true;
      isButtonDisabled = true;
    });

    String geo = await locationStream.getNameFromStoreLocal();

    log('***************************************************************************************');
    log(geo);
    debugPrint('#################################################################################');
    debugPrint(geo);

    Codec<String, String> stringToBase64 = utf8.fuse(base64);

    String geoencoded = stringToBase64.encode(geo);

    try {
      await SmsService().sms(geoencoded, recipients);

      // Reproducir sonido y vibración al enviar SMS exitosamente
      await _playNotificationSoundAndVibrate();

      _alertSnackBar(type: 'success', msg: 'SMS de ayuda enviado con éxito!');
    } catch (error) {
      _alertSnackBar(type: 'error', msg: error.toString());
    }

    await Future.delayed(const Duration(seconds: 1));

    try {
      await CallService().call(phoneNumber: phoneAgent);
    } catch (error) {
      _alertSnackBar(type: 'error', msg: error.toString());
    }

    setState(() {
      statusSendAll = false;
      isButtonDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 1),
              Color.fromRGBO(219, 220, 243, 2.0)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            tileMode: TileMode.clamp),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10.0, 30.0, 10, 20),
        child: Column(
          children: [
            SizedBox(
              height: (MediaQuery.of(context).size.height - 200) * 0.50,
              child: ListView(
                children: [
                  Image.asset('assets/logo/logo.png', height: 20),
                  const SizedBox(height: 30),
                  Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        children: <TextSpan>[
                          const TextSpan(
                              text: 'Hola ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w300, fontSize: 18)),
                          TextSpan(
                              text: _name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blue)),
                        ],
                      )),
                  const SizedBox(height: 10),
                  const Text(
                    '¿Tienes una emergencia?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color.fromRGBO(120, 2, 197, 1),
                        fontSize: 25,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 5),
                  Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                              text: 'Haz clic en el botón ',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                  letterSpacing: -0.2)),
                          const TextSpan(
                              text: 'SOS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color.fromRGBO(120, 2, 197, 1),
                              )),
                          TextSpan(
                              text: ' para llamar ...',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                  letterSpacing: -0.2))
                        ],
                      ))
                ],
              ),
            ),
            Expanded(
              child: Transform.scale(
                scale: 1.4,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, // shape makes the circular button
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromRGBO(241, 47, 47, 1),
                        Color.fromRGBO(242, 76, 75, 1)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Color.fromRGBO(196, 193, 242, 0.6),
                          offset: Offset(0.0, 0.0),
                          blurRadius: 10.0,
                          spreadRadius: 12.0,
                          blurStyle: BlurStyle.inner)
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      //shadowColor: Colors.blue,
                      disabledBackgroundColor: Colors.black,
                      shape: const CircleBorder(
                          side: BorderSide(
                        width: 12,
                        color: Colors.white,
                      )),
                      padding: EdgeInsets.all(!statusSendAll ? 60 : 38),
                      shadowColor: Colors
                          .transparent, //specify the button's elevation color
                      elevation: 6.0, //buttons Material shadow
                    ),
                    onPressed: isButtonDisabled ? null : () => _sendSMS(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        !statusSendAll
                            ? const Icon(
                                Icons.call,
                                color: Colors.white,
                                size: 50.0,
                              )
                            : const SizedBox(
                                height: 51.0,
                                width: 51.0,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white)),
                              ),
                        Text(!statusSendAll ? 'SOS' : 'Llamando ...',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 18)), // text
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
