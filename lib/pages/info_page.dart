import 'package:amaia/services/background-service.dart';
import 'package:amaia/services/call-service.dart';
import 'package:amaia/services/geolocation-service.dart';
import 'package:amaia/services/sms-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: _Info(),
      ),
    );
  }
}

class _Info extends StatefulWidget {
  const _Info();

  @override
  State<_Info> createState() => _InfoState();
}

class _InfoState extends State<_Info> {
  bool statusSendLocation = false;

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

  Future<void> _callExecutive() async {
    try {
      await CallService()
          .call(phoneNumber: dotenv.env['RECIPIENTS_CALL_EMERGENCY'] as String);
    } catch (error) {
      if (context.mounted) {
        _alertSnackBar(type: 'error', msg: 'Error en solicitud de llamada!');
      }
    }
  }

  Future<void> _showMyDialog(String origin) async {
    String statusOrigin = '';

    try {
      if (origin == 'CALL') {
        statusOrigin = await CallService().checkCall();
      } else if (origin == 'SMS') {
        statusOrigin = await SmsService().checkSms();
      } else {
        statusOrigin = await GeolocationService().checkGeo();
      }

      if (context.mounted) {
        showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                  title: const Text('Validador de Permiso'),
                  content: Text('$origin: $statusOrigin'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'OK'),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ));
      }
    } catch (error) {
      _alertSnackBar(
          type: 'error',
          msg: error is String ? error : 'Permiso denegado!');
    }
  }

  Future<void> _checkCurrentLocation() async {
    String check = '';

    setState(() {
      statusSendLocation = true;
    });

    try {
      check = await GeolocationService().checkCurrentGeo();
      if (context.mounted) {
        showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                  title: const Text('Resultado de verificación'),
                  content: Text(check),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'OK'),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ));
      }
    } catch (error) {
      _alertSnackBar(type: 'error', msg: error.toString());
    }

    setState(() {
      statusSendLocation = false;
    });
  }

  Future<void> _activeTask() async {
    try {
      await BackGroundService().getTasksFromNative();
    } catch (error) {
      _alertSnackBar(type: 'error', msg: 'Error en lista de tareas!');
    }
  }

  Future<void> _checkdisableBatteryOptimization() async {
    try {
      BackGroundService().disableBatteryOptimization();
    } catch (error) {
      _alertSnackBar(type: 'error', msg: 'Error en lista de tareas!');
    }
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
          padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
          child: ListView(
            children: <Widget>[
              Image.asset('assets/logo/logo.png', height: 20),
              const SizedBox(height: 10),
              Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    children: <TextSpan>[
                      const TextSpan(
                          text: 'V',
                          style: TextStyle(
                              color: Colors.black45,
                              fontSize: 15,
                              letterSpacing: -0.2)),
                      TextSpan(
                          text: dotenv.env['VERSION'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color.fromRGBO(120, 2, 197, 1),
                          ))
                    ],
                  )),
              const SizedBox(height: 20),
              const ListTile(
                contentPadding: EdgeInsets.fromLTRB(15, 10, 25, 0),
                subtitle: Text(
                  'Somos Mistatas, empresa líder en seguridad para las personas mayores. Te presentamos nuestra app AMAIA, la cual te contacta con toda tu red de apoyo frente a emergencias.',
                  textAlign: TextAlign.justify,
                ),
              ),
              cardExecutive(),
              cardPermissions(),
              cardCheckLocation()
            ],
          )),
    );
  }

  Card cardExecutive() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(15),
      elevation: 5,
      color: const Color.fromRGBO(105, 81, 193, 1.0),
      child: Column(
        children: <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.fromLTRB(15, 10, 25, 0),
            title: Text('Para hablar con un ejecutivo',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Para diferentes consultas, debe llamar al 32 2800 410 o al +56 9 5421 9767.',
                style: TextStyle(color: Colors.white)),
            leading: Icon(
              Icons.call,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () {
                  _callExecutive();
                },
                child: const Text('Llamar'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Card cardPermissions() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(15),
      elevation: 5,
      color: const Color.fromRGBO(0, 191, 238, 1),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(15, 10, 25, 0),
            title: const Text('Permisos requeridos',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold)),
            subtitle: Platform.isAndroid
                ? const Text(
                    'Esta aplicación, requiere de los permisos de Llamada, SMS y Geolocalización. Si no los tiene autorizados, no podrá enviar la alerta de emergencia correspondiente.\n Favor de validar los permisos y autorizarlos',
                    style: TextStyle(color: Colors.white))
                : const Text(
                    'Esta aplicación, requiere del permiso de Geolocalización. Si no lo tiene autorizado, no podrá enviar la alerta de emergencia correspondiente.\n Favor de validar el permiso y autorizarlo',
                    style: TextStyle(color: Colors.white)),
            leading: const Icon(
              Icons.settings,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisAlignment: Platform.isAndroid
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: <Widget>[
              if (Platform.isAndroid)
                TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                  ),
                  onPressed: () {
                    _showMyDialog('CALL');
                  },
                  child: const Text('Llamada'),
                ),
              TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () {
                  _showMyDialog('GEO');
                },
                child: const Text('Geolocalización'),
              ),
              if (Platform.isAndroid)
                TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                  ),
                  onPressed: () {
                    _showMyDialog('SMS');
                  },
                  child: const Text('SMS'),
                ),
            ],
          )
        ],
      ),
    );
  }

  Card cardCheckLocation() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(15),
      elevation: 5,
      color: const Color.fromRGBO(21, 163, 61, 1.0),
      child: Column(
        children: <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.fromLTRB(15, 10, 25, 0),
            title: Text('Verificar Geolocalización',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Prueba la geolocalización de tu dispositivo para calibrar proximidad.',
                style: TextStyle(color: Colors.white)),
            leading: Icon(
              Icons.location_pin,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors
                        .transparent, //specify the button's elevation color
                    elevation: 6.0, //buttons Material shadow
                  ),
                  onPressed: statusSendLocation
                      ? null
                      : () {
                          _checkCurrentLocation();
                        },
                  child: Row(children: <Widget>[
                    if (statusSendLocation)
                      const SizedBox(
                        height: 20.0,
                        width: 20.0,
                        child: Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                    const SizedBox(width: 10),
                    Text(!statusSendLocation ? 'Verificar' : 'Verificando ...',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white)),
                  ])),
            ],
          )
        ],
      ),
    );
  }

  Card cardBackground() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(15),
      elevation: 5,
      color: const Color.fromRGBO(0, 191, 238, 1),
      child: Column(
        children: <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.fromLTRB(15, 10, 25, 0),
            title: Text('Permisos requeridos',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Esta aplicación, requiere de los permisos de Llamada, SMS y Geolocalización. Si no los tiene autorizados, no podrá enviar la alerta de emergencia correspondiente.\n Favor de validar los permisos y autorizarlos',
                style: TextStyle(color: Colors.white)),
            leading: Icon(
              Icons.settings,
              color: Colors.white,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () {
                  _checkdisableBatteryOptimization();
                },
                child: const Text('Quitar optimización'),
              ),
              TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                ),
                onPressed: () {
                  _activeTask();
                },
                child: const Text('Tareas activas'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
