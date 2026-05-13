import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/location_service.dart';
import 'services/firestore_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize Local Notifications
    final nPlugin = FlutterLocalNotificationsPlugin();
    const aInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iSettings = InitializationSettings(android: aInit);
    await nPlugin.initialize(settings: iSettings);

    // 1. Initialize Firebase in background
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // 2. Get saved UID
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    final parentId = prefs.getString('parentId');
    
    if (uid != null && parentId != null) {
      final locService = LocationService();
      final fsService = FirestoreService();
      
      // 3. Get current location
      final pos = await locService.getCurrentLocation();
      if (pos != null) {
        // Update location for live tracking
        await fsService.updateLocation(uid, pos.latitude, pos.longitude);
        
        // 4. Check Boundary
        final zones = await fsService.getSafeZones(parentId);
        if (zones.isNotEmpty) {
          bool isInsideAny = false;
          double minDistance = double.infinity;
          
          for (final zone in zones) {
            final isInside = locService.isWithinBoundary(pos.latitude, pos.longitude, zone['lat'], zone['lng'], zone['radius']);
            if (isInside) {
              isInsideAny = true;
              break;
            }
            final dist = locService.getDistance(zone['lat'], zone['lng'], pos.latitude, pos.longitude);
            if (dist < minDistance) minDistance = dist;
          }

          if (!isInsideAny) {
            await fsService.sendAlert('boundary', uid, parentId, 
              '⚠️ Child is outside all safe zones! Closest zone: ${minDistance.toStringAsFixed(0)}m');
            
            // Show Local Notification to Child
            const aDetails = AndroidNotificationDetails(
              'boundary_channel', 'Safe Zone Alerts',
              importance: Importance.max, priority: Priority.high,
              playSound: true,
            );
            await nPlugin.show(
              id: 100, 
              title: '⚠️ Safe Zone Alert', 
              body: 'You are outside the safe zone!', 
              notificationDetails: NotificationDetails(android: aDetails)
            );
          }
        }
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Lock to Portrait Mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Workmanager
  Workmanager().initialize(callbackDispatcher);
  
  runApp(const ChildGuardApp());
}

class ChildGuardApp extends StatelessWidget {
  const ChildGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChildGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981), // Emerald
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        // Sab buttons ka consistent style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
        // Cards ka style
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
        ),
        // Input fields ka style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}