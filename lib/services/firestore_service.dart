import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// Firestore service - sab database operations yahan hain
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User document banao (register ke baad)
  Future<void> createUser(String uid, String email, String role) async {
    Map<String, dynamic> data = {
      'email': email,
      'role': role,
      'connectedTo': null,
    };
    // Agar parent hai toh unique code generate karo
    if (role == 'parent') {
      data['connectionCode'] = _generateCode();
    }
    await _db.collection('users').doc(uid).set(data);
  }

  // 6 digit random code generate karo
  String _generateCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  // User data fetch karo
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Child ko parent se connect karo (code se)
  Future<bool> connectChild(String code, String childUid) async {
    // Pehle parent dhundho jiska yeh code hai
    final query = await _db
        .collection('users')
        .where('connectionCode', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return false;
    // Parent mila, ab dono ko connect karo
    final parentDoc = query.docs.first;
    final parentUid = parentDoc.id;
    await _db.collection('users').doc(parentUid).update({'connectedTo': childUid});
    await _db.collection('users').doc(childUid).update({'connectedTo': parentUid});
    return true;
  }

  // Child ki location update karo
  Future<void> updateLocation(String uid, double lat, double lng) async {
    await _db.collection('locations').doc(uid).set({
      'latitude': lat,
      'longitude': lng,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Child ki location fetch karo (parent ke liye)
  Future<Map<String, dynamic>?> getChildLocation(String childUid) async {
    final doc = await _db.collection('locations').doc(childUid).get();
    return doc.data();
  }

  // Alert bhejo (panic ya boundary)
  Future<void> sendAlert(String type, String senderId, String parentId, String message) async {
    await _db.collection('alerts').add({
      'type': type,
      'senderId': senderId,
      'parentId': parentId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Alerts fetch karo (user ke liye)
  Stream<QuerySnapshot> getAlerts(String userId) {
    return _db
        .collection('alerts')
        .where('parentId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Child ke alerts bhi dikhao
  Stream<QuerySnapshot> getChildAlerts(String childId) {
    return _db
        .collection('alerts')
        .where('senderId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Boundary set karo (parent)
  Future<void> setBoundary(String uid, double lat, double lng, double radius) async {
    await _db.collection('users').doc(uid).update({
      'boundaryLat': lat,
      'boundaryLng': lng,
      'boundaryRadius': radius,
    });
  }

  // Boundary fetch karo
  Future<Map<String, dynamic>?> getBoundary(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    if (data != null && data['boundaryRadius'] != null) {
      return {
        'lat': data['boundaryLat'],
        'lng': data['boundaryLng'],
        'radius': data['boundaryRadius'],
      };
    }
    return null;
  }
}
