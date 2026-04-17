// ============================================
// alerts_screen.dart - Alerts Screen (Sab Alerts Dekho)
// ============================================
// Is screen pe sab alerts dikhte hain - panic aur boundary dono
// Alerts real-time mein update hote hain (StreamBuilder use kiya hai)
// Matlab jab naya alert aaye toh screen automatically refresh ho jati hai
//
// Parent ko woh alerts dikhte hain jo usko bheje gaye (parentId match)
// Child ko woh alerts dikhte hain jo usne bheje (senderId match)
//
// Har alert mein dikhta hai:
// - Icon aur color (red for panic, orange for boundary)
// - Alert ka type (Panic Alert ya Boundary Alert)
// - Message
// - Time stamp (kab hua)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

// StatelessWidget hai kyunke StreamBuilder khud state manage karta hai
class AlertsScreen extends StatelessWidget {
  final String uid;  // User ki uid
  final String role; // "parent" ya "child"
  const AlertsScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    // Role ke hisab se alag query use karo:
    // Parent ko woh alerts dikhao jo usko bheje gaye (parentId == uid)
    // Child ko woh alerts dikhao jo usne bheje (senderId == uid)
    final alertStream = role == 'parent'
        ? firestoreService.getAlerts(uid)
        : firestoreService.getChildAlerts(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<QuerySnapshot>(
        // StreamBuilder - Firestore se real-time data sunta hai
        // Jab bhi naya alert aaye, builder phir se run hota hai
        stream: alertStream,
        builder: (context, snapshot) {
          // Step 1: Loading state - data abhi aa raha hai
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Step 2: Koi alert nahi mila
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Koi alert nahi hai'));
          }

          // Step 3: Alerts mil gaye, list banao
          final alerts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: alerts.length, // Kitne alerts hain
            itemBuilder: (context, index) {
              // Har alert ka data Map mein convert karo
              final alert = alerts[index].data() as Map<String, dynamic>;

              // Check karo panic hai ya boundary
              final isPanic = alert['type'] == 'panic';

              // Timestamp format karo (readable time banao)
              final timestamp = alert['timestamp'] as Timestamp?;
              final time = timestamp != null
                  ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                  : 'Just now'; // Agar timestamp null hai (abhi abhi bheja)

              // Har alert ke liye Card banao
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                // Panic = red background, Boundary = orange background
                color: isPanic ? Colors.red[50] : Colors.orange[50],
                child: ListTile(
                  // Icon - panic ke liye ⚠️, boundary ke liye ⭕
                  leading: Icon(
                    isPanic ? Icons.warning : Icons.circle_outlined,
                    color: isPanic ? Colors.red : Colors.orange,
                  ),
                  // Alert ka title
                  title: Text(
                    isPanic ? '🚨 Panic Alert' : '⚠️ Boundary Alert',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Alert ka message
                  subtitle: Text(alert['message'] ?? ''),
                  // Time stamp right side mein
                  trailing: Text(time, style: const TextStyle(fontSize: 12)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
