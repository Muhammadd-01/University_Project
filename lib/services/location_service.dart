// location_service.dart - GPS se location lena
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Permission check aur request
  Future<bool> handlePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    return perm != LocationPermission.deniedForever;
  }

  // Current GPS location lo
  Future<Position?> getCurrentLocation() async {
    if (!await handlePermission()) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // Do points ke beech distance (meters)
  double getDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
