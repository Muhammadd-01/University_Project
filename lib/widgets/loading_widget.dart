import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Yeh ek chota sa hissa (widget) hai jo tab dikhta hai jab app koi kaam kar rahi ho
// aur usko thora time lag raha ho (jaise data lana, login karna)
class LoadingWidget extends StatelessWidget {
  final String? message; // Jo text (paigham) loading ke sath dikhana hai
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Sirf utni jagah lo jitni zaroorat hai
        children: [
          // Gol chakra aur logo ko ek dusre ke upar rakhne ke liye Stack istemal kia
          Stack(
            alignment: Alignment.center, // Sab kuch bilkul darmian me rakho
            children: [
              // Bahar wala ruka hua (static) halka circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2), // Halka rang
                    width: 4,
                  ),
                ),
              ),
              // Ghoomne wala loading circle (Spinner)
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary, // Asal tez rang
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat())
               .rotate(duration: 2.seconds), // 2 second me ek chakkar poora karega
               
              // Darmian wala shield (dhaal) ka icon
              Icon(
                Icons.shield_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ).animate(onPlay: (controller) => controller.repeat())
               .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.5)) // Chamakna
               .scale( // Pehle 1 second me bara hoga
                 begin: const Offset(0.8, 0.8),
                 end: const Offset(1.1, 1.1),
                 duration: 1.seconds,
                 curve: Curves.easeInOut,
               ).then().scale( // Agle 1 second me wapas chota hoga (Dhak-dhak effect)
                 begin: const Offset(1.1, 1.1),
                 end: const Offset(0.8, 0.8),
                 duration: 1.seconds,
                 curve: Curves.easeInOut,
               ),
            ],
          ),
          
          // Agar message bheja gaya hai toh usko bhi dikhao
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0), // Aahista se oopar aayega
          ],
        ],
      ),
    );
  }
}
