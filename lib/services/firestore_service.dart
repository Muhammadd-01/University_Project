// firestore_service.dart - Sab database operations yahan hain
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User create karo register ke baad
  Future<void> createUser(String uid, String email, String role) async {
    final data = {'email': email, 'role': role, 'connectedTo': null};
    if (role == 'parent') data['connectionCode'] = _generateCode();
    await _db.collection('users').doc(uid).set(data);
  }

  // 6 digit random code
  String _generateCode() => (100000 + Random().nextInt(900000)).toString();

  // User data fetch karo
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Child ko parent se connect karo code se
  Future<bool> connectChild(String code, String childUid) async {
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) return false;
    final parentUid = query.docs.first.id;
    await _db.collection('users').doc(parentUid).update({'connectedTo': childUid});
    await _db.collection('users').doc(childUid).update({'connectedTo': parentUid});
    return true;
  }

  // Child ki location update karo
  Future<void> updateLocation(String uid, double lat, double lng) async {
    await _db.collection('locations').doc(uid).set({
      'latitude': lat, 'longitude': lng, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Child ki location fetch karo
  Future<Map<String, dynamic>?> getChildLocation(String childUid) async {
    final doc = await _db.collection('locations').doc(childUid).get();
    return doc.data();
  }

  // Alert bhejo (panic ya boundary)
  Future<void> sendAlert(String type, String senderId, String parentId, String message) async {
    await _db.collection('alerts').add({
      'type': type, 'senderId': senderId, 'parentId': parentId,
      'message': message, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Parent ke alerts real-time stream
  Stream<QuerySnapshot> getAlerts(String userId) {
    return _db.collection('alerts').where('parentId', isEqualTo: userId)
        .orderBy('timestamp', descending: true).snapshots();
  }

  // Child ke alerts real-time stream
  Stream<QuerySnapshot> getChildAlerts(String childId) {
    return _db.collection('alerts').where('senderId', isEqualTo: childId)
        .orderBy('timestamp', descending: true).snapshots();
  }

  // Boundary set karo (parent)
  Future<void> setBoundary(String uid, double lat, double lng, double radius) async {
    await _db.collection('users').doc(uid).update({
      'boundaryLat': lat, 'boundaryLng': lng, 'boundaryRadius': radius,
    });
  }

  // Boundary fetch karo
  Future<Map<String, dynamic>?> getBoundary(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    if (data != null && data['boundaryRadius'] != null) {
      return {'lat': data['boundaryLat'], 'lng': data['boundaryLng'], 'radius': data['boundaryRadius']};
    }
    return null;
  }
}
