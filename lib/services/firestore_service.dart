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
    final parentData = query.docs.first.data();

    // 1. Update Primary Parent
    await _db.collection('users').doc(parentUid).update({'children': FieldValue.arrayUnion([childUid])});
    
    // 2. If Co-Parent exists, update them too
    final coParentUid = parentData['coParent'];
    if (coParentUid != null) {
      await _db.collection('users').doc(coParentUid).update({'children': FieldValue.arrayUnion([childUid])});
    }

    // 3. Update Child
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
    final alertData = {
      'type': type, 'senderId': senderId, 'parentId': parentId,
      'message': message, 'timestamp': FieldValue.serverTimestamp(),
    };
    
    await _db.collection('alerts').add(alertData);
    
    // Mirror alert to co-parent if exists
    final parent = await getUser(parentId);
    if (parent != null && parent['coParent'] != null) {
      final mirroredData = Map<String, dynamic>.from(alertData);
      mirroredData['parentId'] = parent['coParent'];
      await _db.collection('alerts').add(mirroredData);
    }
  }

  // Parent ke alerts real-time stream
  Stream<QuerySnapshot> getAlerts(String userId) {
    // Note: To show alerts for both linked parents, we'd need an 'in' query.
    // For now, we'll keep it simple: any alert sent to this parentId.
    return _db.collection('alerts')
        .where('parentId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Child ke alerts real-time stream
  Stream<QuerySnapshot> getChildAlerts(String childId) {
    return _db.collection('alerts')
        .where('senderId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Boundary set karo (parent)
  // Multiple Safe Zones management
  Future<void> addSafeZone(String uid, String name, double lat, double lng, double radius) async {
    final zone = {
      'name': name, 'lat': lat, 'lng': lng, 'radius': radius,
    };
    await _db.collection('users').doc(uid).update({
      'safeZones': FieldValue.arrayUnion([zone])
    });

    // Mirror to co-parent
    final user = await getUser(uid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'safeZones': FieldValue.arrayUnion([zone])
      });
    }
  }

  Future<void> removeSafeZone(String uid, Map<String, dynamic> zone) async {
    await _db.collection('users').doc(uid).update({
      'safeZones': FieldValue.arrayRemove([zone])
    });

    // Mirror to co-parent
    final user = await getUser(uid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'safeZones': FieldValue.arrayRemove([zone])
      });
    }
  }

  Future<List<Map<String, dynamic>>> getSafeZones(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    if (data != null && data['safeZones'] != null) {
      return List<Map<String, dynamic>>.from(data['safeZones']).map((z) {
        return {
          'name': z['name'] ?? 'Safe Zone',
          'lat': (z['lat'] as num).toDouble(),
          'lng': (z['lng'] as num).toDouble(),
          'radius': (z['radius'] as num).toDouble()
        };
      }).toList();
    }
    // Migration fallback: check old fields
    if (data != null && data['boundaryRadius'] != null) {
      return [{
        'name': 'Home',
        'lat': (data['boundaryLat'] as num).toDouble(),
        'lng': (data['boundaryLng'] as num).toDouble(),
        'radius': (data['boundaryRadius'] as num).toDouble()
      }];
    }
    return [];
  }

  // Emergency Contacts management
  Future<void> addEmergencyContact(String parentUid, String name, String phone, String countryCode) async {
    final contact = {'name': name, 'phone': phone, 'countryCode': countryCode};
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayUnion([contact])
    });

    // Mirror to co-parent
    final user = await getUser(parentUid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'emergencyContacts': FieldValue.arrayUnion([contact])
      });
    }
  }

  Future<void> removeEmergencyContact(String parentUid, Map<String, dynamic> contact) async {
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayRemove([contact])
    });

    // Mirror to co-parent
    final user = await getUser(parentUid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'emergencyContacts': FieldValue.arrayRemove([contact])
      });
    }
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
    final user = await getUser(parentUid);
    final coParentUid = user?['coParent'];
    
    // Update primary
    await _updateSingleParentContact(parentUid, oldContact, newContact);
    
    // Update co-parent if exists
    if (coParentUid != null) {
      await _updateSingleParentContact(coParentUid, oldContact, newContact);
    }
  }

  Future<void> _updateSingleParentContact(String uid, Map<String, dynamic> oldContact, Map<String, dynamic> newContact) async {
    final docRef = _db.collection('users').doc(uid);
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


  // Partner Request System
  Future<bool> sendPartnerRequest(String code, String myUid, String myName) async {
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code)
        .where('role', isEqualTo: 'parent').limit(1).get();
    
    if (query.docs.isEmpty) return false;
    final targetUid = query.docs.first.id;
    if (targetUid == myUid) return false;

    await _db.collection('users').doc(targetUid).collection('requests').doc(myUid).set({
      'fromUid': myUid,
      'fromName': myName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'partner'
    });
    return true;
  }

  Stream<QuerySnapshot> getPartnerRequests(String myUid) {
    return _db.collection('users').doc(myUid).collection('requests').snapshots();
  }

  Future<void> acceptPartnerRequest(String myUid, String partnerUid) async {
    final myDoc = await _db.collection('users').doc(myUid).get();
    final partnerDoc = await _db.collection('users').doc(partnerUid).get();
    
    final myData = myDoc.data()!;
    final partnerData = partnerDoc.data()!;

    // 1. Link both ways
    // Partner (the one who requested) inherits My data (the one who accepted)
    await _db.collection('users').doc(partnerUid).update({
      'coParent': myUid,
      'connectionCode': myData['connectionCode'], // Shared code
      'children': myData['children'] ?? [],
      'emergencyContacts': myData['emergencyContacts'] ?? [],
      'safeZones': myData['safeZones'] ?? [],
    });
    
    await _db.collection('users').doc(myUid).update({'coParent': partnerUid});
    
    // 2. Delete the request
    await _db.collection('users').doc(myUid).collection('requests').doc(partnerUid).delete();
  }

  Future<void> rejectPartnerRequest(String myUid, String partnerUid) async {
    await _db.collection('users').doc(myUid).collection('requests').doc(partnerUid).delete();
  }
}
