import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onDone(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        _buildPage(
          title: "Real-time Tracking",
          body: "Keep track of your child's location in real-time on a modern map interface.",
          icon: Icons.location_on_rounded,
          color: const Color(0xFF6366F1),
        ),
        _buildPage(
          title: "Safe Boundaries",
          body: "Set up virtual geofences and get instant alerts if your child leaves the safe zone.",
          icon: Icons.shield_rounded,
          color: const Color(0xFF10B981),
        ),
        _buildPage(
          title: "Instant SOS",
          body: "Children can trigger emergency alerts with physical buttons, notifying you instantly.",
          icon: Icons.emergency_rounded,
          color: const Color(0xFFF43F5E),
        ),
      ],
      onDone: () => _onDone(context),
      onSkip: () => _onDone(context),
      showSkipButton: true,
      skip: const Text("Skip", style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Get Started", style: TextStyle(fontWeight: FontWeight.w700)),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Colors.grey.withOpacity(0.3),
        activeSize: const Size(22.0, 10.0),
        activeColor: Theme.of(context).colorScheme.primary,
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }

  PageViewModel _buildPage({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    return PageViewModel(
      title: title,
      body: body,
      image: Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 100, color: color)
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.5))
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.1, 1.1),
                duration: 1.5.seconds,
                curve: Curves.easeInOut,
              ).then().scale(
                begin: const Offset(1.1, 1.1),
                end: const Offset(0.8, 0.8),
                duration: 1.5.seconds,
                curve: Curves.easeInOut,
              ),
        ),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        bodyTextStyle: TextStyle(fontSize: 18, color: Colors.grey),
        imagePadding: EdgeInsets.only(top: 40),
        pageColor: Colors.white,
      ),
    );
  }
}
