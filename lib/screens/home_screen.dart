// home_screen.dart - Main dashboard, role ke hisab se buttons
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'connect_screen.dart';
import 'map_screen.dart';
import 'panic_screen.dart';
import 'alerts_screen.dart';
import 'safe_zone_screen.dart'; // Added for boundary management
import 'contacts_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

class HomeScreen extends StatefulWidget {
  final String role, uid;
  const HomeScreen({super.key, required this.role, required this.uid});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _locationTimer;
  final _locService = LocationService();
  final _fsService = FirestoreService();
   String? _userName;
  String _trackingStatus = 'Initializing...'; // Track GPS status
  DateTime? _lastAlertTime; // Cooldown for alerts
  StreamSubscription? _alertSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _startTracking(); // Everyone tracks for two-way safety
  }

  void _loadProfile() async {
    final data = await _fsService.getUser(widget.uid);
    if (mounted && data != null) {
      setState(() => _userName = data['name']);
      
      // Sync SharedPreferences for Native Background Panic Detection
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', widget.uid);
      if (data['connectedTo'] != null) {
        await prefs.setString('parentId', data['connectedTo']);
      }

      // If parent, listen for alerts in real-time
      if (widget.role == 'parent') {
        _startAlertListener();
      }

      // Start background task if child
      if (widget.role == 'child') {
        Workmanager().registerPeriodicTask(
          "1", 
          "geofenceCheck",
          frequency: const Duration(minutes: 15), // Android minimum
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    }
  }

  void _startTracking() {
    _sendLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  void _sendLocation() async {
    final ok = await _locService.handlePermission();
    if (!ok) {
      if (mounted) setState(() => _trackingStatus = 'Permission Denied! ❌');
      return;
    }
    
    final pos = await _locService.getCurrentLocation();
    if (pos != null) {
      await _fsService.updateLocation(widget.uid, pos.latitude, pos.longitude);
      _checkBoundary(pos.latitude, pos.longitude);
      if (mounted) setState(() => _trackingStatus = 'Tracking Active! ✅');
    } else {
      if (mounted) setState(() => _trackingStatus = 'GPS Error! ⚠️');
    }
  }

  void _startAlertListener() {
    _alertSub = _fsService.getAlerts(widget.uid).listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final lastAlert = snapshot.docs.first.data() as Map<String, dynamic>;
        final timestamp = lastAlert['timestamp'] as Timestamp?;
        
        // Only notify if alert is newer than 1 minute (prevents old alert spam on login)
        if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inMinutes < 1) {
          _showEmergencyDialog(lastAlert['message'], lastAlert['type']);
        }
      }
    });
  }

  void _showEmergencyDialog(String message, String type) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: type == 'panic' ? Colors.red[50] : Colors.orange[50],
        title: Row(
          children: [
            Icon(type == 'panic' ? Icons.warning : Icons.radar, color: type == 'panic' ? Colors.red : Colors.orange),
            const SizedBox(width: 8),
            Text(type == 'panic' ? '🚨 PANIC ALERT' : '⚠️ BOUNDARY ALERT'),
          ],
        ),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: type == 'panic' ? Colors.red : Colors.orange),
            child: const Text('I am coming!'),
          ),
        ],
      ),
    );
  }


   // Boundary check - child safe zone mein hai ya bahar
  Future<void> _checkBoundary(double lat, double lng) async {
    if (widget.role == 'parent') return; // Parents don't check their own boundary
    
    // Alert cooldown (don't spam alerts more than once every 5 minutes)
    if (_lastAlertTime != null && DateTime.now().difference(_lastAlertTime!).inMinutes < 5) {
      return;
    }

    final user = await _fsService.getUser(widget.uid);
    if (user == null || user['connectedTo'] == null) return;
    
    final boundary = await _fsService.getBoundary(user['connectedTo']);
    if (boundary == null) return;
    
    final isInside = _locService.isWithinBoundary(lat, lng, boundary['lat'], boundary['lng'], boundary['radius']);
    
    if (!isInside) {
      final dist = _locService.getDistance(boundary['lat'], boundary['lng'], lat, lng);
      await _fsService.sendAlert('boundary', widget.uid, user['connectedTo'],
          'Child is outside the safe zone! Distance: ${dist.toStringAsFixed(0)}m');
      _lastAlertTime = DateTime.now();
    }
  }

  @override
  void dispose() { 
    _locationTimer?.cancel(); 
    _alertSub?.cancel();
    super.dispose(); 
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await AuthService().logout();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _linkWhatsApp() {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link your WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your WhatsApp number with country code (e.g. +923001234567).\nThis will be used as your identity in emergency alerts.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '+923001234567',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isNotEmpty && phone.startsWith('+')) {
                await _fsService.linkWhatsApp(widget.uid, phone);
                Navigator.pop(ctx);
                _loadProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ WhatsApp Linked Successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number starting with +')),
                );
              }
            },
            child: const Text('Link Now'),
          ),
        ],
      ),
    );
  }

  void _linkCoParent() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link with Mom/Dad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your spouse\'s connection code to share children access.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Connection Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (codeCtrl.text.isNotEmpty) {
                final ok = await _fsService.linkCoParent(codeCtrl.text, widget.uid);
                Navigator.pop(ctx);
                if (ok) {
                  _loadProfile();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Network Linked with Co-Parent!')));
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Invalid Code or Already Linked')));
                }
              }
            },
            child: const Text('Link Network'),
          ),
        ],
      ),
    );
  }

  void _navigate(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'parent';
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChildGuard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Role card with icon
            Card(
              color: color.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28, backgroundColor: color.primary,
                      child: Icon(isParent ? Icons.person : Icons.child_care, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_userName ?? (isParent ? 'Parent' : 'Child'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(AuthService().currentUser?.email ?? '', // Show Email as secondary
                          style: TextStyle(color: color.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(isParent ? 'Monitoring active' : 'Tracking active',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                       if (!isParent) ...[
                        const SizedBox(height: 4),
                        Text(_trackingStatus, style: TextStyle(color: _trackingStatus.contains('Active') ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() as Map<String, dynamic>?;
                            final linked = data?['linkedWhatsApp'] != null;
                            return ActionChip(
                              avatar: Icon(linked ? Icons.check_circle : Icons.link, size: 16, color: linked ? Colors.green : Colors.orange),
                              label: Text(linked ? 'WhatsApp Linked' : 'Link WhatsApp', style: const TextStyle(fontSize: 10)),
                              onPressed: linked ? null : _linkWhatsApp,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }
                        ),
                      ],
                      if (isParent) ...[
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() as Map<String, dynamic>?;
                            final hasCo = data?['coParent'] != null;
                            return ActionChip(
                              avatar: Icon(hasCo ? Icons.people : Icons.person_add, size: 16, color: hasCo ? Colors.indigo : Colors.grey),
                              label: Text(hasCo ? 'Network Shared' : 'Link Mom/Dad', style: const TextStyle(fontSize: 10)),
                              onPressed: hasCo ? null : _linkCoParent,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Menu buttons
            _menuBtn(Icons.link, 'Connect', 'Link parent & child', color.primary,
                () => _navigate(ConnectScreen(role: widget.role, uid: widget.uid))),
            _menuBtn(Icons.map, 'Live Map', isParent ? 'View child location' : 'View parent location', Colors.green,
                () => _navigate(MapScreen(uid: widget.uid, role: widget.role))),
            if (isParent)
              _menuBtn(Icons.shield, 'Safe Zone', 'Manage safety boundaries', Colors.indigo,
                  () => _navigate(SafeZoneScreen(uid: widget.uid))),
            _menuBtn(Icons.contact_phone, 'Emergency Contacts', isParent ? 'Manage contacts' : 'View contacts', Colors.teal,
                () => _navigate(ContactsScreen(uid: widget.uid, role: widget.role))),
            if (!isParent)
              _menuBtn(Icons.warning_rounded, 'Panic Button', 'Send emergency alert', Colors.red,
                  () => _navigate(PanicScreen(uid: widget.uid))),
            _menuBtn(Icons.notifications, 'Alerts', 'View all alerts', Colors.orange,
                () => _navigate(AlertsScreen(uid: widget.uid, role: widget.role))),
          ],
        ),
      ),
    );
  }

  // Reusable menu button widget
  Widget _menuBtn(IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.15), child: Icon(icon, color: iconColor)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
