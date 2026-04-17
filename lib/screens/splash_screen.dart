// ============================================
// splash_screen.dart - App ki pehli screen (Splash Screen)
// ============================================
// Jab user app kholte hai toh sabse pehle yeh screen dikhti hai
// Yeh screen 2 kaam karti hai:
// 1. ChildGuard ka logo aur naam dikhati hai (2 second ke liye)
// 2. Check karti hai user pehle se logged in hai ya nahi
//    - Agar logged in hai → Home Screen pe bhejti hai
//    - Agar nahi hai → Login Screen pe bhejti hai
// StatefulWidget hai kyunke initState mein async kaam karna hai

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Jaise hi screen load ho, auth check shuru karo
    _checkAuth();
  }

  // _checkAuth() - Check karo user logged in hai ya nahi aur redirect karo
  void _checkAuth() async {
    // 2 second wait karo taake splash screen dikhe (UX ke liye)
    await Future.delayed(const Duration(seconds: 2));

    // Firebase se current user check karo
    // Agar user pehle login kar chuka hai toh currentUser null nahi hoga
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User logged in hai!
      // Ab Firestore se uska role fetch karo (parent ya child)
      final data = await FirestoreService().getUser(user.uid);
      if (data != null && mounted) {
        // mounted check karo - agar screen abhi bhi active hai toh navigate karo
        // (agar user ne screen band kar di ho toh navigate nahi karna chahiye)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(role: data['role'], uid: user.uid),
          ),
        );
      }
    } else {
      // User logged in nahi hai, Login Screen pe bhejo
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple splash screen UI
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center mein rakho
          children: [
            // Shield icon - safety ka symbol
            Icon(Icons.shield, size: 80, color: Colors.blue),
            SizedBox(height: 20), // 20 pixel ka gap
            // App ka naam
            Text(
              'ChildGuard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            // Loading indicator dikhao jab tak check ho raha hai
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
