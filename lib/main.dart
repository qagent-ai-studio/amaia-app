import 'dart:async';
import 'dart:io' show Platform;

import 'package:amaia/models/information.dart';
import 'package:amaia/pages/check_step_phone_page.dart';
import 'package:amaia/pages/close_page.dart';
import 'package:amaia/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';
import 'workmanagers/callback_dispatcher.dart';
import 'db/database_helper.dart';

const uniqueNamePeriodicTask = "com.amaia.alive.task.periodic";
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Timer? _timer;

Future main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: ".env");

  if (Platform.isIOS) {
    final prefs = await SharedPreferences.getInstance();
    final smsUrl = dotenv.env['URL_SMS_IOS'];
    if (smsUrl != null) await prefs.setString('URL_SMS_IOS', smsUrl);
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((value) => runApp(const NavigationApp()));

  Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false);

  Workmanager().registerPeriodicTask(
    uniqueNamePeriodicTask,
    uniqueNamePeriodicTask,
    tag: "amaiaPeriodicTasks",
    frequency: const Duration(hours: 4),

  );

  await checkAlive();

  if (_timer == null || !_timer!.isActive) {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await checkAlive();
    });
  }
}

Future checkAlive() async{
  final DatabaseHelper dbHelper = DatabaseHelper();
  final List<Map<String, dynamic>> alive = await dbHelper.getItems();

  if (alive.isNotEmpty) {
    var infoAlive = Information.fromMap(alive[0]);

    if (infoAlive.value == 2) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ClosePage()),
            (Route<dynamic> route) => false,
      );
    }
  }
  else{
    await dbHelper.insertItem({
      'name': 'alive',
      'value': 1,
    });
  }
}

class NavigationApp extends StatelessWidget {
  const NavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      navigatorKey: navigatorKey,
      home: const NavigationToHome(),
    );
  }
}

class NavigationToHome extends StatefulWidget {
  const NavigationToHome({super.key});

  @override
  State<NavigationToHome> createState() => _NavigationToHomeState();
}

class _NavigationToHomeState extends State<NavigationToHome> {
  String statusActive = '0';

  @override
  void initState() {
    super.initState();
    initialization();
  }

  void initialization() async {
    _getActiveFromStoreLocal();
    await Future.delayed(const Duration(seconds: 3));
    FlutterNativeSplash.remove();
  }

  Future<void> _getActiveFromStoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      statusActive = prefs.getString('active')!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: statusActive == '1' ? const HomePage() : const CheckPhoneStepPage(),
    );
  }
}
