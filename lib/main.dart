// ============================================
// main.dart - App ka entry point (shuruwat yahan se hoti hai)
// ============================================
// Yeh file app ki sabse pehli file hai jo run hoti hai
// Ismein hum Flutter ko initialize karte hain aur Firebase ko start karte hain
// Phir MaterialApp return karte hain jo poori app ko wrap karta hai

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire CLI se auto-generated file
import 'screens/splash_screen.dart';

// main() function - Dart mein sab se pehle yeh function chalta hai
void main() async {
  // Flutter ke widgets ko initialize karo (zaroori hai async operations se pehle)
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase ko start karo - DefaultFirebaseOptions mein saari config hai
  // yeh firebase_options.dart se aati hai jo flutterfire configure ne banaya
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ab app chalao - ChildGuardApp widget se shuruwat hogi
  runApp(const ChildGuardApp());
}

// ChildGuardApp - Yeh poori app ka root widget hai
// StatelessWidget hai kyunke iska state change nahi hota
class ChildGuardApp extends StatelessWidget {
  const ChildGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp - yeh Flutter ka main wrapper hai jo navigation, theme etc handle karta hai
    return MaterialApp(
      title: 'ChildGuard', // App ka title (recent apps mein dikhta hai)
      debugShowCheckedModeBanner: false, // Debug banner hatao (wo red color wali)
      theme: ThemeData(
        primarySwatch: Colors.blue, // Primary color blue rakhte hain
        useMaterial3: true, // Material Design 3 use karo (naya design)
      ),
      home: const SplashScreen(), // App kholne pe sabse pehle SplashScreen dikhega
    );
  }
}
