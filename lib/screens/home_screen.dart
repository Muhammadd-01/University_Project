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

// Home screen - role ke hisab se buttons dikhao
class HomeScreen extends StatefulWidget {
  final String role;
  final String uid;
  const HomeScreen({super.key, required this.role, required this.uid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _locationTimer;
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Agar child hai toh location tracking shuru karo
    if (widget.role == 'child') {
      _startLocationTracking();
    }
  }

  // Har 30 second mein location Firebase ko bhejo
  void _startLocationTracking() {
    _sendLocation(); // Pehli baar turant bhejo
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
    });
  }

  // Location fetch karke Firebase mein save karo
  void _sendLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      await _firestoreService.updateLocation(widget.uid, pos.latitude, pos.longitude);
      // Boundary check karo
      await _checkBoundary(pos.latitude, pos.longitude);
    }
  }

  // Check karo ke child boundary ke andar hai ya bahar
  Future<void> _checkBoundary(double lat, double lng) async {
    final userData = await _firestoreService.getUser(widget.uid);
    if (userData == null || userData['connectedTo'] == null) return;
    final parentUid = userData['connectedTo'];
    final boundary = await _firestoreService.getBoundary(parentUid);
    if (boundary == null) return;
    // Distance calculate karo
    final distance = _locationService.getDistance(
      boundary['lat'], boundary['lng'], lat, lng,
    );
    // Agar boundary se bahar hai toh alert bhejo
    if (distance > boundary['radius']) {
      await _firestoreService.sendAlert(
        'boundary',
        widget.uid,
        parentUid,
        'Child boundary se bahar chala gaya! Distance: ${distance.toStringAsFixed(0)}m',
      );
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChildGuard'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role dikhao
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Role: ${widget.role.toUpperCase()}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Connect button - dono roles ke liye
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConnectScreen(role: widget.role, uid: widget.uid),
                ),
              ),
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
            const SizedBox(height: 10),
            // Map button - sirf parent ke liye
            if (widget.role == 'parent')
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(uid: widget.uid),
                  ),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Map - Child Location'),
              ),
            const SizedBox(height: 10),
            // Panic button - sirf child ke liye
            if (widget.role == 'child')
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PanicScreen(uid: widget.uid),
                  ),
                ),
                icon: const Icon(Icons.warning),
                label: const Text('Panic Button'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            const SizedBox(height: 10),
            // Alerts button - dono roles ke liye
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlertsScreen(uid: widget.uid, role: widget.role),
                ),
              ),
              icon: const Icon(Icons.notifications),
              label: const Text('Alerts'),
            ),
          ],
        ),
      ),
    );
  }
}
