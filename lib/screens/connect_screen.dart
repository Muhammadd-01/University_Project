// connect_screen.dart - Parent child connection code se
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ConnectScreen extends StatefulWidget {
  final String role, uid;
  const ConnectScreen({super.key, required this.role, required this.uid});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _codeC = TextEditingController();
  final _fs = FirestoreService();
  String? _code, _connectedTo, _connectedEmail, _connectedName;
  String? _coParentUid, _coParentName;
  List<Map<String, dynamic>> _childrenProfiles = [];
  bool _loading = true;
  static const _platform = MethodChannel('com.childguard.childguard/sms');

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final data = await _fs.getUser(widget.uid);
    if (data != null) {
      String? connEmail;
      String? connName;
      String? cpName;
      List<Map<String, dynamic>> profiles = [];
      
      if (widget.role == 'parent') {
        if (data['children'] != null) {
          profiles = await _fs.getChildrenProfiles(data['children'] as List<dynamic>);
        }
        if (data['coParent'] != null) {
          final cp = await _fs.getUser(data['coParent']);
          cpName = cp?['name'];
        }
      } else if (data['connectedTo'] != null) {
        final otherUser = await _fs.getUser(data['connectedTo']);
        connEmail = otherUser?['email'];
        connName = otherUser?['name'];
      }
      
      if (mounted) {
        setState(() { 
          _code = data['connectionCode']; 
          _connectedTo = data['connectedTo']; 
          _connectedEmail = connEmail;
          _connectedName = connName;
          _coParentUid = data['coParent'];
          _coParentName = cpName;
          _childrenProfiles = profiles;
          _loading = false; 
        });
        
        // Sync SharedPreferences for background service
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', widget.uid);
        await prefs.setString('role', widget.role);
        if (data['connectedTo'] != null) {
          await prefs.setString('parentId', data['connectedTo']);
        }
        
        // Refresh native service
        try {
          await _platform.invokeMethod('startService');
        } catch (e) {
          debugPrint('Error refreshing service: $e');
        }
      }
    }
  }

  void _sendPartnerRequest() async {
    final code = _codeC.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _loading = true);
    // Get current user name for the request
    final me = await _fs.getUser(widget.uid);
    final ok = await _fs.sendPartnerRequest(code, widget.uid, me?['name'] ?? 'Partner');
    
    if (mounted) {
      setState(() => _loading = false);
      _codeC.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Request sent!' : 'Invalid code or already linked')),
      );
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
            const SizedBox(height: 10),
            // ===== PARENT VIEW: Partner Requests =====
            if (widget.role == 'parent' && _coParentUid == null) ...[
              StreamBuilder(
                stream: _fs.getPartnerRequests(widget.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                  final requests = snapshot.data!.docs;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Partner Requests:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 8),
                      ...requests.map((doc) {
                        final req = doc.data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                            title: Text(req['fromName']),
                            subtitle: const Text('Wants to link as partner'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                                  await _fs.acceptPartnerRequest(widget.uid, req['fromUid']);
                                  _load();
                                }),
                                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () async {
                                  await _fs.rejectPartnerRequest(widget.uid, req['fromUid']);
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ],
            // ===== PARENT VIEW: Linked Partner Info =====
            if (widget.role == 'parent' && _coParentUid != null)
              Card(
                color: Colors.blue[50],
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.favorite, color: Colors.white)),
                  title: Text(_coParentName ?? 'Partner Linked'),
                  subtitle: const Text('Co-Parenting Active'),
                  trailing: const Icon(Icons.verified, color: Colors.blue),
                ),
              ),
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
                      title: Text(_childrenProfiles[i]['name'] ?? 'Unknown Child'),
                      subtitle: Text(_childrenProfiles[i]['email'] ?? ''),
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
              const Text('Shared Connection Code', style: TextStyle(fontSize: 16)),
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
              if (_coParentUid == null) ...[
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Link with Spouse / Partner', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeC, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: 'Enter Partner Code'),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _sendPartnerRequest, icon: const Icon(Icons.link), label: const Text('Send Link Request'))),
              ]
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
