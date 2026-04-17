// ============================================
// panic_screen.dart - Panic Button Screen (Emergency Alert)
// ============================================
// Yeh screen SIRF child ke liye hai
// Is screen pe ek bada RED button hai - emergency ke liye
// Jab child button dabata hai:
// 1. Firestore se parent ki uid fetch hoti hai
// 2. "alerts" collection mein panic alert save hota hai
// 3. Confirmation dikhta hai ke alert bhej diya
//
// POWER BUTTON FEATURE (Android Only):
// - EventChannel se Android native code se events aate hain
// - Agar user power button 2 baar jaldi dabaye toh "DOUBLE_PRESS" event aata hai
// - Event aane pe automatically panic alert bhej diya jata hai
// - LIMITATION: Yeh sirf tab kaam karega jab app foreground mein ho
// - App kill hone pe power button detection band ho jayega

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // EventChannel ke liye
import '../services/firestore_service.dart';

class PanicScreen extends StatefulWidget {
  final String uid; // Child ki uid
  const PanicScreen({super.key, required this.uid});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  final _firestoreService = FirestoreService();
  bool _sending = false; // Alert bhej raha hai ya nahi
  bool _sent = false;    // Alert bhej diya ya nahi

  // EventChannel - Android native code se events sunne ke liye
  // Yeh channel name SAME hona chahiye jo MainActivity.kt mein hai
  static const _powerButtonChannel = EventChannel('com.childguard.childguard/power_button');

  @override
  void initState() {
    super.initState();
    // Power button ke events sunna shuru karo
    _listenPowerButton();
  }

  // _listenPowerButton() - Android se power button double press events suno
  // receiveBroadcastStream() se stream milti hai jo events deti hai
  // Jab "DOUBLE_PRESS" event aaye toh panic alert bhejo
  void _listenPowerButton() {
    _powerButtonChannel.receiveBroadcastStream().listen((event) {
      // Android se "DOUBLE_PRESS" event aaya - panic alert bhejo
      if (event == 'DOUBLE_PRESS') {
        _sendPanic();
      }
    }, onError: (e) {
      // Error aa sakti hai agar:
      // - iOS pe chalaye (power button detection sirf Android pe hai)
      // - Emulator pe chalaye
      // - Android version support na kare
      debugPrint('Power button listener error: $e');
    });
  }

  // _sendPanic() - Panic alert Firebase mein save karo
  // Button dabane pe ya power button double press pe call hota hai
  void _sendPanic() async {
    // Agar pehle se bhej raha hai toh dobara mat bhejo
    if (_sending) return;

    setState(() => _sending = true);

    try {
      // Step 1: Firestore se child ka data fetch karo
      final userData = await _firestoreService.getUser(widget.uid);

      // Check karo child kisi parent se connected hai ya nahi
      if (userData != null && userData['connectedTo'] != null) {
        // Step 2: Alert Firebase mein save karo
        await _firestoreService.sendAlert(
          'panic',                          // Alert type
          widget.uid,                       // Sender (child)
          userData['connectedTo'],          // Receiver (parent)
          '🚨 EMERGENCY! Child ne panic button dabaya!', // Message
        );

        // Alert successful bhej diya
        if (mounted) setState(() => _sent = true);
      } else {
        // Child connected nahi hai kisi parent se
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pehle parent se connect karo!')),
          );
        }
      }
    } catch (e) {
      // Kuch error aa gayi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panic Button'),
        backgroundColor: Colors.red[100], // Light red background
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== BADA PANIC BUTTON =====
              // GestureDetector se tap detect karte hain
              GestureDetector(
                onTap: _sendPanic,
                child: Container(
                  width: 200,
                  height: 200,
                  // Gol container banao (circle shape)
                  decoration: BoxDecoration(
                    color: _sent ? Colors.green : Colors.red, // Sent hone pe green ho jaye
                    shape: BoxShape.circle, // Gol shape
                    // Shadow effect - button ubhra hua lagta hai
                    boxShadow: [
                      BoxShadow(
                        color: (_sent ? Colors.green : Colors.red).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    // Loading spinner ya icon dikhao
                    child: _sending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            _sent ? Icons.check : Icons.warning, // Sent = tick, not sent = warning
                            size: 80,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Status text
              Text(
                _sent ? 'Alert bhej diya gaya!' : 'Emergency ke liye dabao!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _sent ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 10),

              // Reset button (sent ke baad dikhega)
              if (_sent)
                ElevatedButton(
                  onPressed: () => setState(() => _sent = false),
                  child: const Text('Reset'),
                ),
              const SizedBox(height: 30),

              // Power button info card
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '💡 Power button 2 dafa jaldi dabao\ntoh bhi alert chala jayega',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
