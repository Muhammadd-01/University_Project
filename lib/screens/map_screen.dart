// map_screen.dart - OpenStreetMap pe child ki location
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/firestore_service.dart';

class MapScreen extends StatefulWidget {
  final String uid;
  const MapScreen({super.key, required this.uid});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _fs = FirestoreService();
  final _mapCtrl = MapController();
  LatLng? _childLoc;
  Map<String, dynamic>? _boundary;
  String? _childUid;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final user = await _fs.getUser(widget.uid);
    if (user == null || user['connectedTo'] == null) {
      if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to a child first!'))); }
      return;
    }
    _childUid = user['connectedTo'];
    final loc = await _fs.getChildLocation(_childUid!);
    final bnd = await _fs.getBoundary(widget.uid);
    if (mounted) setState(() { if (loc != null) _childLoc = LatLng(loc['latitude'], loc['longitude']); _boundary = bnd; _loading = false; });
  }

  void _setBoundary() {
    if (_childLoc == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child location not available!'))); return; }
    final rc = TextEditingController(text: '500');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Set Safe Zone'), icon: const Icon(Icons.shield),
      content: TextField(controller: rc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Radius (meters)', suffixText: 'm')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final r = double.tryParse(rc.text) ?? 500;
          await _fs.setBoundary(widget.uid, _childLoc!.latitude, _childLoc!.longitude, r);
          if (mounted) { Navigator.pop(ctx); _load(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Safe zone set: ${r.toInt()}m radius'))); }
        }, child: const Text('Set')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Map'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        IconButton(onPressed: _setBoundary, icon: const Icon(Icons.shield_outlined), tooltip: 'Set Safe Zone'),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _childLoc == null ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.location_off, size: 60, color: Colors.grey),
              SizedBox(height: 12), Text('Child location not available yet', style: TextStyle(color: Colors.grey)),
            ]))
          : FlutterMap(mapController: _mapCtrl, options: MapOptions(initialCenter: _childLoc!, initialZoom: 15), children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.childguard.childguard'),
              if (_boundary != null) CircleLayer(circles: [CircleMarker(
                point: LatLng(_boundary!['lat'], _boundary!['lng']), radius: _boundary!['radius'].toDouble(),
                useRadiusInMeter: true, color: Colors.blue.withValues(alpha: 0.15), borderColor: Colors.blue, borderStrokeWidth: 2,
              )]),
              MarkerLayer(markers: [Marker(point: _childLoc!, width: 50, height: 50, child: const Icon(Icons.location_pin, color: Colors.red, size: 50))]),
            ]),
    );
  }
}
