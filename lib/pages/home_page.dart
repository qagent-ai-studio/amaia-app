import 'package:amaia/pages/config_page.dart';
import 'package:amaia/pages/info_page.dart';
import 'package:amaia/pages/send_sms_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true),
            home: const Scaffold(
              body: _Home(),
            )));
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.support_agent),
            icon: Icon(Icons.support_agent),
            label: 'Ayuda',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.info_outline),
            icon: Icon(Icons.info),
            label: 'Información',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.info_outline),
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
      body: <Widget>[
        /// Home page
        const SendSmsPage(),

        /// Information Page
        const InfoPage(),

        /// Configuration Page
        const ConfigPage(),
      ][currentPageIndex],
    );
  }
}
