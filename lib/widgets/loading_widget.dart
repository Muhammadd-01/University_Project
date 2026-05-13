import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 4,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat())
               .rotate(duration: 2.seconds),
              Icon(
                Icons.shield_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ).animate(onPlay: (controller) => controller.repeat())
               .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.5))
               .scale(
                 begin: const Offset(0.8, 0.8),
                 end: const Offset(1.1, 1.1),
                 duration: 1.seconds,
                 curve: Curves.easeInOut,
               ).then().scale(
                 begin: const Offset(1.1, 1.1),
                 end: const Offset(0.8, 0.8),
                 duration: 1.seconds,
                 curve: Curves.easeInOut,
               ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }
}
