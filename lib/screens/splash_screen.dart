import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  void _checkAuth() async {
    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      final prefs = await SharedPreferences.getInstance();
      final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

      if (!seenOnboarding) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Try to get user data from Firestore
        final data = await FirestoreService().getUser(user.uid);
        
        if (data != null && mounted) {
          // Save credentials for Native Background Panic Detection
          await prefs.setString('uid', user.uid);
          await prefs.setString('role', data['role']); // Save role for native service
          if (data['connectedTo'] != null) {
            await prefs.setString('parentId', data['connectedTo']);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(role: data['role'], uid: user.uid),
            ),
          );
          return; // Stop here if everything is successful
        }
      }

      // If user is null or data fetch failed, send to Login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint("Auth verification failed: $e");
      // Fallback to login screen on any error
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
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withBlue(200),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with animation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(
                Icons.shield_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ).animate()
             .fadeIn(duration: 800.ms)
             .scale(duration: 800.ms, curve: Curves.elasticOut)
             .shimmer(delay: 1200.ms, duration: 1500.ms),
            
            const SizedBox(height: 40),
            
            const Text(
              'ChildGuard',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ).animate()
             .fadeIn(delay: 400.ms, duration: 800.ms)
             .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 12),
            
            Text(
              'Keep your child safe, always',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w400,
              ),
            ).animate()
             .fadeIn(delay: 700.ms, duration: 800.ms)
             .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 60),
            
            // Custom premium loading indicator
            SizedBox(
              width: 50,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ).animate()
             .fadeIn(delay: 1000.ms)
             .scaleX(begin: 0, end: 1, duration: 1500.ms),
          ],
        ),
      ),
    );
  }
}

