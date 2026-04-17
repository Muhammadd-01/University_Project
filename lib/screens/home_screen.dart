// home_screen.dart - Main dashboard, role ke hisab se buttons
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'connect_screen.dart';
import 'map_screen.dart';
import 'panic_screen.dart';
import 'alerts_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Child hai toh location tracking shuru karo
    if (widget.role == 'child') _startTracking();
  }

  void _startTracking() {
    _sendLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  void _sendLocation() async {
    final pos = await _locService.getCurrentLocation();
    if (pos != null) {
      await _fsService.updateLocation(widget.uid, pos.latitude, pos.longitude);
      _checkBoundary(pos.latitude, pos.longitude);
    }
  }

  // Boundary check - child safe zone mein hai ya bahar
  Future<void> _checkBoundary(double lat, double lng) async {
    final user = await _fsService.getUser(widget.uid);
    if (user == null || user['connectedTo'] == null) return;
    final boundary = await _fsService.getBoundary(user['connectedTo']);
    if (boundary == null) return;
    final dist = _locService.getDistance(boundary['lat'], boundary['lng'], lat, lng);
    if (dist > boundary['radius']) {
      await _fsService.sendAlert('boundary', widget.uid, user['connectedTo'],
          'Child is outside the safe zone! Distance: ${dist.toStringAsFixed(0)}m');
    }
  }

  @override
  void dispose() { _locationTimer?.cancel(); super.dispose(); }

  void _logout() async {
    await AuthService().logout();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
      body: Padding(
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
                      Text(isParent ? 'Parent Mode' : 'Child Mode',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(AuthService().currentUser?.email ?? 'User', // Show Email
                          style: TextStyle(color: color.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(isParent ? 'Monitoring active' : 'Tracking active',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Menu buttons
            _menuBtn(Icons.link, 'Connect', 'Link parent & child', color.primary,
                () => _navigate(ConnectScreen(role: widget.role, uid: widget.uid))),
            if (isParent)
              _menuBtn(Icons.map, 'Live Map', 'View child location', Colors.green,
                  () => _navigate(MapScreen(uid: widget.uid))),
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
