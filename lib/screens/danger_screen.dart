import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/firestore_service.dart';


// Yeh screen tab show hoti hai jab emergency (panic ya boundary) alert aata hai
class DangerScreen extends StatefulWidget {
  final String message;
  final String type; // 'panic' or 'boundary'
  final String? alertId;

  const DangerScreen({super.key, required this.message, required this.type, this.alertId});

  @override
  State<DangerScreen> createState() => _DangerScreenState();
}

class _DangerScreenState extends State<DangerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller; // Icon ko bara chota karne wali animation ka controller
  late Animation<double> _scaleAnimation;
  Timer? _vibrationTimer; // Phone ko vibrate karwane ke liye timer
  static const _platform = MethodChannel('com.childguard.childguard/sms');


  @override
  void initState() {
    super.initState();
    // Animation controller banaya jo 0.5 sec mein complete hoga aur repeat hoga
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Icon ko apni size se 1.2x bara karna ka setup
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Agar alert panic (emergency) hai toh continuously vibrate shuru kar do
    if (widget.type == 'panic') {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        HapticFeedback.vibrate();
      });
    }
  }

  // Screen band hone par animation aur vibration ko rokna
  @override
  void dispose() {
    _controller.dispose();
    _vibrationTimer?.cancel();
    _platform.invokeMethod('stopVibration');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPanic = widget.type == 'panic';
    // Agar panic hai toh lal rang, warna boundary alert ke liye orange
    final bgColor = isPanic ? Colors.red : Colors.orange;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        // Background mein ek light sa gradient (shadow effect) dalna
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
            // Warning ka icon jo dhak dhak (scale) karega
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                isPanic ? Icons.warning_rounded : Icons.radar_rounded,
                size: 150,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            // Bada sa title
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
            // Jo message backend se aya hai wo dikhao
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
            // Parent ke respond karne ka button
            ElevatedButton(
              onPressed: () {
                _vibrationTimer?.cancel();
                _platform.invokeMethod('stopVibration');
                if (widget.alertId != null) {
                  FirestoreService().resolveAlert(widget.alertId!);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 10,
              ),
              child: const Text(
                'I AM RESPONDING',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _vibrationTimer?.cancel();
                _platform.invokeMethod('stopVibration');
                if (widget.alertId != null) {
                  FirestoreService().resolveAlert(widget.alertId!);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 5,
              ),
              child: const Text(
                'I AM COMING',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            // Hidayat
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
