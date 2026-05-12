// alerts_screen.dart - Sab alerts dikhao (real-time)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class AlertsScreen extends StatelessWidget {
  final String uid, role;
  const AlertsScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final stream = role == 'parent' ? fs.getAlerts(uid) : fs.getChildAlerts(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts'), actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Error loading alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_off, size: 60, color: Colors.grey),
              SizedBox(height: 12), 
              Text('No alerts yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 8),
              Text('Your safety events will appear here', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]));
          }

          final docs = snap.data!.docs;
          // Sort client-side to avoid needing composite indexes
          docs.sort((a, b) {
            final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA); // Descending
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final a = docs[i].data() as Map<String, dynamic>;
              final isPanic = a['type'] == 'panic';
              final ts = a['timestamp'] as Timestamp?;
              final time = ts != null ? '${ts.toDate().day}/${ts.toDate().month} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}' : 'Just now';
              
              return Card(
                elevation: 1,
                color: isPanic ? Colors.red[50] : Colors.orange[50],
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPanic ? Colors.red[100] : Colors.orange[100],
                    child: Icon(isPanic ? Icons.warning_rounded : Icons.radar, color: isPanic ? Colors.red : Colors.orange),
                  ),
                  title: Text(isPanic ? 'Panic Alert' : 'Boundary Alert', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(a['message'] ?? ''),
                  trailing: Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
