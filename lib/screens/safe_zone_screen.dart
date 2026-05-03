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
  final _radiusController = TextEditingController(text: '500');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    await _loadChildren();
    await _loadCurrentBoundary();
  }

  Map<String, dynamic>? _currentBoundary;

  Future<void> _loadCurrentBoundary() async {
    final b = await _fs.getBoundary(widget.uid);
    if (mounted) setState(() => _currentBoundary = b);
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

  void _save() async {
    if (_selectedChildUid == null) return;
    final r = double.tryParse(_radiusController.text);
    if (r == null || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid radius!')));
      return;
    }

    final loc = await _fs.getChildLocation(_selectedChildUid!);
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child location not found! Need location to set center.')));
      return;
    }

    await _fs.setBoundary(widget.uid, loc['latitude'], loc['longitude'], r);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safe zone updated successfully!')));
      Navigator.pop(context);
    }
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
                  const Text('Choose which child to set a boundary for', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.child_care),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_currentBoundary != null) ...[
                    Card(
                      color: Colors.blue.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.blue, width: 0.5)),
                      child: ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.blue),
                        title: const Text('Current Active Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Radius: ${_currentBoundary!['radius'].toStringAsFixed(0)}m\nCenter: ${_currentBoundary!['lat'].toStringAsFixed(4)}, ${_currentBoundary!['lng'].toStringAsFixed(4)}', 
                          style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Safe Radius (meters)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Alerts will trigger if the child leaves this area', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _radiusController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.radar),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixText: 'm',
                      hintText: 'e.g. 500',
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Activate Safe Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Note: Center will be set to child\'s current location', 
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
    );
  }
}
