// location_service.dart - GPS se location lena
import 'package:geolocator/geolocator.dart';

// Ye class phone ke GPS se location nikalne aur doori (distance) napne ka kaam karti hai
class LocationService {
  // Permission check karna aur agar na ho toh user se maangna
  Future<bool> handlePermission() async {
    // Agar mobile ki apni Location Service (GPS) band hai
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    
    var perm = await Geolocator.checkPermission(); // Permission check karo
    if (perm == LocationPermission.denied) { // Agar inkaar kia hua hai
      perm = await Geolocator.requestPermission(); // Dobara ijazat maango
      if (perm == LocationPermission.denied) return false;
    }
    // Agar humesha ke liye band kar di hai permission
    return perm != LocationPermission.deniedForever;
  }

  // Abhi ki taza GPS location maloom karna
  Future<Position?> getCurrentLocation() async {
    try {
      if (!await handlePermission()) return null; // Bina ijazat ke wapas jao
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // Sab se behtareen (accurate) location chahiye
          timeLimit: Duration(seconds: 15), // 15 second tak intezar karo location milne ka
        ),
      );
    } catch (e) {
      // Agar kamre ya building ke andar hone ki wajah se taza location na mile (Timeout ho jaye)
      // Toh jo aakhri dafa location mili thi wahi wapas de do
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // Do jaghon (points) ke darmiyan kitna faasla hai (meters mein) napna
  double getDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // Check karna ke bacha apni hudood (Safe Zone) ke andar hai ya bahir nikal gaya hai
  bool isWithinBoundary(double lat, double lng, double bLat, double bLng, double radius) {
    final dist = getDistance(lat, lng, bLat, bLng); // Faasla nikalo
    return dist <= radius; // Agar faasla radius (hadd) se kam ya barabar hai, toh andar hai
  }
}
