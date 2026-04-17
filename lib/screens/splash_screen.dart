// ============================================
// splash_screen.dart - App ki pehli screen (Splash Screen)
// ============================================
// Jab user app kholte hai toh sabse pehle yeh screen dikhti hai
// Yeh screen 3 cheezein check karti hai:
// 1. Kya onboarding dekhi hai? (SharedPreferences se check)
//    - Nahi dekhi → Onboarding Screen pe bhejo
// 2. Kya user logged in hai? (Firebase Auth se check)
//    - Logged in hai → Home Screen pe bhejo
//    - Nahi hai → Login Screen pe bhejo

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // _checkAuth() - Onboarding, auth check karo aur redirect karo
  void _checkAuth() async {
    // 2 second wait karo taake splash screen dikhe
    await Future.delayed(const Duration(seconds: 2));

    // Step 1: Check karo onboarding dekhi hai ya nahi
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;

    if (!onboardingDone) {
      // Pehli baar app kholi hai - Onboarding dikhao
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
      return;
    }

    // Step 2: Firebase se current user check karo
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User logged in hai - role fetch karo aur Home pe bhejo
      final data = await FirestoreService().getUser(user.uid);
      if (data != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(role: data['role'], uid: user.uid),
          ),
        );
      }
    } else {
      // User logged in nahi hai - Login pe bhejo
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App ka logo dikhao (generated image)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 20),
            // App ka naam
            const Text(
              'ChildGuard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Loading indicator
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
