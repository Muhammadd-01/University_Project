// map_screen.dart - Real-time tracking map
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../widgets/loading_widget.dart';

// Yeh screen live map dikhati hai jahan parent apne bacho ko real-time track kar sakte hain
class MapScreen extends StatefulWidget {
  final String uid, role;
  const MapScreen({super.key, required this.uid, required this.role});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _fs = FirestoreService();
  final _ls = LocationService();
  final _mapCtrl = MapController(); // Map ko control (zoom/pan) karne ke liye
  List<Map<String, dynamic>> _childrenProfiles = [];
  List<Map<String, dynamic>> _safeZones = [];
  bool _loading = true;

  // Map par mukhtalif bacho ke liye mukhtalif rang ke markers
  final List<Color> _markerColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() { super.initState(); _load(); }

  // User ka data, bacho ki list, aur safe zones (geofences) load karna
  void _load() async {
    final user = await _fs.getUser(widget.uid);
    List<dynamic> targetUids = [];
    
    // Agar parent hai toh uske sub bacho ka data laao
    if (widget.role == 'parent') {
      targetUids = user?['children'] ?? [];
    } else {
      // Agar child hai toh apne parent ka data dekho
      final parentUid = user?['connectedTo'];
      if (parentUid != null) {
        targetUids.add(parentUid);
        final parentData = await _fs.getUser(parentUid);
        // Agar ami/abu dono hain toh dono ko list me dalo
        if (parentData != null && parentData['coParent'] != null) {
          targetUids.add(parentData['coParent']);
        }
      }
    }

    if (targetUids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Bacho ki profiles aur geofence zones database se lana
    final profiles = await _fs.getChildrenProfiles(targetUids);
    final zones = await _fs.getSafeZones(widget.role == 'parent' ? widget.uid : user?['connectedTo']);
    
    if (mounted) setState(() { _childrenProfiles = profiles; _safeZones = zones; _loading = false; });
  }

  // Kisi makhsoos bachay ke marker par map focus karna aur uski doori (distance) dikhana
  void _focusChild(String name, LatLng pos) async {
    _mapCtrl.move(pos, 17); // Map wahan le jao aur thora zoom karo

    // Parent ki apni location
    final myPos = await _ls.getCurrentLocation();
    if (myPos != null) {
      final meters = _ls.getDistance(myPos.latitude, myPos.longitude, pos.latitude, pos.longitude);
      // Agar 1000m (1km) se kam hai toh meters me warna km me dikhao
      String distText = meters < 1000 
          ? "${meters.round()}m away" 
          : "${(meters / 1000).toStringAsFixed(1)}km away";

      // Neeche se ek chota sa popup (bottom sheet) nikal kar information dikhana
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          elevation: 0,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text(distText, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Text('Secure real-time link established', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingWidget(message: 'Initializing map...'));

    return Scaffold(
      extendBodyBehindAppBar: true, // App bar ke peechay bhi map nazar aye
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: const Text('Live Tracking', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.black)),
        ],
      ),
      // Stream builder database se live location sun raha hai (real-time updates)
      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.getMultiLocationStream(_childrenProfiles.map((p) => p['uid']?.toString()).whereType<String>().toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingWidget(message: 'Syncing positions...');
          
          List<Marker> markers = [];
          List<Map<String, dynamic>> activeChildren = [];
          LatLng? firstLoc;

          // Jab live location data ajaye toh usay parse karna
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final loc = doc.data() as Map<String, dynamic>;
              if (loc['latitude'] == null || loc['longitude'] == null) continue;
              
              final pos = LatLng(loc['latitude'], loc['longitude']);
              firstLoc ??= pos;

              final profileIdx = _childrenProfiles.indexWhere((p) => p['uid'] == doc.id);
              final name = profileIdx != -1 ? _childrenProfiles[profileIdx]['name'] : 'User';
              final color = _markerColors[profileIdx != -1 ? (profileIdx % _markerColors.length) : 0];

              activeChildren.add({'name': name, 'pos': pos, 'color': color});

              // Map ke upar dikhne wala pin (marker) banana
              markers.add(Marker(
                point: pos, width: 120, height: 120,
                child: Column(
                  children: [
                    // Bachay ka naam marker ke oopar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      ),
                      child: Text(name, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    // Location pin jisme peeche thora dhak dhak (pulse) effect hai
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: color.withOpacity(0.3), shape: BoxShape.circle),
                        ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(2, 2), duration: 1500.ms).fadeOut(),
                        Icon(Icons.location_on_rounded, color: color, size: 40),
                      ],
                    ),
                  ],
                ),
              ));
            }
          }

          // Agar kisi ki bhi location nahi mili
          if (markers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('No live signals found', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.role == 'parent' ? 'Awaiting child signal...' : 'Awaiting parent signal...', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Main Map ka widget
              FlutterMap(
                mapController: _mapCtrl, 
                options: MapOptions(
                  initialCenter: firstLoc ?? const LatLng(0, 0), // Pehli location par map center karo
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ), 
                children: [
                  // Map ki tiles (background imagery - cartocdn voyager theme)
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.childguard.childguard',
                  ),
                  // Agar safe zones define kiye gaye hain toh wo gol (circles) draw karo
                  if (_safeZones.isNotEmpty) CircleLayer(circles: _safeZones.map((z) => CircleMarker(
                    point: LatLng(z['lat'], z['lng']), radius: z['radius'].toDouble(),
                    useRadiusInMeter: true, 
                    color: const Color(0xFF6366F1).withOpacity(0.1), 
                    borderColor: const Color(0xFF6366F1), 
                    borderStrokeWidth: 2,
                  )).toList()),
                  // Locations ke markers draw karo
                  MarkerLayer(markers: markers),
                ],
              ),
              
              // Map ke neeche bacho ke naam wala slider (Carousel)
              Positioned(
                bottom: 30, left: 0, right: 0,
                child: Column(
                  children: [
                    SizedBox(
                      height: 55,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: activeChildren.length,
                        itemBuilder: (context, index) {
                          final child = activeChildren[index];
                          // Har bachay ke liye ek chip banegi jisko click kar ke map udhar chala jayega
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: ActionChip(
                              avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: child['color'], shape: BoxShape.circle)),
                              label: Text(child['name'], style: const TextStyle(fontWeight: FontWeight.w900)),
                              onPressed: () => _focusChild(child['name'], child['pos']), // Click par focus wala function
                              backgroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.black26,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.5, end: 0);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

