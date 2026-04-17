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
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_off, size: 60, color: Colors.grey),
              SizedBox(height: 12), Text('No alerts yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final a = snap.data!.docs[i].data() as Map<String, dynamic>;
              final isPanic = a['type'] == 'panic';
              final ts = a['timestamp'] as Timestamp?;
              final time = ts != null ? '${ts.toDate().day}/${ts.toDate().month} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}' : 'Just now';
              return Card(
                color: isPanic ? Colors.red[50] : Colors.orange[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPanic ? Colors.red[100] : Colors.orange[100],
                    child: Icon(isPanic ? Icons.warning_rounded : Icons.circle_outlined, color: isPanic ? Colors.red : Colors.orange),
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
