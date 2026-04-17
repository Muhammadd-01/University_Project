// ============================================
// home_screen.dart - Home Screen (Main Dashboard)
// ============================================
// Login ke baad yeh screen dikhti hai - app ka main page
// Role ke hisab se alag buttons dikhata hai:
// - Parent: Connect, Map (child location), Alerts, Logout
// - Child: Connect, Panic Button, Alerts, Logout
//
// IMPORTANT: Child ke liye location tracking yahan se shuru hoti hai
// Har 30 second mein child ki location GPS se le ke Firebase ko bhejti hai
// Boundary check bhi har location update pe hoti hai
// Agar child boundary se bahar jaye toh alert automatically Firebase mein save hota hai

import 'package:flutter/material.dart';
import 'dart:async'; // Timer ke liye (periodic location updates)
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'connect_screen.dart';
import 'map_screen.dart';
import 'panic_screen.dart';
import 'alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  final String role; // "parent" ya "child"
  final String uid;  // User ki unique Firebase id
  const HomeScreen({super.key, required this.role, required this.uid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Timer jo har 30 second mein location bhejta hai
  Timer? _locationTimer;
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Agar child hai toh location tracking shuru karo
    // Parent ko location tracking ki zaroorat nahi hai
    if (widget.role == 'child') {
      _startLocationTracking();
    }
  }

  // _startLocationTracking() - Har 30 second mein child ki location Firebase ko bhejo
  // Timer.periodic use karta hai jo automatically repeat hota hai
  void _startLocationTracking() {
    _sendLocation(); // Pehli baar turant location bhejo (timer ka wait na karo)

    // Har 30 second baad _sendLocation() call hoga
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
    });
  }

  // _sendLocation() - GPS se location lo aur Firebase mein save karo
  void _sendLocation() async {
    // Step 1: GPS se current position lo
    final pos = await _locationService.getCurrentLocation();

    if (pos != null) {
      // Step 2: Location Firebase ke "locations" collection mein save karo
      await _firestoreService.updateLocation(widget.uid, pos.latitude, pos.longitude);

      // Step 3: Boundary check karo - child safe zone mein hai ya nahi
      await _checkBoundary(pos.latitude, pos.longitude);
    }
  }

  // _checkBoundary() - Check karo child boundary ke andar hai ya bahar
  // Agar bahar hai toh automatically alert Firebase mein save hota hai
  Future<void> _checkBoundary(double lat, double lng) async {
    // Pehle check karo child kisi parent se connected hai ya nahi
    final userData = await _firestoreService.getUser(widget.uid);
    if (userData == null || userData['connectedTo'] == null) return;

    // Parent ki uid lo
    final parentUid = userData['connectedTo'];

    // Parent ne boundary set ki hai ya nahi check karo
    final boundary = await _firestoreService.getBoundary(parentUid);
    if (boundary == null) return; // Boundary set nahi hai, skip karo

    // Distance calculate karo - child ki position se boundary center tak
    // getDistance() meters mein distance deta hai
    final distance = _locationService.getDistance(
      boundary['lat'], boundary['lng'], lat, lng,
    );

    // Agar distance boundary radius se zyada hai toh child BAHAR hai!
    if (distance > boundary['radius']) {
      // Boundary alert bhejo Firebase ko
      await _firestoreService.sendAlert(
        'boundary', // Alert ka type
        widget.uid, // Child ki uid (sender)
        parentUid,  // Parent ki uid (receiver)
        'Child boundary se bahar chala gaya! Distance: ${distance.toStringAsFixed(0)}m',
      );
    }
  }

  @override
  void dispose() {
    // Screen band hone pe timer cancel karo (memory leak na ho)
    _locationTimer?.cancel();
    super.dispose();
  }

  // _logout() - User ko logout karke Login screen pe bhejo
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
      // App bar with title aur logout button
      appBar: AppBar(
        title: const Text('ChildGuard'),
        actions: [
          // Logout button (top right corner mein)
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Buttons poori width lein
          children: [
            // Role card - dikhao user parent hai ya child
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

            // Connect button - dono roles ke liye (parent aur child)
            // Parent ko apna code dikhega, child code enter karega
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

            // Map button - SIRF parent ke liye
            // Child ki location map pe dikhata hai
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

            // Panic button - SIRF child ke liye
            // Emergency mein dabao toh parent ko alert jayega
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
                // Red color se danger feel aaye
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 10),

            // Alerts button - dono roles ke liye
            // Sab alerts dikhata hai (panic + boundary)
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
