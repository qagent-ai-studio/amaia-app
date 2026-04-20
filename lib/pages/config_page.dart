import 'package:amaia/services/background-service.dart';
import 'package:amaia/services/call-service.dart';
import 'package:amaia/services/geolocation-service.dart';
import 'package:amaia/services/sms-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:amaia/pages/ble_button/bloc/ble_button_bloc.dart';
import 'package:amaia/pages/ble_button/data/ble_button_repository.dart';
import 'package:amaia/pages/ble_button/presentation/scan_page.dart';

import 'dart:io' show Platform;

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: _Config(),
      ),
    );
  }
}

class _Config extends StatefulWidget {
  const _Config();

  @override
  State<_Config> createState() => _ConfigState();
}

class _ConfigState extends State<_Config> {
  bool statusSendLocation = false;

  _alertSnackBar({required String type, required String msg}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: type == 'success' ? Colors.green : Colors.red,
          content: Text(msg),
          duration: const Duration(milliseconds: 5000),
          width: 280.0,
          padding: const EdgeInsets.symmetric(
              horizontal: 10,
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
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => RepositoryProvider<BleButtonRepository>(
          create: (_) => BleButtonRepositoryImpl(),
          child: BlocProvider(
            create: (context) => BleButtonBloc(
              repository: context.read<BleButtonRepository>(),
            ),
            child: const ScanPage(),
          ),
        ),
      ),
    );
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
      _alertSnackBar(type: 'error', msg: 'Permiso denegado!');
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
              cardExecutive(),
            ],
          )),
    );
  }

  Card cardExecutive() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _callExecutive,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 92, 174, 246).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  color: Color.fromARGB(255, 7, 131, 226),
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de dispositivos',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Configura acá tus dispositivos BLE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFB0BEC5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
