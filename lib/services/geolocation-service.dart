import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeolocationService {
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastUpdate;

  Future<String> getCurrentGeo() async {
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 500,
        timeLimit: const Duration(seconds: 20),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
          timeLimit: const Duration(seconds: 20),
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.fitness,
          distanceFilter: 100,
          pauseLocationUpdatesAutomatically: true);
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Location permissions are permanently denied, we cannot request permissions.';
    }

    Position position =
        await Geolocator.getCurrentPosition(locationSettings: locationSettings);

    String dataGeo = '${position.latitude},${position.longitude}';

    return dataGeo;
  }

  Future<String> getStreamGeo() async {
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
          timeLimit: const Duration(seconds: 20),
          intervalDuration: const Duration(seconds: 60),
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
                "Estamos obteniendo su ubicación, mientras se realiza la llamada.",
            notificationTitle: "Geolocalización en segundo plano",
            enableWakeLock: true,
          ));
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        timeLimit: const Duration(seconds: 20),
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 500,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Location permissions are permanently denied, we cannot request permissions.';
    }

    Stream<Position> stream =
        Geolocator.getPositionStream(locationSettings: locationSettings);

    try {
      await for (var data in stream) {
        return '${data.latitude},${data.longitude}';
      }
    } catch (e) {
      return 'SIN_GEO';
    }

    return 'SIN_GEO';
  }

  Future<String> checkGeo() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      return Future.error('Servicio GEO no habilitado');
    } else {
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Permiso denegado');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error('Permiso denegado permanentemente.');
      }

      return 'Permiso validado correctamente';
    }
  }

  Future<String> checkCurrentGeo() async {
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 500,
        timeLimit: const Duration(minutes: 15),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
          timeLimit: const Duration(minutes: 15),
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.fitness,
          distanceFilter: 500,
          pauseLocationUpdatesAutomatically: true);
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      return Future.error('Servicio GEO no habilitado');
    } else {
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Permiso denegado');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        return Future.error('Permiso denegado permanentemente.');
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings);

        setStoreLocalGeo(geo: '${position.latitude}, ${position.longitude}');

        return 'Coordenadas: ${position.latitude},${position.longitude}';
      } catch (error) {
        return Future.error(error.toString());
      }
    }
  }

  Future<void> setStoreLocalGeo({required String geo}) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('geo', geo);
  }

  Future<String> getNameFromStoreLocal() async {
    final prefs = await SharedPreferences.getInstance();
    String geo = prefs.getString('geo')!;

    return geo.isNotEmpty ? geo : 'SIN_GEO';
  }

  Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado permanentemente.');
      }
    }
  }

  void pediodStreamGeo() {
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
          //timeLimit: const Duration(seconds: 20),
          //intervalDuration: const Duration(seconds: 60),
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
                "Estamos obteniendo su ubicación para mantener la precisión en la llamada de ayuda.",
            notificationTitle: "Geolocalización en segundo plano",
            enableWakeLock: true,
          ));
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 20,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setStoreLocalGeo(geo: '${position.latitude}, ${position.longitude}');
    }, onError: (error) {});
  }

  void stopLocationUpdates() {
    _positionSubscription?.cancel();
  }
}
