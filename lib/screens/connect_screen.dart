import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

// Connect screen - parent code dikhe, child code enter kare
class ConnectScreen extends StatefulWidget {
  final String role;
  final String uid;
  const ConnectScreen({super.key, required this.role, required this.uid});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _codeController = TextEditingController();
  final _firestoreService = FirestoreService();
  String? _connectionCode;
  String? _connectedTo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // User data load karo
  void _loadData() async {
    final data = await _firestoreService.getUser(widget.uid);
    if (data != null) {
      setState(() {
        _connectionCode = data['connectionCode'];
        _connectedTo = data['connectedTo'];
        _loading = false;
      });
    }
  }

  // Child code enter karke connect kare
  void _connect() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    final success = await _firestoreService.connectChild(code, widget.uid);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected successfully!')),
        );
        _loadData(); // Refresh karo
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid code!')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Agar already connected hai
                  if (_connectedTo != null)
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '✅ Connected!',
                          style: TextStyle(fontSize: 20, color: Colors.green[800]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Parent ko code dikhao
                  if (widget.role == 'parent' && _connectionCode != null) ...[
                    const Text('Apna code child ko do:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    Text(
                      _connectionCode!,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8),
                    ),
                  ],
                  // Child ko code enter karne do
                  if (widget.role == 'child' && _connectedTo == null) ...[
                    const Text('Parent ka code enter karo:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Connection Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _connect,
                        child: const Text('Connect'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
