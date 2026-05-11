import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _checkAuth();
  }

  void _checkAuth() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Try to get user data from Firestore
        final data = await FirestoreService().getUser(user.uid);
        
        if (data != null && mounted) {
          // Save credentials for Native Background Panic Detection
          final prefs = await SharedPreferences.getInstance();
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
        // Gradient background - blue theme
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with white circle background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/logo.png', width: 80, height: 80),
              ),
            ),
            const SizedBox(height: 24),
            const Text('ChildGuard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Keep your child safe', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
