// home_screen.dart - Main dashboard
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../widgets/loading_widget.dart';
import 'login_screen.dart';
import 'connect_screen.dart';
import 'map_screen.dart';
import 'panic_screen.dart';
import 'alerts_screen.dart';
import 'safe_zone_screen.dart';
import 'contacts_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'danger_screen.dart';

// Yeh app ka main dashboard hai jahan se sab features open hote hain
class HomeScreen extends StatefulWidget {
  final String role, uid;
  const HomeScreen({super.key, required this.role, required this.uid});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _locationTimer; // Location bhejne ke liye timer
  final _locService = LocationService();
  final _fsService = FirestoreService();
  String? _userName;
  String _trackingStatus = 'Initializing...';
  DateTime? _lastAlertTime;
  StreamSubscription? _alertSub; // Database se alerts sunne ke liye
  
  // Native Android se events (e.g. power button dabana) sunne ke liye
  static const _platform = MethodChannel('com.childguard.childguard/sms');
  static const _eventChannel = EventChannel('com.childguard.childguard/power_button');
  
  final _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _nativeSub;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initNotifications();
    _startTracking();
    _listenToNativeEvents();
    _checkInitialAlert();
  }

  // Background se aane wale hardware button events (volume/power) ko sunna
  void _listenToNativeEvents() {
    _nativeSub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is String && event.startsWith('DANGER|')) {
        final parts = event.split('|');
        if (parts.length >= 3) {
          final type = parts[1];
          final message = parts[2];
          final alertId = parts.length >= 4 ? parts[3] : null;
          _showEmergencyDialog(message, type, alertId); // Emergency screen kholo
        }
      }
    });
  }

  // App khulte hi check karo ke koi purana alert toh nahi aya tha jab app band thi
  void _checkInitialAlert() async {
    try {
      final Map? alert = await _platform.invokeMethod('getInitialAlert');
      if (alert != null) {
        final type = alert['type'] ?? 'panic';
        final message = alert['message'] ?? 'Emergency detected!';
        final alertId = alert['alertId'];
        _showEmergencyDialog(message, type, alertId);
      }
    } catch (e) {
      debugPrint('Error checking initial alert: $e');
    }
  }

  // Notifications bhejne ke liye permissions aur settings
  void _initNotifications() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
    
    // Parent ko sirf notifications ki permission chahiye
    if (widget.role == 'parent') {
      await Permission.notification.request();
      await Permission.systemAlertWindow.request(); // Danger screen pop up ke liye
    } 
    // Child ko location ki permissions chahiye
    else if (widget.role == 'child') {
      await Permission.notification.request();
      var status = await Permission.location.request();
      if (status.isGranted) {
        await Permission.locationAlways.request(); // Background me location ke liye
      }
    }
  }

  // User ka data database se mangwana
  void _loadProfile() async {
    final data = await _fsService.getUser(widget.uid);
    if (mounted && data != null) {
      setState(() {
        _userName = data['name'];
        _isLoading = false;
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', widget.uid);
      await prefs.setString('role', widget.role);
      if (data['connectedTo'] != null) {
        await prefs.setString('parentId', data['connectedTo']);
      }
      
      // Native Android service start karna takay app background me bhi chale
      try {
        await _platform.invokeMethod('startService');
      } catch (e) {
        debugPrint('Error starting native service: $e');
      }

      if (widget.role == 'parent') {
        _startAlertListener(); // Parent alerts ka intezar karega
      }

      if (widget.role == 'child') {
        // Child ke phone me Workmanager se background task set karna (har 15 minute)
        Workmanager().registerPeriodicTask(
          "1", 
          "geofenceCheck",
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    }
  }

  // Live location track karna shuru karo (har 30 sec baad)
  void _startTracking() {
    _sendLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  // Location database mein bhejna
  void _sendLocation() async {
    final ok = await _locService.handlePermission();
    if (!ok) {
      if (mounted) setState(() => _trackingStatus = 'Permission Denied! ❌');
      return;
    }
    
    final pos = await _locService.getCurrentLocation();
    if (pos != null) {
      await _fsService.updateLocation(widget.uid, pos.latitude, pos.longitude);
      _checkBoundary(pos.latitude, pos.longitude); // Check karo ke bacha safe zone mein hai ya nahi
      if (mounted) setState(() => _trackingStatus = 'Active');
    } else {
      if (mounted) setState(() => _trackingStatus = 'GPS Error');
    }
  }

  // Parent ke phone me alerts listen karna (jaise hi child panic dabaye)
  void _startAlertListener() {
    _alertSub = _fsService.getAlerts(widget.uid).listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final lastAlert = snapshot.docs.first.data() as Map<String, dynamic>;
        final timestamp = lastAlert['timestamp'] as Timestamp?;
        
        // Agar alert pichle 1 minute me aya hai toh screen par dikhao
        if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inMinutes < 1) {
          _showEmergencyDialog(lastAlert['message'], lastAlert['type'], snapshot.docs.first.id);
        }
      }
    });
  }

  bool _isShowingDanger = false;
  DateTime? _lastDangerTime;

  // Danger/Emergency screen kholna aur Notification bhejna
  void _showEmergencyDialog(String message, String type, String? alertId) async {
    if (!mounted || _isShowingDanger) return;
    
    if (_lastDangerTime != null && DateTime.now().difference(_lastDangerTime!).inSeconds < 10) return;
    _lastDangerTime = DateTime.now();

    _isShowingDanger = true;
    
    // High priority notification settings
    final androidDetails = AndroidNotificationDetails(
      'EmergencyAlertChannel', 
      '🚨 EMERGENCY ALERTS',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // Screen khud on ho jayegi
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

    // App ko background se samne lana (Android native code call)
    try {
      await _platform.invokeMethod('bringToForeground');
    } catch (e) {
      debugPrint('Bring to foreground error: $e');
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => DangerScreen(message: message, type: type, alertId: alertId)));
    _isShowingDanger = false;
  }

  // Check karna ke bacha safe zone ke andar hai ya bahar nikal gaya hai
  Future<void> _checkBoundary(double lat, double lng) async {
    if (widget.role == 'parent') return; // Parent ka check nahi karna
    
    // Har 5 min me ek hi baar alert bhejo
    if (_lastAlertTime != null && DateTime.now().difference(_lastAlertTime!).inMinutes < 5) {
      return;
    }

    final user = await _fsService.getUser(widget.uid);
    if (user == null || user['connectedTo'] == null) return;
    
    final zones = await _fsService.getSafeZones(user['connectedTo']);
    if (zones.isEmpty) return;
    
    bool isInsideAny = false;
    double minDistance = double.infinity;
    
    for (final zone in zones) {
      final isInside = _locService.isWithinBoundary(lat, lng, zone['lat'], zone['lng'], zone['radius']);
      if (isInside) {
        isInsideAny = true; // Bacha safe zone ke andar hai
        break;
      }
      final dist = _locService.getDistance(zone['lat'], zone['lng'], lat, lng);
      if (dist < minDistance) minDistance = dist;
    }
    
    // Agar bahar nikal aya hai toh parent ko alert bhej do
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

  // App se bahar nikalna (Logout)
  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out from ChildGuard?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoggingOut = true);
              
              // Thora wait karo animation ke liye
              await Future.delayed(const Duration(milliseconds: 1500));
              await AuthService().logout();
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Phone se local memory saaf kardo
              
              if (mounted) {
                // Login screen par wapas le jao
                Navigator.pushReplacement(
                  context, 
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 800),
                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              }
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Apne partner (husband/wife) ko app mein shamil karna
  void _linkCoParent() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link with Partner', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your spouse\'s connection code to share child monitoring.', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Connection Code',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.isNotEmpty) {
                final ok = await _fsService.sendPartnerRequest(codeCtrl.text, widget.uid, _userName ?? 'Partner');
                Navigator.pop(ctx);
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Request Sent!')));
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Invalid Code')));
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // Doosri screen par jane ka short function
  void _navigate(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    if (_isLoggingOut) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: LoadingWidget(message: 'Securing your session and signing out...'),
      );
    }
    if (_isLoading) return const Scaffold(body: LoadingWidget(message: 'Syncing your profile...'));

    final isParent = widget.role == 'parent';
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ChildGuard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: IconButton(
              onPressed: _logout, // Logout ka icon
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User ka apna profile card
            _buildProfileCard(isParent, colorScheme).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 30),
            
            Text(
              'Security Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.grey[800],
              ),
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 16),
            
            // Buttons ka grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildMenuCard(
                  Icons.link_rounded, 
                  'Connect', 
                  'Link Devices', 
                  colorScheme.primary,
                  () => _navigate(ConnectScreen(role: widget.role, uid: widget.uid)),
                ).animate(delay: 200.ms).fadeIn().scale(),
                
                _buildMenuCard(
                  Icons.map_rounded, 
                  'Live Map', 
                  'Real-time', 
                  const Color(0xFF10B981), // Sabz (Green) color
                  () => _navigate(MapScreen(uid: widget.uid, role: widget.role)),
                ).animate(delay: 300.ms).fadeIn().scale(),
                
                if (isParent)
                  _buildMenuCard(
                    Icons.shield_rounded, 
                    'Safe Zone', 
                    'Geofencing', 
                    Colors.indigo,
                    () => _navigate(SafeZoneScreen(uid: widget.uid)),
                  ).animate(delay: 400.ms).fadeIn().scale(),
                
                _buildMenuCard(
                  Icons.notifications_active_rounded, 
                  'Activity', 
                  'Logs', 
                  Colors.orangeAccent,
                  () => _navigate(AlertsScreen(uid: widget.uid, role: widget.role)),
                ).animate(delay: 500.ms).fadeIn().scale(),

                _buildMenuCard(
                  Icons.contacts_rounded, 
                  'SOS List', 
                  'Contacts', 
                  Colors.redAccent,
                  () => _navigate(ContactsScreen(uid: widget.uid, role: widget.role)),
                ).animate(delay: 600.ms).fadeIn().scale()
                 .shimmer(delay: 3000.ms, duration: 2000.ms),

                // Agar child hai toh Panic button dikhao
                if (!isParent)
                  _buildMenuCard(
                    Icons.warning_rounded, 
                    'PANIC', 
                    'Emergency', 
                    Colors.red,
                    () => _navigate(PanicScreen(uid: widget.uid)),
                  ).animate(onPlay: (c) => c.repeat())
                   .shimmer(delay: 1000.ms, duration: 1000.ms)
                   .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 500.ms, curve: Curves.easeInOut),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Profile card ka design
  Widget _buildProfileCard(bool isParent, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Icon(isParent ? Icons.person_rounded : Icons.child_care_rounded, color: colorScheme.primary, size: 35),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(
                  widget.role.toUpperCase(),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                // Child ke liye GPS status dikhao
                if (!isParent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          'GPS: $_trackingStatus',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                // Parent ke liye Co-parent (partner) link karne ka button
                if (isParent)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final hasCo = data?['coParent'] != null;
                      return GestureDetector(
                        onTap: hasCo ? null : _linkCoParent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(hasCo ? Icons.people_rounded : Icons.person_add_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                hasCo ? 'Family Network Active' : 'Link Mom/Dad',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dashboard ke box (card) ka design
  Widget _buildMenuCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Subtle background decoration (pichay jo gol design hai)
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white.withOpacity(0.5))
                     .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms, curve: Curves.easeInOut),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
     .fadeIn(duration: 600.ms)
     .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
     .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}
