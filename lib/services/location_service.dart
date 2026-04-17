// ============================================
// location_service.dart - GPS Location ka kaam
// ============================================
// Yeh file Geolocator package use karke phone se GPS location leti hai
// Ismein 3 functions hain:
// 1. handlePermission() - location permission check aur request karo
// 2. getCurrentLocation() - abhi ki GPS location lo (lat, lng)
// 3. getDistance() - do points ke beech distance nikalo (meters mein)
//
// Geolocator package Android ke GPS sensor se baat karta hai
// Location lene ke liye user ki permission zaroori hai

import 'package:geolocator/geolocator.dart';

class LocationService {
  // handlePermission() - Location permission check aur request karo
  // Pehle check karta hai GPS on hai ya nahi
  // Phir permission check karta hai (allowed, denied, permanently denied)
  // true return karta hai agar permission mil gayi, false agar nahi mili
  Future<bool> handlePermission() async {
    // Step 1: Check karo phone ka GPS/Location service on hai ya nahi
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false; // GPS band hai, kaam nahi chalega

    // Step 2: Check karo app ko location permission di hai ya nahi
    LocationPermission permission = await Geolocator.checkPermission();

    // Agar permission denied hai (user ne abhi tak allow nahi kiya)
    if (permission == LocationPermission.denied) {
      // Permission request karo (popup aayega user ko)
      permission = await Geolocator.requestPermission();
      // Agar phir bhi deny kar diya toh false return karo
      if (permission == LocationPermission.denied) return false;
    }

    // Agar user ne permanently deny kar diya (Don't ask again)
    // Toh hum kuch nahi kar sakte, user ko settings mein jaana padega
    if (permission == LocationPermission.deniedForever) return false;

    return true; // Permission mil gayi, location le sakte hain!
  }

  // getCurrentLocation() - Phone ki current GPS location lo
  // Position object return karta hai jismein latitude aur longitude hoti hai
  // Agar permission nahi hai toh null return karega
  Future<Position?> getCurrentLocation() async {
    // Pehle permission check karo
    bool hasPermission = await handlePermission();
    if (!hasPermission) return null; // Permission nahi hai

    // GPS se current position lo
    // LocationAccuracy.high matlab GPS satellite se exact location lega
    // (kam accuracy mein cell tower se approximate location milti hai)
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // getDistance() - Do GPS points ke beech distance nikalo (meters mein)
  // Yeh boundary check karne ke liye use hota hai
  // Example: agar child 500m door hai aur boundary 300m hai, toh child bahar hai
  // Geolocator.distanceBetween() Earth ki curvature ko bhi consider karta hai
  double getDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
