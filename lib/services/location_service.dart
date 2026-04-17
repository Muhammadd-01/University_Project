import 'package:geolocator/geolocator.dart';

// Location service - GPS se location lena
class LocationService {
  // Location permission check aur request
  Future<bool> handlePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // Current location lo
  Future<Position?> getCurrentLocation() async {
    bool hasPermission = await handlePermission();
    if (!hasPermission) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // Do points ke beech distance nikalo (meters mein)
  double getDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
