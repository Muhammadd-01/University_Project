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
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'danger_screen.dart';

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
  static const _platform = MethodChannel('com.childguard.childguard/sms');
  static const _eventChannel = EventChannel('com.childguard.childguard/power_button');
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _nativeSub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initNotifications();
    _startTracking(); // Everyone tracks for two-way safety
    _listenToNativeEvents();
    _checkInitialAlert();
  }

  void _listenToNativeEvents() {
    _nativeSub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is String && event.startsWith('DANGER|')) {
        final parts = event.split('|');
        if (parts.length >= 3) {
          final type = parts[1];
          final message = parts[2];
          _showEmergencyDialog(message, type);
        }
      }
    });
  }

  void _checkInitialAlert() async {
    try {
      final Map? alert = await _platform.invokeMethod('getInitialAlert');
      if (alert != null) {
        final type = alert['type'] ?? 'panic';
        final message = alert['message'] ?? 'Emergency detected!';
        _showEmergencyDialog(message, type);
      }
    } catch (e) {
      debugPrint('Error checking initial alert: $e');
    }
  }

  void _initNotifications() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
    
    // Request notification permission for Android 13+
    if (widget.role == 'parent') {
      await Permission.notification.request();
      // Draw over apps permission (needed for auto-open on some devices)
      await Permission.systemAlertWindow.request();
    } else if (widget.role == 'child') {
      await Permission.notification.request();
      // Request Foreground then Background location for continuous tracking
      var status = await Permission.location.request();
      if (status.isGranted) {
        await Permission.locationAlways.request();
      }
    }
  }

  void _loadProfile() async {
    final data = await _fsService.getUser(widget.uid);
    if (mounted && data != null) {
      setState(() => _userName = data['name']);
      
      // Sync SharedPreferences for Native Background Panic Detection
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', widget.uid);
      await prefs.setString('role', widget.role);
      if (data['connectedTo'] != null) {
        await prefs.setString('parentId', data['connectedTo']);
      }
      
      // Tell native service to refresh its listeners with these new credentials
      try {
        await _platform.invokeMethod('startService');
      } catch (e) {
        debugPrint('Error starting native service: $e');
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

  bool _isShowingDanger = false;
  DateTime? _lastDangerTime;

  void _showEmergencyDialog(String message, String type) async {
    if (!mounted || _isShowingDanger) return;
    
    // Prevent duplicate triggers within 10 seconds
    if (_lastDangerTime != null && DateTime.now().difference(_lastDangerTime!).inSeconds < 10) return;
    _lastDangerTime = DateTime.now();

    _isShowingDanger = true;
    
    // 1. Trigger System Notification (High Importance)
    // Using ID 100 to overwrite the native service notification instead of duplicating
    final androidDetails = AndroidNotificationDetails(
      'EmergencyAlertChannel', 
      '🚨 EMERGENCY ALERTS',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: true,
      styleInformation: BigTextStyleInformation(message),
      color: type == 'panic' ? Colors.red : Colors.orange,
    );
    
    await _notifications.show(
      id: 100, 
      title: type == 'panic' ? '🚨 PANIC ALERT' : '⚠️ BOUNDARY ALERT',
      body: message,
      notificationDetails: NotificationDetails(android: androidDetails),
    );

    // 2. Bring App to Foreground if hidden
    try {
      await _platform.invokeMethod('bringToForeground');
    } catch (e) {
      debugPrint('Bring to foreground error: $e');
    }

    // 3. Show Danger Splash Screen and wait for it to close
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DangerScreen(message: message, type: type)));
    
    // Reset flag after user closes the danger screen
    _isShowingDanger = false;
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
    
    final zones = await _fsService.getSafeZones(user['connectedTo']);
    if (zones.isEmpty) return;
    
    // Child is SAFE if they are inside ANY zone
    bool isInsideAny = false;
    double minDistance = double.infinity;
    
    for (final zone in zones) {
      final isInside = _locService.isWithinBoundary(lat, lng, zone['lat'], zone['lng'], zone['radius']);
      if (isInside) {
        isInsideAny = true;
        break;
      }
      final dist = _locService.getDistance(zone['lat'], zone['lng'], lat, lng);
      if (dist < minDistance) minDistance = dist;
    }
    
    if (!isInsideAny) {
      await _fsService.sendAlert('boundary', widget.uid, user['connectedTo'],
          'Child is outside all safe zones! Closest zone distance: ${minDistance.toStringAsFixed(0)}m');
      _lastAlertTime = DateTime.now();
    }
  }

  @override
  void dispose() { 
    _locationTimer?.cancel(); 
    _alertSub?.cancel();
    _nativeSub?.cancel();
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


  void _linkCoParent() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link with Mom/Dad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your spouse\'s connection code to send a link request.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                final ok = await _fsService.sendPartnerRequest(codeCtrl.text, widget.uid, _userName ?? 'Partner');
                Navigator.pop(ctx);
                if (ok) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Request Sent! Waiting for partner to approve.')));
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Invalid Code or Already Linked')));
                }
              }
            },
            child: const Text('Send Request'),
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
          leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.15), child: Icon(icon, color: iconColor)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
