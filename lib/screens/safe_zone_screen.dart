import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class SafeZoneScreen extends StatefulWidget {
  final String uid;
  const SafeZoneScreen({super.key, required this.uid});

  @override
  State<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends State<SafeZoneScreen> {
  final _fs = FirestoreService();
  bool _loading = true;
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildUid;
  List<Map<String, dynamic>> _safeZones = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    await _loadChildren();
    await _loadSafeZones();
  }

  Future<void> _loadSafeZones() async {
    final zones = await _fs.getSafeZones(widget.uid);
    if (mounted) setState(() => _safeZones = zones);
  }

  Future<void> _loadChildren() async {
    final user = await _fs.getUser(widget.uid);
    final List<dynamic> childrenUids = user?['children'] ?? [];
    if (childrenUids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final profiles = await _fs.getChildrenProfiles(childrenUids);
    if (mounted) {
      setState(() {
        _children = profiles;
        if (_children.isNotEmpty) _selectedChildUid = _children[0]['uid'];
        _loading = false;
      });
    }
  }

  void _addZone() async {
    if (_selectedChildUid == null) return;
    
    final nameCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Safe Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Zone Name (e.g. School)')),
            const SizedBox(height: 12),
            TextField(controller: radiusCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Radius (meters)', suffixText: 'm')),
            const SizedBox(height: 12),
            const Text('Note: This will use the child\'s current location as the center of the safe zone.', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final r = double.tryParse(radiusCtrl.text);
              if (name.isNotEmpty && r != null && r > 0) {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                
                final loc = await _fs.getChildLocation(_selectedChildUid!);
                if (loc == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find child location!')));
                    setState(() => _loading = false);
                  }
                  return;
                }

                await _fs.addSafeZone(widget.uid, name, loc['latitude'], loc['longitude'], r);
                _loadSafeZones();
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Add Zone'),
          ),
        ],
      ),
    );
  }

  void _deleteZone(Map<String, dynamic> zone) async {
    await _fs.removeSafeZone(widget.uid, zone);
    _loadSafeZones();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Safe Zone'),
        actions: [IconButton(onPressed: _loadChildren, icon: const Icon(Icons.refresh))],
      ),
      body: _children.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No children connected yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _loadChildren, child: const Text('Check for Connections')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Child', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Choose a child to manage zones for', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedChildUid,
                    isExpanded: true,
                    items: _children.map((c) => DropdownMenuItem<String>(
                      value: c['uid'].toString(),
                      child: Text(c['name'] ?? c['email'] ?? 'Unknown User'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedChildUid = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.child_care),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Safe Zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      TextButton.icon(onPressed: _addZone, icon: const Icon(Icons.add), label: const Text('Add Zone')),
                    ],
                  ),
                  const Divider(),
                  if (_safeZones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.location_off, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No safe zones created yet.', style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _safeZones.length,
                      itemBuilder: (context, i) {
                        final zone = _safeZones[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.radar, color: Colors.blue)),
                            title: Text(zone['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Radius: ${zone['radius'].toStringAsFixed(0)}m'),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteZone(zone)),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(child: Text('Child will trigger an alert ONLY if they are outside ALL safe zones at once.', style: TextStyle(fontSize: 12, color: Colors.orange))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
