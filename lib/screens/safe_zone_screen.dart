import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add Safe Zone', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl, 
              decoration: const InputDecoration(
                labelText: 'Zone Name',
                hintText: 'e.g. School, Home',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: radiusCtrl, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(
                labelText: 'Radius (meters)', 
                suffixText: 'm',
                prefixIcon: Icon(Icons.radar_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will use the child\'s current location as the center point.', 
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final r = double.tryParse(radiusCtrl.text);
              if (name.isNotEmpty && r != null && r > 0) {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                
                final loc = await _fs.getChildLocation(_selectedChildUid!);
                if (loc == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Could not find child location!')));
                    setState(() => _loading = false);
                  }
                  return;
                }

                await _fs.addSafeZone(widget.uid, name, loc['latitude'], loc['longitude'], r);
                _loadSafeZones();
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Create Zone'),
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
    if (_loading) return const Scaffold(body: LoadingWidget(message: 'Loading safety zones...'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Safe Zones', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _loadInitialData, icon: const Icon(Icons.refresh_rounded, color: Colors.black))],
      ),
      body: _children.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('No children connected.', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  OutlinedButton(onPressed: _loadChildren, child: const Text('Check Connections')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monitoring Child', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedChildUid,
                    isExpanded: true,
                    items: _children.map((c) => DropdownMenuItem<String>(
                      value: c['uid'].toString(),
                      child: Text(c['name'] ?? c['email'] ?? 'Child'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedChildUid = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.child_care_rounded),
                    ),
                  ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Configured Zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ElevatedButton.icon(
                        onPressed: _addZone, 
                        icon: const Icon(Icons.add_rounded, size: 18), 
                        label: const Text('Add Zone'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ).animate(delay: 200.ms).fadeIn(),
                  
                  const SizedBox(height: 16),
                  
                  if (_safeZones.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.location_off_outlined, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No safe zones established yet.', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _safeZones.length,
                      itemBuilder: (context, i) {
                        final zone = _safeZones[i];
                        return _buildZoneCard(zone).animate(delay: (300 + (i * 100)).ms).fadeIn().slideY(begin: 0.1, end: 0);
                      },
                    ),
                  
                  const SizedBox(height: 40),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.indigo),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Smart Alert: You will only receive a notification if the child leaves ALL defined safe zones.',
                            style: TextStyle(fontSize: 13, color: Colors.indigo[900], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 600.ms).fadeIn(),
                ],
              ),
            ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.radar_rounded, color: Colors.indigo),
        ),
        title: Text(zone['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Radius: ${zone['radius'].toStringAsFixed(0)}m'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () => _deleteZone(zone),
        ),
      ),
    );
  }
}

