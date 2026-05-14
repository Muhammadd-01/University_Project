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

// Yeh background task handler hai jo app background mein hone ke bawajood chalta hai
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Local Notifications ko initialize kar rahe hain takay device par alert show kar sakein
    final nPlugin = FlutterLocalNotificationsPlugin();
    const aInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iSettings = InitializationSettings(android: aInit);
    await nPlugin.initialize(settings: iSettings);

    // 1. Background mein Firebase ko initialize kar rahe hain
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // 2. SharedPreferences se saved User ID (uid) aur Parent ID nikal rahe hain
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    final parentId = prefs.getString('parentId');
    
    // Agar user logged in hai (uid aur parentId mojood hain)
    if (uid != null && parentId != null) {
      final locService = LocationService();
      final fsService = FirestoreService();
      
      // 3. Bacche ki current location le rahe hain
      final pos = await locService.getCurrentLocation();
      if (pos != null) {
        // Firestore par location update kar rahe hain takay parents live track kar sakein
        await fsService.updateLocation(uid, pos.latitude, pos.longitude);
        
        // 4. Safe zones check kar rahe hain (Boundary logic)
        final zones = await fsService.getSafeZones(parentId);
        if (zones.isNotEmpty) {
          bool isInsideAny = false;
          double minDistance = double.infinity;
          
          // Har safe zone ke mutabiq check kar rahe hain ke baccha andar hai ya bahar
          for (final zone in zones) {
            final isInside = locService.isWithinBoundary(pos.latitude, pos.longitude, zone['lat'], zone['lng'], zone['radius']);
            if (isInside) {
              isInsideAny = true;
              break;
            }
            final dist = locService.getDistance(zone['lat'], zone['lng'], pos.latitude, pos.longitude);
            if (dist < minDistance) minDistance = dist;
          }

          // Agar baccha kisi bhi safe zone mein nahi hai, toh alert send karo
          if (!isInsideAny) {
            await fsService.sendAlert('boundary', uid, parentId, 
              '⚠️ Child is outside all safe zones! Closest zone: ${minDistance.toStringAsFixed(0)}m');
            
            // Bacche ko phone par local notification show karwa rahe hain
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
    return Future.value(true); // Task kamyabi se mukammal ho gaya
  });
}

// App ka main starting point
void main() async {
  // Flutter binding ko initialize kar rahe hain
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase ko app start hotay hi initialize kar rahe hain
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // App ko sirf portrait mode (seedha) mein lock kar rahe hain takay UI kharab na ho
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Background tasks ke liye Workmanager ko start kar rahe hain
  Workmanager().initialize(callbackDispatcher);
  
  // App ko run kar rahe hain
  runApp(const ChildGuardApp());
}

// Yeh app ki main root widget hai
class ChildGuardApp extends StatelessWidget {
  const ChildGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChildGuard',
      // Debug banner ko hata rahe hain (top right kone se)
      debugShowCheckedModeBanner: false,
      // App ka main theme aur colors define kar rahe hain
      theme: ThemeData(
        useMaterial3: true, // Material 3 UI design use kar rahe hain
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo color
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981), // Emerald (Greenish) color
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
        ),
        // Modern Google font (Outfit) apply kar rahe hain poori app par
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        // Sab buttons ka consistent style (Design) define kar rahe hain
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Gol corners
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
        // Cards (boxes) ka style
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1), // Halki si border
          ),
        ),
        // Input fields (Text fields) ka style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.withOpacity(0.05), // Halka grey background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none, // Border nahi chahiye
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5), // Jab type karein toh border nazar aye
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
      // App start hone par sabse pehle SplashScreen show hogi
      home: const SplashScreen(),
    );
  }
}