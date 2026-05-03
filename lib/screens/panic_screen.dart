// panic_screen.dart - Emergency panic button with auto SMS sending via native platform channel
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

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
  int _sentCount = 0;
  int _totalContacts = 0;
  String _statusText = 'Tap for Emergency!';

  // Power button triple press listener
  static const _powerChannel = EventChannel('com.childguard.childguard/power_button');
  // Native SMS sending channel
  static const _smsChannel = MethodChannel('com.childguard.childguard/sms');

  @override
  void initState() {
    super.initState();
    _requestSmsPermission();
    _powerChannel.receiveBroadcastStream().listen((e) {
      if (e == 'TRIPLE_PRESS') _sendPanic();
    }, onError: (_) {});
  }

  Future<void> _requestSmsPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ SMS permission needed for auto-alerts')),
      );
    }
  }

  void _handleButtonTap() {
    _sendPanic();
  }

  /// Sends SMS silently via native Android SmsManager
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

  /// Sends SMS silently to all emergency contacts
  Future<void> _sendSmsToContacts(List<Map<String, dynamic>> contacts, double? lat, double? lng) async {
    _totalContacts = contacts.length;
    _sentCount = 0;

    for (var contact in contacts) {
      final phone = contact['phone'].toString();
      final name = contact['name'] ?? 'Unknown';

      String message = '🚨 CHILDGUARD EMERGENCY!\n'
          'This is an automated emergency alert.\n';
      if (lat != null && lng != null) {
        message += 'Location: https://www.google.com/maps/search/?api=1&query=$lat,$lng\n';
      }
      message += 'Please respond immediately!';

      final success = await _sendSmsNative(phone, message);
      if (success) {
        _sentCount++;
      }
      if (mounted) {
        setState(() => _statusText = '${success ? "✅" : "❌"} $name ($_sentCount/$_totalContacts)');
      }
    }
  }

  void _sendPanic() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _statusText = 'Sending alerts...';
    });

    try {
      final user = await _fs.getUser(widget.uid);
      if (user != null && user['connectedTo'] != null) {
        if (mounted) setState(() => _statusText = 'Getting location...');
        final pos = await _ls.getCurrentLocation();
        final lat = pos?.latitude;
        final lng = pos?.longitude;

        // 1. Send Firebase Alert
        if (mounted) setState(() => _statusText = 'Sending Firebase alert...');
        await _fs.sendAlert('panic', widget.uid, user['connectedTo'],
            '🚨 EMERGENCY! Panic button pressed!');

        // 2. Auto-send SMS to all emergency contacts
        if (mounted) setState(() => _statusText = 'Sending SMS alerts...');
        final contacts = await _fs.getEmergencyContacts(user['connectedTo']);
        if (contacts.isNotEmpty) {
          await _sendSmsToContacts(contacts, lat, lng);
        }

        if (mounted) {
          setState(() {
            _sent = true;
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
        setState(() => _statusText = 'Connect to a parent first!');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect to a parent first!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Error sending alerts');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final btnColor = _sent ? Colors.green : Colors.red;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency'), backgroundColor: Colors.red[50]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big panic button
              GestureDetector(
                onTap: _handleButtonTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    color: btnColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: btnColor.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Center(child: _sending
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      : Icon(_sent ? Icons.check : Icons.warning_rounded, size: 80, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
              Text(_statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: btnColor)),
              const SizedBox(height: 8),
              if (!_sent && !_sending)
                Text('Your emergency contacts will receive SMS automatically',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
              if (_sending && _totalContacts > 0) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _totalContacts > 0 ? _sentCount / _totalContacts : null,
                  backgroundColor: Colors.red[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                ),
                const SizedBox(height: 8),
                Text('$_sentCount of $_totalContacts messages sent',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
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
              Card(
                color: Colors.green[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.sms, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                        'SMS alerts are sent automatically — no need to open any app!',
                        style: TextStyle(fontSize: 13, color: Colors.green))),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                        'Triple-press the power button to trigger alert even when app is in background',
                        style: TextStyle(fontSize: 13, color: Colors.grey))),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
