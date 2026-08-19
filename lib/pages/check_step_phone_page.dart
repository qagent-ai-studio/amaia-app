import 'dart:convert';
import 'dart:io' show Platform;
import 'package:amaia/pages/home_page.dart';
import 'package:amaia/services/call-service.dart';
import 'package:amaia/services/geolocation-service.dart';
import 'package:amaia/services/sms-service.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CheckPhoneStepPage extends StatelessWidget {
  const CheckPhoneStepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: _CheckPhoneStep(),
      ),
    );
  }
}

class _CheckPhoneStep extends StatefulWidget {
  const _CheckPhoneStep();

  @override
  State<_CheckPhoneStep> createState() => _CheckPhoneStepState();
}

class _CheckPhoneStepState extends State<_CheckPhoneStep> {
  PageController pageController = PageController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _validatePhone = false;
  bool _validateName = false;
  bool loadValidateNumber = false;
  Object textStatusPermission = {
    'CALL': 'Verificar',
    'SMS': 'Verificar',
    'GEO': 'Verificar'
  };
  final double sizeHeightBox = Platform.isAndroid ? 140 : 170;

  final _currentSelectedCountry = CountryWithPhoneCode(
      phoneCode: '56',
      countryCode: 'CL',
      exampleNumberMobileNational: '(2) 2123 4567',
      exampleNumberFixedLineNational: '(2) 2123 4567',
      phoneMaskMobileNational: '(0) 0000 0000',
      phoneMaskFixedLineNational: '(0) 0000 0000',
      exampleNumberMobileInternational: '+56 2 2123 4567',
      exampleNumberFixedLineInternational: '+56 2 2123 4567',
      phoneMaskMobileInternational: '+00 0 0000 0000',
      phoneMaskFixedLineInternational: '+00 0 0000 0000',
      countryName: 'Chile');

  @override
  void initState() {
    super.initState();
  }

  Future<void> _setPhoneFromStoreLocal(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('phone', phone);
  }

  Future<void> _setNameFromStoreLocal(String name) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('name', name);
  }

  Future<void> _setActiveStoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('active', '1');
  }

  Future<void> _showMyDialog(String origin) async {
    String statusOrigin = '';
    var textPermissions = textStatusPermission as Map<String, String>;

    setState(() {
      textPermissions[origin] = 'Verificando ...';
    });

    try {
      if (origin == 'CALL') {
        statusOrigin = await CallService().checkCall();
      } else if (origin == 'SMS') {
        statusOrigin = await SmsService().checkSms();
      } else {
        statusOrigin = await GeolocationService().checkCurrentGeo();
      }

      if (context.mounted) {
        showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => AlertDialog(
                  title: const Text('Validador de Permiso'),
                  content: Text('$origin: $statusOrigin'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          textPermissions[origin] = 'Verificado';
                        });
                        if (origin == 'CALL' || origin == 'SMS') {
                          Navigator.pop(context, 'OK');
                        } else {
                          await Future.delayed(const Duration(seconds: 1));
                          Navigator.of(context).push(_createRoute());
                        }
                      },
                      child: Text(origin == 'CALL' || origin == 'SMS'
                          ? 'Cerrar'
                          : 'Finalizar'),
                    ),
                  ],
                ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(error is String ? error : 'Permiso denegado!'),
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

      setState(() {
        textPermissions[origin] = 'Verificar';
      });
    }
  }

  Future<Null> _sendValidatorPhone(String phone) async {
    var parsePhone =
        phone.replaceAll(' ', '').replaceAll('(', '').replaceAll(')', '');

    if (parsePhone.isEmpty || parsePhone.length < 9) {
      setState(() {
        _validatePhone = true;
      });
    } else {
      setState(() {
        loadValidateNumber = true;
      });

      var url = Uri.parse(dotenv.env['URL_CHECK_PHONE'] as String);
      var headers = {'Content-Type': 'application/json'};
      var payload = jsonEncode(<String, String>{
        'phone': parsePhone,
      });

      var response = await http.post(
        url,
        body: payload,
        headers: headers,
        encoding: Encoding.getByName("utf-8"),
      );

      setState(() {
        loadValidateNumber = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: const Text('Número válido!'),
              duration: const Duration(milliseconds: 3000),
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

        _setPhoneFromStoreLocal(parsePhone);

        pageController.nextPage(
            duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
      } else if (response.statusCode == 403) {
        if (context.mounted) {
          showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text('Validador de Número'),
                    content:
                        const Text('Número no existe en nuestros registros!'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ));
        }
      } else {
        if (context.mounted) {
          showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text('Validador de Número'),
                    content: const Text(
                        'Error interno. Comuníquese con su admininstrador.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ));
        }
      }
    }
  }

  Widget _getWidgetIcon(String origin) {
    var textPermissions = textStatusPermission as Map<String, String>;

    if (textPermissions[origin] == 'Verificado') {
      return const Icon(
        Icons.check,
        color: Colors.white,
        size: 50.0,
      );
    } else if (textPermissions[origin] == 'Verificando ...') {
      return const SizedBox(
        height: 51.0,
        width: 51.0,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    } else {
      return Icon(
        origin == 'CALL'
            ? Icons.settings_phone
            : origin == 'SMS'
                ? Icons.sms
                : Icons.location_pin,
        color: Colors.white,
        size: 50.0,
      );
    }
  }

  double _getPadding(String origin) {
    var textPermissions = textStatusPermission as Map<String, String>;

    if (textPermissions[origin] == 'Verificado') {
      return 53.5;
    } else if (textPermissions[origin] == 'Verificando ...') {
      return 38;
    } else {
      return 60;
    }
  }

  Route _createRoute() {
    _setActiveStoreLocal();

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
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
        child: Stack(
          children: [
            PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: pageController,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 150,
                          child: ListView(
                            children: [
                              Image.asset('assets/logo/logo.png', height: 20),
                              const SizedBox(height: 30),
                              const Padding(
                                padding:
                                    EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 10),
                                child: Text(
                                  'Ingresa tu número de celular asociado a este dispositivo.',
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        Expanded(
                            child: Center(
                                child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.phone),
                                  labelText:
                                      'Ingrese los 9 dígitos de su número',
                                  errorText: _validatePhone
                                      ? "Valor debe ser 9 dígitos"
                                      : null,
                                  hintText: '999999999'),
                              controller: _phoneController,
                              inputFormatters: [
                                LibPhonenumberTextFormatter(
                                  phoneNumberType: PhoneNumberType.mobile,
                                  phoneNumberFormat: PhoneNumberFormat.national,
                                  country: _currentSelectedCountry,
                                  inputContainsCountryCode: true,
                                  shouldKeepCursorAtEndOfInput: true,
                                ),
                              ],
                              onChanged: (text) => {
                                setState(() {
                                  _validatePhone = text.isEmpty;
                                })
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextButton(
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _sendValidatorPhone(_phoneController.text);
                                  },
                                  child: loadValidateNumber
                                      ? const SizedBox(
                                          height: 18.0,
                                          width: 18.0,
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.white)),
                                        )
                                      : const Text('Validar')),
                            ),
                          ],
                        ))),
                        Container(
                          height: 10,
                        )
                      ],
                    )),
                Padding(
                    padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 130,
                          child: ListView(
                            children: [
                              Image.asset('assets/logo/logo.png', height: 20),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                        Expanded(
                            child: Center(
                                child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person),
                                labelText: 'Ingrese solo su nombre',
                                errorText: _validateName
                                    ? "Debe ingresar un nombre"
                                    : null,
                                hintText: '',
                              ),
                              controller: _usernameController,
                              onChanged: (text) => {
                                setState(() {
                                  _validateName = text.isEmpty;
                                })
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  if (_usernameController.text.isNotEmpty) {
                                    _setNameFromStoreLocal(
                                        _usernameController.text);

                                    pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        curve: Curves.easeIn);
                                  }
                                },
                                child: const Text('Siguiente'),
                              ),
                            ),
                          ],
                        ))),
                        Container(
                          height: 10,
                        )
                      ],
                    )),
                if (Platform.isAndroid)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: sizeHeightBox,
                            child: ListView(
                              children: [
                                Image.asset('assets/logo/logo.png', height: 20),
                                const SizedBox(height: 20),
                                const Text(
                                  'Esta APP requiere de los permisos de llamada telefónica para contactar a la central de ayuda. Favor de verificar y autorizar.',
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                              child: Center(
                            child: Transform.scale(
                              scale: 0.9,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape
                                      .circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.fromRGBO(214, 104, 239, 1.0),
                                      Color.fromRGBO(114, 89, 205, 1.0)
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Color.fromRGBO(196, 193, 242, 0.6),
                                        offset: Offset(0.0, 0.0),
                                        blurRadius: 10.0,
                                        spreadRadius: 12.0,
                                        blurStyle: BlurStyle.inner)
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,

                                    disabledBackgroundColor: Colors.black12,
                                    shape: const CircleBorder(
                                        side: BorderSide(
                                      width: 10,
                                      color: Color.fromRGBO(223, 221, 246, 0.6),
                                    )),
                                    padding:
                                        EdgeInsets.all(_getPadding('CALL')),
                                    shadowColor: Colors
                                        .transparent,
                                    elevation: 6.0,
                                  ),
                                  onPressed: (textStatusPermission as Map<
                                                  String, String>)['CALL'] ==
                                              'Verificando ...' ||
                                          (textStatusPermission as Map<String,
                                                  String>)['CALL'] ==
                                              'Verificado'
                                      ? null
                                      : () => _showMyDialog('CALL'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _getWidgetIcon('CALL'),
                                      Text(
                                          (textStatusPermission
                                              as Map<String, String>)['CALL']!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 18)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextButton(
                              onPressed: (textStatusPermission
                                          as Map<String, String>)['CALL'] !=
                                      'Verificado'
                                  ? null
                                  : () => pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      curve: Curves.easeIn),
                              child: const Text('Siguiente'),
                            ),
                          ),
                          Container(
                            height: 60,
                          )
                        ],
                      )),
                if (Platform.isAndroid)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: sizeHeightBox,
                            child: ListView(
                              children: [
                                Image.asset('assets/logo/logo.png', height: 20),
                                const SizedBox(height: 20),
                                const Text(
                                  'Esta APP requiere de los permisos de envío de SMS para notificar las emergencias. Favor de verificar y autorizar.',
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                              child: Center(
                            child: Transform.scale(
                              scale: 0.9,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape
                                      .circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.fromRGBO(27, 225, 82, 1.0),
                                      Color.fromRGBO(21, 163, 61, 1.0)
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Color.fromRGBO(196, 193, 242, 0.6),
                                        offset: Offset(0.0, 0.0),
                                        blurRadius: 10.0,
                                        spreadRadius: 12.0,
                                        blurStyle: BlurStyle.inner)
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,

                                    disabledBackgroundColor: Colors.black12,
                                    shape: const CircleBorder(
                                        side: BorderSide(
                                      width: 10,
                                      color: Color.fromRGBO(223, 221, 246, 0.6),
                                    )),
                                    padding: EdgeInsets.all(_getPadding('SMS')),
                                    shadowColor: Colors
                                        .transparent,
                                    elevation: 6.0,
                                  ),
                                  onPressed: (textStatusPermission as Map<
                                                  String, String>)['SMS'] ==
                                              'Verificando ...' ||
                                          (textStatusPermission as Map<String,
                                                  String>)['SMS'] ==
                                              'Verificado'
                                      ? null
                                      : () => _showMyDialog('SMS'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _getWidgetIcon('SMS'),
                                      Text(
                                          (textStatusPermission
                                              as Map<String, String>)['SMS']!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 18)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextButton(
                              onPressed: (textStatusPermission
                                          as Map<String, String>)['SMS'] !=
                                      'Verificado'
                                  ? null
                                  : () => pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      curve: Curves.easeIn),
                              child: const Text('Siguiente'),
                            ),
                          ),
                          Container(
                            height: 60,
                          )
                        ],
                      )),
                Padding(
                    padding: const EdgeInsets.fromLTRB(10.0, 40.0, 10, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: sizeHeightBox + 60,
                          child: ListView(
                            children: [
                              Image.asset('assets/logo/logo.png', height: 20),
                              const SizedBox(height: 20),
                              const Text(
                                'Amaia recopila datos de ubicación (GPS) para enviar tu posición a tus contactos de emergencia y a la central de monitoreo cuando activas una alerta, incluso cuando la aplicación está cerrada o no se está usando. Pulsa Verificar para conocer el detalle y autorizar.',
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                            child: Center(
                          child: Transform.scale(
                            scale: 0.9,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape
                                    .circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.fromRGBO(62, 201, 232, 1.0),
                                    Color.fromRGBO(20, 111, 182, 1.0)
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

                                  disabledBackgroundColor: Colors.black12,
                                  shape: const CircleBorder(
                                      side: BorderSide(
                                    width: 10,
                                    color: Color.fromRGBO(223, 221, 246, 0.6),
                                  )),
                                  padding: EdgeInsets.all(_getPadding('GEO')),
                                  shadowColor: Colors
                                      .transparent,
                                  elevation: 6.0,
                                ),
                                onPressed: (textStatusPermission as Map<String,
                                                String>)['GEO'] ==
                                            'Verificando ...' ||
                                        (textStatusPermission as Map<String,
                                                String>)['GEO'] ==
                                            'Verificado'
                                    ? null
                                    : () => _showMyDialog('GEO'),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _getWidgetIcon('GEO'),
                                    Text(
                                        (textStatusPermission
                                            as Map<String, String>)['GEO']!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 18)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                        Container(
                          height: 79,
                        )
                      ],
                    )),
              ],
            ),
            Container(
              alignment: const Alignment(0, 0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SmoothPageIndicator(controller: pageController, count: 4)
                ],
              ),
            )
          ],
        ));
  }
}
