import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

class LocationService {
  /// Current position, or throws [ApiException] with a user-friendly message.
  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiException('Please turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw ApiException('Location permission is needed to find a dealer near you.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw ApiException('Location permission is blocked. Enable it for this app in your phone settings.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw ApiException('Could not get your location. Please try again.');
    }
  }
}
