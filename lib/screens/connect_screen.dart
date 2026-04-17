// connect_screen.dart - Parent child connection code se
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ConnectScreen extends StatefulWidget {
  final String role, uid;
  const ConnectScreen({super.key, required this.role, required this.uid});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _codeC = TextEditingController();
  final _fs = FirestoreService();
  String? _code, _connectedTo, _connectedEmail, _connectedName; // Added _connectedName
  List<Map<String, dynamic>> _childrenProfiles = []; // Added children list
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final data = await _fs.getUser(widget.uid);
    if (data != null) {
      String? connEmail;
      String? connName;
      List<Map<String, dynamic>> profiles = [];
      
      if (widget.role == 'parent' && data['children'] != null) {
        // Parent view: fetch multiple children
        profiles = await _fs.getChildrenProfiles(data['children'] as List<dynamic>);
      } else if (data['connectedTo'] != null) {
        // Child view: fetch single parent
        final otherUser = await _fs.getUser(data['connectedTo']);
        connEmail = otherUser?['email'];
        connName = otherUser?['name'];
      }
      
      setState(() { 
        _code = data['connectionCode']; 
        _connectedTo = data['connectedTo']; 
        _connectedEmail = connEmail;
        _connectedName = connName;
        _childrenProfiles = profiles;
        _loading = false; 
      });
    }
  }

  void _connect() async {
    if (_codeC.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final ok = await _fs.connectChild(_codeC.text.trim(), widget.uid);
    if (mounted) {
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code!')));
        setState(() => _loading = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected successfully!')));
        _load(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // ===== PARENT VIEW: List all children =====
            if (widget.role == 'parent' && _childrenProfiles.isNotEmpty) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('Connected Children:', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _childrenProfiles.length,
                itemBuilder: (context, i) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.child_care)),
                      title: Text(_childrenProfiles[i]['name'] ?? 'Unknown Child'), // Show name
                      subtitle: Text(_childrenProfiles[i]['email'] ?? ''), // Show email as secondary
                      trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
            // ===== CHILD VIEW: Show parent info =====
            if (widget.role == 'child' && _connectedTo != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 28),
                        SizedBox(width: 12),
                        Text('Connected!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                      if (_connectedName != null || _connectedEmail != null) ...[
                        const SizedBox(height: 8),
                        Text('Linked with: ${_connectedName ?? _connectedEmail}', style: TextStyle(color: Colors.green[700], fontSize: 13)),
                      ]
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            // Parent view - show code
            if (widget.role == 'parent' && _code != null) ...[
              Icon(Icons.qr_code, size: 60, color: color.primary),
              const SizedBox(height: 16),
              const Text('Your Connection Code', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Center(
                child: Card(
                  color: color.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                    child: Text(
                      _code!, 
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 10, color: color.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Share this code with your child', style: TextStyle(color: Colors.grey[600])),
            ],
            // Child view - enter code
            if (widget.role == 'child' && _connectedTo == null) ...[
              Icon(Icons.link, size: 60, color: color.primary),
              const SizedBox(height: 16),
              const Text('Enter Parent\'s Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              TextField(
                controller: _codeC, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(hintText: '000000'),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _connect, child: const Text('Connect'))),
            ],
          ],
        ),
      ),
    );
  }
}
