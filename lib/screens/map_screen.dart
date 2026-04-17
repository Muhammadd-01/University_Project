// ============================================
// map_screen.dart - Map Screen (Child Ki Location Dekho)
// ============================================
// Yeh screen SIRF parent ke liye hai
// Is screen pe OpenStreetMap dikhta hai jismein:
// 1. Child ki location pe red marker lagta hai
// 2. Agar boundary set hai toh blue circle dikhti hai (safe zone)
// 3. Refresh button se latest location fetch hoti hai
// 4. Boundary set karne ka button hai (circle icon) - dialog khulta hai radius enter karne ke liye
//
// flutter_map package use kiya hai jo OpenStreetMap tiles dikhata hai
// Google Maps ki tarah API key nahi chahiye (free hai!)
// latlong2 package se LatLng object banate hain (latitude, longitude)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firestore_service.dart';

class MapScreen extends StatefulWidget {
  final String uid; // Parent ki uid
  const MapScreen({super.key, required this.uid});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _firestoreService = FirestoreService();
  final _mapController = MapController(); // Map ko control karne ke liye

  LatLng? _childLocation;       // Child ki location (lat, lng)
  Map<String, dynamic>? _boundary; // Boundary data (lat, lng, radius)
  String? _connectedChildUid;   // Connected child ki uid
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildLocation(); // Screen load hote hi child ki location fetch karo
  }

  // _loadChildLocation() - Firestore se child ki location aur boundary data fetch karo
  void _loadChildLocation() async {
    // Step 1: Parent ka data fetch karo taake connected child ki uid mile
    final userData = await _firestoreService.getUser(widget.uid);

    // Agar parent kisi child se connected nahi hai
    if (userData == null || userData['connectedTo'] == null) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle child ko connect karo!')),
        );
      }
      return;
    }

    // Connected child ki uid
    _connectedChildUid = userData['connectedTo'];

    // Step 2: Child ki location fetch karo "locations" collection se
    final locData = await _firestoreService.getChildLocation(_connectedChildUid!);

    // Step 3: Boundary data fetch karo (agar set hai)
    final boundaryData = await _firestoreService.getBoundary(widget.uid);

    if (mounted) {
      setState(() {
        // Location data se LatLng object banao
        if (locData != null) {
          _childLocation = LatLng(locData['latitude'], locData['longitude']);
        }
        _boundary = boundaryData;
        _loading = false;
      });
    }
  }

  // _setBoundary() - Parent boundary (safe zone) set kare
  // AlertDialog khulta hai jismein radius (meters) enter karte hain
  // Boundary ka center child ki current location hoti hai
  void _setBoundary() {
    // Child ki location chahiye boundary set karne ke liye
    if (_childLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child ki location abhi nahi mili!')),
      );
      return;
    }

    // Radius input ke liye controller (default 500 meters)
    final radiusController = TextEditingController(text: '500');

    // Dialog dikhao
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Boundary Set Karo'),
        content: TextField(
          controller: radiusController,
          keyboardType: TextInputType.number, // Sirf numbers
          decoration: const InputDecoration(
            labelText: 'Radius (meters)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          // Cancel button
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          // Set button - boundary save karo
          ElevatedButton(
            onPressed: () async {
              // User ka enter kiya radius lo, agar invalid ho toh 500 default
              final radius = double.tryParse(radiusController.text) ?? 500;

              // Firestore mein boundary save karo
              // Center = child ki current location
              await _firestoreService.setBoundary(
                widget.uid,
                _childLocation!.latitude,
                _childLocation!.longitude,
                radius,
              );

              if (mounted) {
                Navigator.pop(ctx); // Dialog band karo
                _loadChildLocation(); // Map refresh karo (circle dikhane ke liye)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Boundary set: ${radius.toInt()}m')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Location'),
        actions: [
          // Refresh button - latest location dobara fetch karo
          IconButton(onPressed: _loadChildLocation, icon: const Icon(Icons.refresh)),
          // Boundary set button (circle icon)
          IconButton(onPressed: _setBoundary, icon: const Icon(Icons.circle_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _childLocation == null
              // Child ki location nahi mili
              ? const Center(child: Text('Child ki location abhi nahi mili'))
              // Map dikhao with child marker
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _childLocation!, // Map child ki location pe center ho
                    initialZoom: 15, // Zoom level (15 = street level)
                  ),
                  children: [
                    // OpenStreetMap tiles - yeh map ki images load karta hai
                    // Free hai, koi API key nahi chahiye
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.childguard.childguard',
                    ),

                    // Boundary circle dikhao (agar parent ne set ki hai)
                    // Blue transparent circle jo safe zone represent karti hai
                    if (_boundary != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(_boundary!['lat'], _boundary!['lng']),
                            radius: _boundary!['radius'].toDouble(),
                            useRadiusInMeter: true, // Radius meters mein hai, pixels mein nahi
                            color: Colors.blue.withValues(alpha: 0.2), // Transparent blue fill
                            borderColor: Colors.blue, // Blue border
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                    // Child ka location marker (red pin)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _childLocation!, // Child ki position
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
