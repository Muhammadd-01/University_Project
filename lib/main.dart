import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
        final boundary = await fsService.getBoundary(parentId);
        if (boundary != null) {
          final isInside = locService.isWithinBoundary(pos.latitude, pos.longitude, boundary['lat'], boundary['lng'], boundary['radius']);
          if (!isInside) {
            final dist = locService.getDistance(boundary['lat'], boundary['lng'], pos.latitude, pos.longitude);
            await fsService.sendAlert('boundary', uid, parentId, 
              '⚠️ Child is outside safe zone! Distance: ${dist.toStringAsFixed(0)}m');
            
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
  
  // Initialize Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  
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
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        // Sab buttons ka consistent style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        // Cards ka style
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        // Input fields ka style
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}