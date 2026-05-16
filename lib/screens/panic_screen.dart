// panic_screen.dart - Emergency panic button with auto SMS sending via native platform channel
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'parent_responding_screen.dart';

// Yeh screen child ko emergency mein use karni hoti hai, yahan panic button hota hai
class PanicScreen extends StatefulWidget {
  final String uid;
  const PanicScreen({super.key, required this.uid});
  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  final _fs = FirestoreService();
  final _ls = LocationService();
  bool _sending = false, _sent = false;
  bool _accessibilityEnabled = false;
  int _sentCount = 0; // Kitne logo ko SMS chala gaya
  int _totalContacts = 0; // Total kitne contacts thay
  String _statusText = 'Tap for Emergency!';
  StreamSubscription? _responseSub; // Parent ke response ka intezar karne ke liye sub

  // Power button (ya volume buttons) ko lagatar 3 baar dabane par alert bhejne ka connection
  static const _powerChannel = EventChannel('com.childguard.childguard/power_button');
  // Background mein chupke se SMS bhejne ke liye native connection
  static const _smsChannel = MethodChannel('com.childguard.childguard/sms');

  @override
  void dispose() {
    _responseSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requestSmsPermission(); // SMS bhejne ki ijazat mangna
    _checkAccessibility();
    // Hardware buttons dabane ki aawaz (signals) sunna
    _powerChannel.receiveBroadcastStream().listen((e) {
      if (e == 'TRIPLE_PRESS' || e == 'VOLUME_BUTTONS') {
        _sendPanic(trigger: e.toString()); // Background se alert bhejna
      }
    }, onError: (_) {});
  }

  // Accessibility service check karna (Android setting jo background me app chalne me madad karti hai)
  Future<void> _checkAccessibility() async {
    try {
      final bool enabled = await _smsChannel.invokeMethod('isAccessibilityServiceEnabled');
      if (mounted) setState(() => _accessibilityEnabled = enabled);
    } catch (e) {
      debugPrint('Accessibility check error: $e');
    }
  }

  // Agar zaroorat ho toh user ko Settings mein bhej kar accessibility on karwana
  Future<void> _openAccessibilitySettings() async {
    await _smsChannel.invokeMethod('openAccessibilitySettings');
    // Jab user wapas app mein aaye toh 2 second baad dobara check karo
    Future.delayed(const Duration(seconds: 2), _checkAccessibility);
  }

  // SMS bhejne ki permission phone se mangna
  Future<void> _requestSmsPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    // Agar permission nahi di toh warning dikhao
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ SMS permission needed for auto-alerts')),
      );
    }
  }

  // Screen par bane laal button ko dabana
  void _handleButtonTap() {
    _sendPanic();
  }

  // Parent ke resolution (I AM COMING) ka intezar karna
  void _listenForResponse(String alertId) {
    _responseSub?.cancel();
    _responseSub = FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data()?['status'] == 'resolved') {
        _responseSub?.cancel();
        if (mounted) {
          // Panic screen ko band kar ke 'Parent Responding' screen dikhao
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const ParentRespondingScreen())
          );
        }
      }
    });
  }

  /// Khamoshi se (bina SMS app khole) SMS bhejna native Android ke zariye
  Future<bool> _sendSmsNative(String phone, String message) async {
    try {
      final result = await _smsChannel.invokeMethod('sendSms', {
        'phone': phone,
        'message': message,
      });
      return result == true;
    } catch (e) {
      debugPrint('Native SMS error: $e');
      return false;
    }
  }

  /// Emergency contacts list mein majood har number par SMS bhejna
  Future<void> _sendSmsToContacts(List<Map<String, dynamic>> contacts, double? lat, double? lng) async {
    _totalContacts = contacts.length;
    _sentCount = 0;

    for (var contact in contacts) {
      final phone = contact['phone'].toString();
      final name = contact['name'] ?? 'Unknown';

      // SMS ka text message banana
      String message = '🚨 CHILDGUARD EMERGENCY!\n'
          'This is an automated emergency alert.\n';
      // Agar location mil gayi hai toh Google Maps ka link bhi bhej do
      if (lat != null && lng != null) {
        message += 'Location: https://www.google.com/maps/search/?api=1&query=$lat,$lng\n';
      }
      message += 'Please respond immediately!';

      final success = await _sendSmsNative(phone, message);
      if (success) {
        _sentCount++;
      }
      // Kitne bhej diye, uski ginti update karna
      if (mounted) {
        setState(() => _statusText = '${success ? "✅" : "❌"} $name ($_sentCount/$_totalContacts)');
      }
    }
  }

  // Asal function jo Panic ka pura process chalata hai
  void _sendPanic({String trigger = 'MANUAL'}) async {
    if (_sending) return; // Agar pehle se bhej raha hai toh dobara mat chalao
    setState(() {
      _sending = true;
      _statusText = 'Sending alerts...';
    });

    try {
      final user = await _fs.getUser(widget.uid);
      if (user != null && user['connectedTo'] != null) {
        // 1. Sabse pehle Firebase database me alert bhejo takay parent ki app par foran ghanti baje
        if (mounted) setState(() => _statusText = 'Sending alert...');
        String alertMsg = '🚨 EMERGENCY! ';
        
        // Pata lagana ke panic kahan se dabaya gaya (screen se, volume button se ya power button se)
        if (trigger == 'VOLUME_BUTTONS') {
          alertMsg += 'Panic triggered by Volume Buttons!';
        } else if (trigger == 'TRIPLE_PRESS') {
          alertMsg += 'Panic triggered by Power Button!';
        } else {
          alertMsg += 'Panic button pressed manually!';
        }
        
        final alertId = await _fs.sendAlert('panic', widget.uid, user['connectedTo'], alertMsg);
        if (alertId != null) {
          _listenForResponse(alertId);
        }
        
        // 2. Apni live location nikalna aur parent ke set kiye gaye contacts mangwana dono kaam ek sath (parallel) karna
        if (mounted) setState(() => _statusText = 'Updating location & contacts...');
        
        final results = await Future.wait([
          _ls.getCurrentLocation(),
          _fs.getEmergencyContacts(user['connectedTo'])
        ]);
        
        final pos = results[0] as dynamic; // Position (Location)
        final contacts = results[1] as List<Map<String, dynamic>>;
        
        final lat = pos?.latitude;
        final lng = pos?.longitude;

        // 3. Contacts mil gaye toh unko khufia (silent) SMS bhejna shuru karo
        if (contacts.isNotEmpty) {
          if (mounted) setState(() => _statusText = 'Sending SMS to contacts...');
          await _sendSmsToContacts(contacts, lat, lng);
        }

        // Sab kaam ho gaya
        if (mounted) {
          setState(() {
            _sent = true; // Bhej diya gaya
            _statusText = contacts.isEmpty
                ? '✅ Alert Sent! (No emergency contacts)'
                : '✅ All Done! ($_sentCount/$_totalContacts SMS sent)';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Emergency SMS sent to $_sentCount contacts!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (mounted) {
        // Agar bacha kisi parent ke sath linked (connected) nahi hai
        setState(() => _statusText = 'Connect to a parent first!');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect to a parent first!')));
      }
    } catch (e) {
      // Agar internet kharab ho ya koi aur masla aa jaye
      if (mounted) {
        setState(() => _statusText = 'Error sending alerts');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _sending = false); // Button dobara dabane ke qabil karo
  }

  @override
  Widget build(BuildContext context) {
    // Agar alert ja chuka hai toh hara rang, warna lal rang
    final btnColor = _sent ? Colors.green : Colors.red;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency'), backgroundColor: Colors.red[50]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bada sa panic button
              GestureDetector(
                onTap: _handleButtonTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    color: btnColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: btnColor.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)], // Glow effect
                  ),
                  child: Center(child: _sending
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3) // Loading goal chakra
                      : Icon(_sent ? Icons.check : Icons.warning_rounded, size: 80, color: Colors.white)), // Icon
                ),
              ),
              const SizedBox(height: 32),
              // Current status kya chal raha hai uski text
              Text(_statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: btnColor)),
              const SizedBox(height: 8),
              // Agar message ja chuka hai toh wapas pehli halat me aane ka (Reset) button dikhao
              if (_sent) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _sent = false;
                    _sentCount = 0;
                    _totalContacts = 0;
                    _statusText = 'Tap for Emergency!';
                  }),
                  child: const Text('Reset'),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
