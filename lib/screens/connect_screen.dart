// connect_screen.dart - Parent child connection
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Yeh screen Parent aur Child ke darmiyan connection banati hai
class ConnectScreen extends StatefulWidget {
  final String role, uid;
  const ConnectScreen({super.key, required this.role, required this.uid});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _codeC = TextEditingController(); // Connection code likhne ke liye controller
  final _fs = FirestoreService();
  
  // Variables jo connection status store karenge
  String? _code, _connectedTo, _connectedEmail, _connectedName;
  String? _coParentUid, _coParentName;
  List<Map<String, dynamic>> _childrenProfiles = [];
  bool _loading = true; // Jab tak data aye, loading true rahegi
  
  // Native Android se SMS service shuru karne ke liye channel
  static const _platform = MethodChannel('com.childguard.childguard/sms');

  @override
  void initState() { super.initState(); _load(); }

  // Database se user aur uske connections ka data load karne ka function
  void _load() async {
    final data = await _fs.getUser(widget.uid);
    if (data != null) {
      String? connEmail;
      String? connName;
      String? cpName;
      List<Map<String, dynamic>> profiles = [];
      
      // Agar user parent hai toh uske bachon aur partner (co-parent) ki list nikalo
      if (widget.role == 'parent') {
        if (data['children'] != null) {
          profiles = await _fs.getChildrenProfiles(data['children'] as List<dynamic>);
        }
        if (data['coParent'] != null) {
          final cp = await _fs.getUser(data['coParent']);
          cpName = cp?['name'];
        }
      } 
      // Agar child hai toh uske parent ka data nikalo
      else if (data['connectedTo'] != null) {
        final otherUser = await _fs.getUser(data['connectedTo']);
        connEmail = otherUser?['email'];
        connName = otherUser?['name'];
      }
      
      // UI ko naye data ke sath update karo
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
        
        // Data phone ki memory (SharedPreferences) mein save karo
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', widget.uid);
        await prefs.setString('role', widget.role);
        if (data['connectedTo'] != null) {
          await prefs.setString('parentId', data['connectedTo']);
        }
        
        // Native background service start karo (Panic button waghera ke liye)
        try {
          await _platform.invokeMethod('startService');
        } catch (e) {
          debugPrint('Error refreshing service: $e');
        }
      }
    }
  }

  // Apne partner (spouse) ko monitoring me shamil karne ki request bhejna
  void _sendPartnerRequest() async {
    final code = _codeC.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _loading = true);
    final me = await _fs.getUser(widget.uid);
    final ok = await _fs.sendPartnerRequest(code, widget.uid, me?['name'] ?? 'Partner');
    
    // Request bhejne ke baad message dikhao
    if (mounted) {
      setState(() => _loading = false);
      _codeC.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Partner request sent!' : '❌ Invalid code or already linked'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  // Child code enter kar ke parent se connect hota hai
  void _connect() async {
    if (_codeC.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final ok = await _fs.connectChild(_codeC.text.trim(), widget.uid);
    if (mounted) {
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Invalid code!')));
        setState(() => _loading = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Connected successfully!')));
        _load(); // Naya data load karo connection banne ke baad
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agar data load ho raha hai toh loading screen dikhao
    if (_loading) return const Scaffold(body: LoadingWidget(message: 'Loading connections...'));

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Device Connection', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          // Refresh button takay data dobara server se le sakien
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.black)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== PARENT VIEW: Partner Requests Dikhana =====
            if (widget.role == 'parent' && _coParentUid == null) ...[
              StreamBuilder(
                stream: _fs.getPartnerRequests(widget.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                  final requests = snapshot.data!.docs;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Partner Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...requests.map((doc) {
                        final req = doc.data() as Map<String, dynamic>;
                        return _buildRequestCard(req, doc.id);
                      }),
                      const SizedBox(height: 30),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.1, end: 0);
                },
              ),
            ],

            // ===== PARENT VIEW: Linked Partner ki Information =====
            if (widget.role == 'parent' && _coParentUid != null)
              _buildStatusCard(
                'Co-Parent Linked',
                'Successfully linked with ${_coParentName ?? "Partner"}',
                Icons.favorite_rounded,
                Colors.pinkAccent,
              ).animate().fadeIn().scale(),

            const SizedBox(height: 16),

            // ===== PARENT VIEW: Sab connected bachon ki list =====
            if (widget.role == 'parent' && _childrenProfiles.isNotEmpty) ...[
              const Text('Connected Children', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _childrenProfiles.length,
                itemBuilder: (context, i) {
                  return _buildConnectionCard(
                    _childrenProfiles[i]['name'] ?? 'Child',
                    _childrenProfiles[i]['email'] ?? '',
                    Icons.child_care_rounded,
                    colorScheme.primary,
                  );
                },
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 30),
            ],

            // ===== CHILD VIEW: Child ko apna parent dikhana =====
            if (widget.role == 'child' && _connectedTo != null)
              _buildStatusCard(
                'Safety Linked!',
                'You are connected to ${_connectedName ?? _connectedEmail}',
                Icons.verified_user_rounded,
                Colors.green,
              ).animate().fadeIn().scale(),

            const SizedBox(height: 20),

            // Main Action Area (Parent ke liye apna code dikhana aur Child ke liye code enter karne ka dabha)
            if (widget.role == 'parent') _buildParentActionArea(colorScheme),
            if (widget.role == 'child' && _connectedTo == null) _buildChildActionArea(colorScheme),
          ],
        ),
      ),
    );
  }

  // Partner request ka card UI
  Widget _buildRequestCard(Map<String, dynamic> req, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.person_rounded, color: Colors.orange)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['fromName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('Wants to share monitoring', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          // Accept button
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
            onPressed: () async {
              await _fs.acceptPartnerRequest(widget.uid, req['fromUid']);
              _load();
            },
          ),
          // Reject button
          IconButton(
            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
            onPressed: () async {
              await _fs.rejectPartnerRequest(widget.uid, req['fromUid']);
            },
          ),
        ],
      ),
    );
  }

  // Status dikhane wala general card
  Widget _buildStatusCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 14, color: color.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Connected baccho ka chota list card
  Widget _buildConnectionCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
      ),
    );
  }

  // Parent ke page par code dikhana aur partner link karne ka box
  Widget _buildParentActionArea(ColorScheme colorScheme) {
    return Column(
      children: [
        const Center(child: Text('Your Unique Connection Code', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: colorScheme.primary.withOpacity(0.1), width: 2),
          ),
          child: Text(
            _code ?? '000000',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10, color: colorScheme.primary),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        const Text('Share this code with your child to link devices', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        
        // Agar partner link nahi hai toh option dikhao
        if (_coParentUid == null) ...[
          const SizedBox(height: 50),
          const Divider(),
          const SizedBox(height: 20),
          const Text('Link with a Spouse / Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _codeC,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'Enter Partner Code'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendPartnerRequest, 
              icon: const Icon(Icons.person_add_rounded), 
              label: const Text('Send Connection Request'),
            ),
          ),
        ],
      ],
    );
  }

  // Child ko code enter karne wali screen ka UI
  Widget _buildChildActionArea(ColorScheme colorScheme) {
    return Column(
      children: [
        const Center(child: Icon(Icons.link_rounded, size: 80, color: Colors.indigo)),
        const SizedBox(height: 20),
        const Text('Connect to Parent', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('Enter the 6-digit code shown on your parent\'s device', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        TextField(
          controller: _codeC,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
          decoration: const InputDecoration(hintText: '000000'),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _connect,
            child: const Text('Establish Connection', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(),
      ],
    );
  }
}

