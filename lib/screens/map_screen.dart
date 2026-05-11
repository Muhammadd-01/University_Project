// map_screen.dart - OpenStreetMap pe child ki location
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final String uid, role;
  const MapScreen({super.key, required this.uid, required this.role});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _fs = FirestoreService();
  final _ls = LocationService();
  final _mapCtrl = MapController();
  List<Map<String, dynamic>> _childrenProfiles = [];
  List<Map<String, dynamic>> _safeZones = [];
  bool _loading = true;

  // Colors for different children
  final List<Color> _markerColors = [
    Colors.red, Colors.blue, Colors.green, 
    Colors.purple, Colors.orange, Colors.teal
  ];

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final user = await _fs.getUser(widget.uid);
    List<dynamic> targetUids = [];
    
    if (widget.role == 'parent') {
      targetUids = user?['children'] ?? [];
    } else {
      // Child tracking parent: parent is the 'connectedTo' ID
      final parentUid = user?['connectedTo'];
      if (parentUid != null) {
        targetUids.add(parentUid);
        // Check if this parent has a co-parent linked
        final parentData = await _fs.getUser(parentUid);
        if (parentData != null && parentData['coParent'] != null) {
          targetUids.add(parentData['coParent']);
        }
      }
    }

    if (targetUids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Fetch all profiles to get names
    final profiles = await _fs.getChildrenProfiles(targetUids);
    // Boundary check: everyone can see the boundary on map if it exists
    final zones = await _fs.getSafeZones(widget.role == 'parent' ? widget.uid : user?['connectedTo']);
    
    if (mounted) setState(() { _childrenProfiles = profiles; _safeZones = zones; _loading = false; });
  }

  void _focusChild(String name, LatLng pos) async {
    // 1. Center the map
    _mapCtrl.move(pos, 16);

    // 2. Calculate Distance
    final myPos = await _ls.getCurrentLocation();
    if (myPos != null) {
      final meters = _ls.getDistance(myPos.latitude, myPos.longitude, pos.latitude, pos.longitude);
      String distText = meters < 1000 
          ? "${meters.round()}m away" 
          : "${(meters / 1000).toStringAsFixed(1)}km away";

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Icon(Icons.location_on, color: Theme.of(context).primaryColor, size: 40),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(distText, style: TextStyle(color: Colors.blue[800], fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                const Text('Real-time tracking is active', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Cannot calculate distance: Please enable your GPS'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'parent';
    return Scaffold(
      appBar: AppBar(title: const Text('Live Map'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _fs.getMultiLocationStream(_childrenProfiles.map((p) => p['uid']?.toString()).whereType<String>().toList()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Firestore Error: ${snapshot.error}\n\nPlease click the link in your console to create the index if shown.', 
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ));
                }

                List<Marker> markers = [];
                List<Map<String, dynamic>> activeChildren = [];
                LatLng? firstLoc;

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final loc = doc.data() as Map<String, dynamic>;
                    if (loc['latitude'] == null || loc['longitude'] == null) continue;
                    
                    final pos = LatLng(loc['latitude'], loc['longitude']);
                    firstLoc ??= pos;

                    final profileIdx = _childrenProfiles.indexWhere((p) => p['uid'] == doc.id);
                    final name = profileIdx != -1 ? _childrenProfiles[profileIdx]['name'] : 'Unknown';
                    final color = _markerColors[profileIdx != -1 ? (profileIdx % _markerColors.length) : 0];

                    activeChildren.add({'name': name, 'pos': pos, 'color': color});

                    markers.add(Marker(
                      point: pos, width: 80, height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          Icon(Icons.location_pin, color: color, size: 40),
                        ],
                      ),
                    ));
                  }
                }

                if (markers.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.location_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 12), 
                    const Text('No locations available yet', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(isParent ? 'Tracking: ${_childrenProfiles.length} children' : 'Tracking Default Parent', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    TextButton(onPressed: _load, child: const Text('Refresh Connections')),
                  ]));
                }

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapCtrl, 
                      options: MapOptions(
                        initialCenter: firstLoc ?? const LatLng(0, 0), 
                        initialZoom: 15,
                        // Enable rotation for a more dynamic feel
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ), 
                      children: [
                        TileLayer(
                          // Using CartoDB Voyager for a cleaner, premium 3D-ish feel
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.childguard.childguard',
                        ),
                        if (_safeZones.isNotEmpty) CircleLayer(circles: _safeZones.map((z) => CircleMarker(
                          point: LatLng(z['lat'], z['lng']), radius: z['radius'].toDouble(),
                          useRadiusInMeter: true, color: Colors.blue.withOpacity(0.1), borderColor: Colors.blue, borderStrokeWidth: 1,
                        )).toList()),
                      MarkerLayer(markers: markers),
                    ]),
                    
                    // Child Focus Bar at bottom
                    Positioned(
                      bottom: 20, left: 0, right: 0,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: activeChildren.length,
                              itemBuilder: (context, index) {
                                final child = activeChildren[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ActionChip(
                                    avatar: CircleAvatar(backgroundColor: child['color'], radius: 10),
                                    label: Text(child['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _focusChild(child['name'], child['pos']),
                                    backgroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: Colors.black26,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                            child: Text('Live: ${markers.length}/${_childrenProfiles.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
