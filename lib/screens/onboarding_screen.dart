// ============================================
// onboarding_screen.dart - Pehli Baar App Kholne Pe Dikhne Wali Screen
// ============================================
// Yeh screen sirf PEHLI BAAR dikhti hai jab user app install karke kholte hai
// Ismein 3 pages hain jo swipe karke dekh sakte hain:
// Page 1: App ka introduction - ChildGuard kya hai
// Page 2: Features - kya kya kar sakte hain
// Page 3: Shuru karo - Get Started button
//
// SharedPreferences mein save hota hai ke onboarding dekh liya
// Agla baar app kholne pe seedha Splash Screen pe jayega
// Skip button se bhi seedha login pe ja sakte hain

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // PageController - pages swipe karne ke liye
  final _pageController = PageController();
  int _currentPage = 0; // Abhi kaunsa page dikhta hai (0, 1, 2)

  // Onboarding pages ka data - har page ka icon, title, description
  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.shield,
      'title': 'ChildGuard',
      'description': 'Apne bachon ki safety ko track karo.\nReal-time location tracking aur alerts ke saath.',
      'color': Colors.blue,
    },
    {
      'icon': Icons.map_outlined,
      'title': 'Location Tracking',
      'description': 'Child ki location map pe dekho.\nSafe zone set karo aur boundary alerts pao.',
      'color': Colors.green,
    },
    {
      'icon': Icons.warning_amber_rounded,
      'title': 'Emergency Alerts',
      'description': 'Panic button se turant alert bhejo.\nPower button double press se bhi kaam karta hai.',
      'color': Colors.red,
    },
  ];

  // _completeOnboarding() - Onboarding khatam, ab app shuru
  // SharedPreferences mein save karo ke onboarding dekh li
  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    // 'onboarding_done' key ko true set karo
    // Agla baar splash_screen check karega yeh value
    await prefs.setBool('onboarding_done', true);

    if (mounted) {
      // Splash Screen pe navigate karo (jo phir login check karega)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== SKIP BUTTON (Top Right) =====
            // Sirf pehle 2 pages pe dikhega, last page pe nahi
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < _pages.length - 1
                  ? TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text('Skip', style: TextStyle(fontSize: 16)),
                    )
                  : const SizedBox(height: 48), // Spacing consistent rakhne ke liye
            ),

            // ===== PAGE VIEW (Swipe Pages) =====
            // PageView.builder swipeable pages banata hai
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                // Jab page change ho toh _currentPage update karo
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Page Icon - bada icon dikhao
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page['icon'],
                            size: 70,
                            color: page['color'],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Page Title
                        Text(
                          page['title'],
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Page Description
                        Text(
                          page['description'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ===== PAGE DOTS INDICATOR =====
            // 3 dots dikhao - current page wali dot badi hogi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8, // Active dot badi
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.blue : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ===== NEXT / GET STARTED BUTTON =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      // Next page pe jao (animation ke saath)
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      // Last page pe hai - onboarding khatam karo
                      _completeOnboarding();
                    }
                  },
                  // Last page pe "Shuru Karo" dikhao, baaki pe "Next"
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Shuru Karo',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
