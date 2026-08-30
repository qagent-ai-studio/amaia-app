import 'dart:async';

import 'package:amaia/db/database_helper.dart';
import 'package:amaia/models/information.dart';
import 'package:amaia/pages/check_step_phone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClosePage extends StatelessWidget {
  const ClosePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: SafeArea(child: _Close()),
      ),
    );
  }
}

class _Close extends StatefulWidget {
  const _Close();

  @override
  State<_Close> createState() => _CloseState();
}

class _CloseState extends State<_Close> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () async {
      Information? infoAlive;
      final DatabaseHelper dbHelper = DatabaseHelper();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active', '0');
      await prefs.remove('phone');
      await prefs.remove('name');

      final List<Map<String, dynamic>> tableAlive = await dbHelper.getItems();

      if (tableAlive.isNotEmpty) {
        infoAlive = Information.fromMap(tableAlive[0]);
        await dbHelper.updateItem(infoAlive.id, {
          'id': infoAlive.id,
          'name': 'alive',
          'value': 0,
        });
      }

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CheckPhoneStepPage()),
          (Route<dynamic> route) => false);
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
                  contentPadding: EdgeInsets.fromLTRB(15, 10, 25, 0)),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 51.0,
                    width: 51.0,
                    child: Center(
                        child: CircularProgressIndicator(color: Colors.grey)),
                  ),
                  Text('Cerrando cuenta ...',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)), // text
                ],
              ),
            ],
          )),
    );
  }
}
