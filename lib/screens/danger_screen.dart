import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class DangerScreen extends StatefulWidget {
  final String message;
  final String type; // 'panic' or 'boundary'

  const DangerScreen({super.key, required this.message, required this.type});

  @override
  State<DangerScreen> createState() => _DangerScreenState();
}

class _DangerScreenState extends State<DangerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Start continuous vibration for panic alerts
    if (widget.type == 'panic') {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        HapticFeedback.vibrate();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPanic = widget.type == 'panic';
    final bgColor = isPanic ? Colors.red : Colors.orange;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                isPanic ? Icons.warning_rounded : Icons.radar_rounded,
                size: 150,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isPanic ? 'DANGER: PANIC ALERT' : 'WARNING: BOUNDARY BREACH',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 10,
              ),
              child: const Text(
                'I AM RESPONDING',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'KEEP APP OPEN UNTIL CHILD IS SAFE',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
