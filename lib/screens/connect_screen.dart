// ============================================
// connect_screen.dart - Parent-Child Connection Screen
// ============================================
// Is screen se parent aur child ek dusre se connect hote hain
// Kaise kaam karta hai:
//
// PARENT SIDE:
// - Parent ko apna 6-digit code dikhta hai (jo register pe generate hua tha)
// - Parent yeh code child ko batata hai (verbally ya message se)
//
// CHILD SIDE:
// - Child ko ek TextField milta hai jismein parent ka code dalta hai
// - Code enter karke "Connect" button dabata hai
// - System Firestore mein dhundta hai kaunsa parent hai is code wala
// - Match hone pe dono ke documents mein connectedTo field update hoti hai
//
// Connection ke baad dono ko green tick dikhta hai "Connected!"

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ConnectScreen extends StatefulWidget {
  final String role; // "parent" ya "child"
  final String uid;  // User ki uid
  const ConnectScreen({super.key, required this.role, required this.uid});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  // Controller for code input (child side)
  final _codeController = TextEditingController();
  final _firestoreService = FirestoreService();

  String? _connectionCode; // Parent ka 6-digit code
  String? _connectedTo;    // Connected user ki uid (null agar connected nahi)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData(); // Screen load hote hi user data fetch karo
  }

  // _loadData() - Firestore se user ka data fetch karo
  // Check karo connection code kya hai aur connected hai ya nahi
  void _loadData() async {
    final data = await _firestoreService.getUser(widget.uid);
    if (data != null) {
      setState(() {
        _connectionCode = data['connectionCode']; // Parent ka code (child ke liye null hoga)
        _connectedTo = data['connectedTo'];       // Connected user ki uid
        _loading = false;
      });
    }
  }

  // _connect() - Child code enter karke parent se connect ho
  void _connect() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return; // Empty code na bhejo

    setState(() => _loading = true);

    // connectChild() Firestore mein code se parent dhundta hai
    // Agar mila toh dono ke connectedTo mein ek dusre ki uid save hoti hai
    final success = await _firestoreService.connectChild(code, widget.uid);

    if (mounted) {
      if (success) {
        // Connection successful!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected successfully!')),
        );
        _loadData(); // Screen refresh karo taake "Connected!" dikhe
      } else {
        // Code galat hai
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
                  // Agar already connected hai toh green card dikhao
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

                  // ===== PARENT VIEW =====
                  // Parent ko apna 6-digit code dikhao
                  // Yeh code child ko dena hai
                  if (widget.role == 'parent' && _connectionCode != null) ...[
                    const Text('Apna code child ko do:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    // Code bade font mein dikhao taake easy ho padhna
                    Text(
                      _connectionCode!,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8, // Letters ke beech spacing
                      ),
                    ),
                  ],

                  // ===== CHILD VIEW =====
                  // Child ko code enter karne do (agar abhi connected nahi hai)
                  if (widget.role == 'child' && _connectedTo == null) ...[
                    const Text('Parent ka code enter karo:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    // Code input field
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number, // Sirf numbers
                      decoration: const InputDecoration(
                        labelText: 'Connection Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Connect button
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
