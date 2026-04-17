import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firestore_service.dart';

// Map screen - parent child ki location dekhta hai
class MapScreen extends StatefulWidget {
  final String uid;
  const MapScreen({super.key, required this.uid});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _firestoreService = FirestoreService();
  final _mapController = MapController();
  LatLng? _childLocation;
  Map<String, dynamic>? _boundary;
  String? _connectedChildUid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildLocation();
  }

  // Child ki location load karo
  void _loadChildLocation() async {
    final userData = await _firestoreService.getUser(widget.uid);
    if (userData == null || userData['connectedTo'] == null) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pehle child ko connect karo!')),
        );
      }
      return;
    }
    _connectedChildUid = userData['connectedTo'];
    // Child location fetch karo
    final locData = await _firestoreService.getChildLocation(_connectedChildUid!);
    // Boundary fetch karo
    final boundaryData = await _firestoreService.getBoundary(widget.uid);
    if (mounted) {
      setState(() {
        if (locData != null) {
          _childLocation = LatLng(locData['latitude'], locData['longitude']);
        }
        _boundary = boundaryData;
        _loading = false;
      });
    }
  }

  // Boundary set karne ka dialog
  void _setBoundary() {
    if (_childLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child ki location abhi nahi mili!')),
      );
      return;
    }
    final radiusController = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Boundary Set Karo'),
        content: TextField(
          controller: radiusController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Radius (meters)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final radius = double.tryParse(radiusController.text) ?? 500;
              await _firestoreService.setBoundary(
                widget.uid,
                _childLocation!.latitude,
                _childLocation!.longitude,
                radius,
              );
              if (mounted) {
                Navigator.pop(ctx);
                _loadChildLocation(); // Refresh karo
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
          // Refresh button
          IconButton(onPressed: _loadChildLocation, icon: const Icon(Icons.refresh)),
          // Boundary set button
          IconButton(onPressed: _setBoundary, icon: const Icon(Icons.circle_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _childLocation == null
              ? const Center(child: Text('Child ki location abhi nahi mili'))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _childLocation!,
                    initialZoom: 15,
                  ),
                  children: [
                    // OpenStreetMap tiles
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.childguard.childguard',
                    ),
                    // Boundary circle dikhao (agar set hai)
                    if (_boundary != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(_boundary!['lat'], _boundary!['lng']),
                            radius: _boundary!['radius'].toDouble(),
                            useRadiusInMeter: true,
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    // Child ka marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _childLocation!,
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
