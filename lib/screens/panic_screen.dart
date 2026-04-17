// panic_screen.dart - Emergency panic button + power button detection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

class PanicScreen extends StatefulWidget {
  final String uid;
  const PanicScreen({super.key, required this.uid});
  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  final _fs = FirestoreService();
  bool _sending = false, _sent = false;
  
  // Power button triple press listener
  static const _powerChannel = EventChannel('com.childguard.childguard/power_button');

  @override
  void initState() {
    super.initState();
    _powerChannel.receiveBroadcastStream().listen((e) {
      if (e == 'TRIPLE_PRESS') _sendPanic();
    }, onError: (_) {});
  }

  // UI Button Tap Logic
  void _handleButtonTap() {
    _sendPanic(); // One tap as requested
  }

  void _sendPanic() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final user = await _fs.getUser(widget.uid);
      if (user != null && user['connectedTo'] != null) {
        await _fs.sendAlert('panic', widget.uid, user['connectedTo'], '🚨 EMERGENCY! Panic button pressed!');
        if (mounted) setState(() => _sent = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to a parent first!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final btnColor = _sent ? Colors.green : Colors.red;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency'), backgroundColor: Colors.red[50]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big panic button
              GestureDetector(
                onTap: _handleButtonTap, // Triple tap logic
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    color: btnColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: btnColor.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Center(child: _sending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(_sent ? Icons.check : Icons.warning_rounded, size: 80, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
              Text(_sent ? 'Alert Sent!' : 'Tap for Emergency!', // One tap
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: btnColor)),
              const SizedBox(height: 8),
              if (!_sent) Text('Your parent will be notified immediately', style: TextStyle(color: Colors.grey[600])),
              if (_sent) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => setState(() => _sent = false), child: const Text('Reset')),
              ],
              const SizedBox(height: 40),
              // Power button tip
              Card(
                color: Colors.grey[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(child: Text('Triple-press the power button to trigger alert automatically', style: TextStyle(fontSize: 13, color: Colors.grey))),
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
