// firestore_service.dart - Sab database operations yahan hain
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User create karo register ke baad
  Future<void> createUser(String uid, String email, String role, String name) async {
    final Map<String, dynamic> data = {'email': email, 'role': role, 'name': name, 'connectedTo': null};
    if (role == 'parent') {
      data['connectionCode'] = _generateCode();
      data['children'] = []; // Multiple children ke liye array
      data['coParent'] = null; // Link for Mom/Dad
    }
    await _db.collection('users').doc(uid).set(data);
  }

  // Multi-child locations stream (Real-time tracking for all kids)
  Stream<QuerySnapshot> getMultiLocationStream(List<dynamic> uids) {
    // Filter out nulls and ensure list is not empty
    final safeUids = uids.where((id) => id != null).toList();
    if (safeUids.isEmpty) return const Stream.empty();
    
    return _db.collection('locations')
        .where(FieldPath.documentId, whereIn: safeUids).snapshots();
  }

  // 6 digit random code
  String _generateCode() => (100000 + Random().nextInt(900000)).toString();

  // User data fetch karo
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Fetch multiple user profiles by UID
  Future<List<Map<String, dynamic>>> getChildrenProfiles(List<dynamic> uids) async {
    if (uids.isEmpty) return [];
    
    // Filter out nulls/falsy values
    final safeUids = uids.where((id) => id != null && id.toString().isNotEmpty).toList();
    if (safeUids.isEmpty) return [];

    final snapshots = await _db.collection('users')
        .where(FieldPath.documentId, whereIn: safeUids).get();
        
    return snapshots.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      // Ensure 'uid' is present by using the document ID if missing
      data['uid'] = d.id;
      return data;
    }).toList();
  }

  // Child ko parent se connect karo code se
  Future<bool> connectChild(String code, String childUid) async {
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) return false;
    final parentUid = query.docs.first.id;
    // Parent mein childUID add karo (arrayUnion duplicate se bachata hai)
    await _db.collection('users').doc(parentUid).update({'children': FieldValue.arrayUnion([childUid])});
    // Child mein parentUID set karo
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
      return {
        'lat': (data['boundaryLat'] as num).toDouble(),
        'lng': (data['boundaryLng'] as num).toDouble(),
        'radius': (data['boundaryRadius'] as num).toDouble()
      };
    }
    return null;
  }

  // Emergency Contacts management
  Future<void> addEmergencyContact(String parentUid, String name, String phone, String countryCode) async {
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayUnion([
        {'name': name, 'phone': phone, 'countryCode': countryCode}
      ])
    });
  }

  Future<void> removeEmergencyContact(String parentUid, Map<String, dynamic> contact) async {
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayRemove([contact])
    });
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    if (data != null && data['emergencyContacts'] != null) {
      return List<Map<String, dynamic>>.from(data['emergencyContacts']);
    }
    return [];
  }

  Future<void> updateEmergencyContact(String parentUid, Map<String, dynamic> oldContact, Map<String, dynamic> newContact) async {
    final docRef = _db.collection('users').doc(parentUid);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      
      final contacts = List<Map<String, dynamic>>.from(doc.get('emergencyContacts') ?? []);
      final index = contacts.indexWhere((c) => c['phone'] == oldContact['phone']);
      
      if (index != -1) {
        contacts[index] = newContact;
        transaction.update(docRef, {'emergencyContacts': contacts});
      }
    });
  }

  // Child's own WhatsApp linking
  Future<void> linkWhatsApp(String uid, String phone) async {
    await _db.collection('users').doc(uid).update({
      'linkedWhatsApp': phone,
    });
  }

  // Parent linking (Mom & Dad)
  Future<bool> linkCoParent(String code, String myUid) async {
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code)
        .where('role', isEqualTo: 'parent').limit(1).get();
    
    if (query.docs.isEmpty) return false;
    final coParentUid = query.docs.first.id;
    if (coParentUid == myUid) return false;

    // Link both ways
    await _db.collection('users').doc(myUid).update({'coParent': coParentUid});
    await _db.collection('users').doc(coParentUid).update({'coParent': myUid});
    return true;
  }
}
