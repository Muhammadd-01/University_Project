import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

// Yeh screen app khulte hi sab se pehle dikhti hai (Logo wali screen)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth(); // Screen khulte hi check karo user logged in hai ya nahi
  }

  // User ka status check karne wala function
  void _checkAuth() async {
    try {
      // 2.5 second ke liye screen ko roko taake logo ki animation puri ho jaye
      await Future.delayed(const Duration(milliseconds: 2500));
      
      // Phone ki memory se pucho ke kya user ne onboarding (tutorial) dekh liya hai?
      final prefs = await SharedPreferences.getInstance();
      final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

      // Agar tutorial nahi dekha toh wahan bhej do
      if (!seenOnboarding) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
        return; // Yahan se aagay mat jao
      }

      // Check karo ke Firebase mein koi user pehle se login toh nahi hai
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Agar user login hai, toh uski mazeed maloomat (role wagara) database se nikalo
        final data = await FirestoreService().getUser(user.uid);
        
        if (data != null && mounted) {
          // Native background panic service ke liye user ka data phone memory mein save karo
          await prefs.setString('uid', user.uid);
          await prefs.setString('role', data['role']); // Parent hai ya child
          if (data['connectedTo'] != null) {
            await prefs.setString('parentId', data['connectedTo']);
          }

          // Sab kuch set hai, direct Home Screen par le jao
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(role: data['role'], uid: user.uid),
            ),
          );
          return; // Sab theek ho gaya, rukk jao
        }
      }

      // Agar user login nahi hai ya database se data nahi mila, toh Login screen dikhao
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint("Auth verification failed: $e");
      // Agar internet ka ya koi aur error aa jaye toh by default login par bhej do
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
          // Background par halka sa gradient (rangon ka milap)
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
            // Shield wala Logo aur uski animation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                // Logo ke peeche naram sa saya (glow)
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
             .fadeIn(duration: 800.ms) // Aahista se namoodar hona
             .scale(duration: 800.ms, curve: Curves.elasticOut) // Jhatke se bada hona
             .shimmer(delay: 1200.ms, duration: 1500.ms), // Chamakna
            
            const SizedBox(height: 40),
            
            // App ka naam (ChildGuard)
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
             .slideY(begin: 0.3, end: 0), // Neeche se upar aana
            
            const SizedBox(height: 12),
            
            // Slogan
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
            
            // Choti si safaid line jo loading dikhati hai
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
             .scaleX(begin: 0, end: 1, duration: 1500.ms), // Dheere dheere lambi hona
          ],
        ),
      ),
    );
  }
}

