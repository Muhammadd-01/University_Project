// alerts_screen.dart - Real-time safety logs
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';

// Yeh screen user (Parent ya Child) ko unki notifications ya alerts dikhati hai
class AlertsScreen extends StatelessWidget {
  final String uid, role;
  const AlertsScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    // Agar parent hai toh uske connected child ke alerts aayenge, warna child ke apne alerts
    final stream = role == 'parent' ? fs.getAlerts(uid) : fs.getChildAlerts(uid);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // Appbar ki shadow khatam kar di
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          // Back button dabane par pichli screen par le jayega
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Activity Logs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      // Firestore se real-time alerts fetch karne ke liye StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          // Jab tak data load ho raha hai, LoadingWidget dikhao
          if (snap.connectionState == ConnectionState.waiting) return const LoadingWidget(message: 'Syncing logs...');
          
          // Agar database se data laane mein koi error aati hai
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.redAccent),
                    const SizedBox(height: 20),
                    const Text('Connection Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          // Agar koi alerts mojud nahi hain toh empty state show karo
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text('No alerts detected', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('Your safety events will be logged here', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ).animate().fadeIn();
          }

          final docs = snap.data!.docs;
          // Alerts ko naye se purane time (descending order) ke hisaab se sort karna
          docs.sort((a, b) {
            final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA);
          });

          // Alerts ki list dikhane ke liye ListView
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final a = docs[i].data() as Map<String, dynamic>;
              final isPanic = a['type'] == 'panic'; // Check karna ke yeh panic alert hai ya boundary alert
              final ts = a['timestamp'] as Timestamp?;
              final time = ts != null ? _formatTime(ts.toDate()) : 'Recent';
              
              // Alert card build karo aur animations apply karo
              return _buildAlertCard(a, isPanic, time)
                  .animate(delay: (i * 50).ms)
                  .fadeIn()
                  .slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }

  // Time ko parhne layak banata hai (e.g., 'Just now', '15m ago')
  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}/${date.month}'; // Agar 1 din se zyada ho gaya toh date/month dikhao
  }

  // Yeh ek individual alert card ka UI banata hai
  Widget _buildAlertCard(Map<String, dynamic> a, bool isPanic, String time) {
    final color = isPanic ? Colors.redAccent : Colors.orangeAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)], // Halki shadow effect
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(isPanic ? Icons.warning_amber_rounded : Icons.radar_rounded, color: color, size: 24),
        ),
        title: Text(
          isPanic ? 'Emergency Signal' : 'Boundary Alert', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          a['message'] ?? 'Suspicious activity detected', 
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time, 
              style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
            ),
            if (a['status'] == 'resolved')
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'RESPONDED',
                  style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
