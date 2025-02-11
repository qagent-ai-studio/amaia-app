import 'dart:io';
import 'dart:convert';
import 'package:amaia/models/information.dart';
import 'package:amaia/services/sms-service.dart';
import 'package:http/http.dart' as http;
import 'package:amaia/models/alive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:amaia/db/database_helper.dart';
import 'package:intl/intl.dart';

var logger = Logger(
  printer: PrettyPrinter(
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

List<String> daysToExecuteFunction = ['Monday', 'Wednesday', 'Friday'];

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    print("Ejecutando tarea en segundo plano: $task");
    logger.i("Ejecutando tarea en segundo plano: $task");

    switch (task) {
      case Workmanager.iOSBackgroundTask:
        stderr.writeln("The iOS background fetch was triggered");
        break;
      case 'com.amaia.alive.task.periodic':
        await processPeriodicTask(task);
        break;
      default:
        print('sin tarea periodica');
        break;
    }

    return Future.value(true);
  });
}

Future<void> processPeriodicTask(String task) async {
  final DatabaseHelper dbHelper = DatabaseHelper();
  Alive? alive;
  Information? infoAlive;
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  String? phone = prefs.getString('phone');
  DateTime date = DateTime.now();

  bool isConnected = await hasInternetAccess();
  List<String> recipients =
      dotenv.env['LIST_RECIPIENTS_SMS_EMERGENCY']?.split(',') as List<String>;

  if (phone != null &&
      daysToExecuteFunction.contains(DateFormat.EEEE().format(date))) {
    if (isConnected) {
      var url = Uri.parse(dotenv.env['URL_CHECK_ALIVE'] as String);
      var headers = {'Content-Type': 'application/json'};
      var payload = jsonEncode(<String, String>{
        'phone': phone,
      });

      try {
        final response = await http.post(
          url,
          body: payload,
          headers: headers,
          encoding: Encoding.getByName("utf-8"),
        );

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          alive = Alive.fromJson(data);

          if (alive.status == '0') {
            final List<Map<String, dynamic>> tableAlive =
                await dbHelper.getItems();

            if (tableAlive.isNotEmpty) {
              infoAlive = Information.fromMap(tableAlive[0]);
              await dbHelper.updateItem(infoAlive.id, {
                'id': infoAlive.id,
                'name': 'alive',
                'value': 2,
              });
            }
          }
        }
      } catch (err) {
        logger.e(err);
        print("Error ejecutando tarea en segundo plano: $task :$err");
      }
    } else {
      try {
        await SmsService().smsFromCallbackDispatcher('ALIVEAPP', recipients);
      } catch (err) {
        logger.e(err);
      }
    }
  } else {
    logger.e("sin telefono");
  }
}

Future<bool> hasInternetAccess() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}
