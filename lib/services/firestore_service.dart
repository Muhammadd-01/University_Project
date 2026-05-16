// firestore_service.dart - Sab database operations yahan hain
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// Ye class Firebase Database ke sath sari baat cheet krti hai (Data dalna, nikalna)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Account banne ke baad naye user ka data database me daalna
  Future<void> createUser(String uid, String email, String role, String name) async {
    final Map<String, dynamic> data = {'email': email, 'role': role, 'name': name, 'connectedTo': null};
    // Agar parent hai, toh usko ek khas code do taake bache connect ho sakain
    if (role == 'parent') {
      data['connectionCode'] = _generateCode();
      data['children'] = []; // Multiple children ke liye array
      data['coParent'] = null; // Ami ya Abu ke sath link karne ke liye
    }
    await _db.collection('users').doc(uid).set(data);
  }

  // Sab bacho ki live location ek sath dekhne ke liye (Stream)
  Stream<QuerySnapshot> getMultiLocationStream(List<dynamic> uids) {
    // Filter out nulls and ensure list is not empty
    final safeUids = uids.where((id) => id != null).toList();
    if (safeUids.isEmpty) return const Stream.empty();
    
    return _db.collection('locations')
        .where(FieldPath.documentId, whereIn: safeUids).snapshots();
  }

  // 6 digit ka random connection code banana (100000 se 999999 ke darmian)
  String _generateCode() => (100000 + Random().nextInt(900000)).toString();

  // Kisi makhsoos user ka data nikalna
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Bohot sare bacho ki details ek sath nikalna UID de kar
  Future<List<Map<String, dynamic>>> getChildrenProfiles(List<dynamic> uids) async {
    if (uids.isEmpty) return [];
    
    // Khali (null) ID wale nikal do
    final safeUids = uids.where((id) => id != null && id.toString().isNotEmpty).toList();
    if (safeUids.isEmpty) return [];

    final snapshots = await _db.collection('users')
        .where(FieldPath.documentId, whereIn: safeUids).get();
        
    return snapshots.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      // ID ko data ka hissa bana do
      data['uid'] = d.id;
      return data;
    }).toList();
  }

  // Bachay ki app mein 6-digit code daal kar parent ke sath jorna
  Future<bool> connectChild(String code, String childUid) async {
    // Code dhoondo database me
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) return false; // Agar code nahi mila toh ghalat
    final parentUid = query.docs.first.id;
    final parentData = query.docs.first.data();

    // 1. Asal parent ke profile me bachay ki ID shamil karo
    await _db.collection('users').doc(parentUid).update({'children': FieldValue.arrayUnion([childUid])});
    
    // 2. Agar ami aur abu dono hain (Co-Parent), toh dosre ke paas bhi bacha add karo
    final coParentUid = parentData['coParent'];
    if (coParentUid != null) {
      await _db.collection('users').doc(coParentUid).update({'children': FieldValue.arrayUnion([childUid])});
    }

    // 3. Bachay ke profile mein likh do ke wo is parent ke sath juda hua hai
    await _db.collection('users').doc(childUid).update({'connectedTo': parentUid});
    return true; // Connection kamyab
  }

  // Bachay ki naye location database par update karna
  Future<void> updateLocation(String uid, double lat, double lng) async {
    await _db.collection('locations').doc(uid).set({
      'latitude': lat, 'longitude': lng, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Bachay ki akhri jani pehchani location dekhna
  Future<Map<String, dynamic>?> getChildLocation(String childUid) async {
    final doc = await _db.collection('locations').doc(childUid).get();
    return doc.data();
  }

  // Emergency (Danger) ka message database mein daalna
  Future<void> sendAlert(String type, String senderId, String parentId, String message) async {
    final alertData = {
      'type': type, 'senderId': senderId, 'parentId': parentId,
      'message': message, 'timestamp': FieldValue.serverTimestamp(),
      'status': 'active', // Mark alert as active initially
    };
    
    // Alert bhej do
    await _db.collection('alerts').add(alertData);
    
    // Agar ami aur abu dono link hain, toh dosre (Co-parent) ko bhi alert bhejo
    final parent = await getUser(parentId);
    if (parent != null && parent['coParent'] != null) {
      final mirroredData = Map<String, dynamic>.from(alertData);
      mirroredData['parentId'] = parent['coParent'];
      await _db.collection('alerts').add(mirroredData);
    }
  }

  // Parent ki app ke liye live (real-time) alerts mangwana
  Stream<QuerySnapshot> getAlerts(String userId) {
    return _db.collection('alerts')
        .where('parentId', isEqualTo: userId)
        .where('status', isEqualTo: 'active') // Only get active alerts
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Alert ko hal (resolve) karna jab parent respond kare
  Future<void> resolveAlert(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({'status': 'resolved'});
  }

  // Bachay ki app ke liye live alerts
  Stream<QuerySnapshot> getChildAlerts(String childId) {
    return _db.collection('alerts')
        .where('senderId', isEqualTo: childId)
        .snapshots();
  }

  // Naya Safe Zone (mehfooz ilaqa) database me dalna
  Future<void> addSafeZone(String uid, String name, double lat, double lng, double radius) async {
    final zone = {
      'name': name, 'lat': lat, 'lng': lng, 'radius': radius,
    };
    await _db.collection('users').doc(uid).update({
      'safeZones': FieldValue.arrayUnion([zone])
    });

    // Co-parent ke paas bhi zone bej do
    final user = await getUser(uid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'safeZones': FieldValue.arrayUnion([zone])
      });
    }
  }

  // Safe Zone khatam karna (Delete)
  Future<void> removeSafeZone(String uid, Map<String, dynamic> zone) async {
    await _db.collection('users').doc(uid).update({
      'safeZones': FieldValue.arrayRemove([zone])
    });

    // Co-parent se bhi delete karo
    final user = await getUser(uid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'safeZones': FieldValue.arrayRemove([zone])
      });
    }
  }

  // Banaye gaye tamam Safe Zones mangwana
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
    // Agar purani app wala system chal raha hai toh fallback (bachao)
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

  // Emergency (Aafat mein phone karne wale) Contacts add karna
  Future<void> addEmergencyContact(String parentUid, String name, String phone, String countryCode) async {
    final contact = {'name': name, 'phone': phone, 'countryCode': countryCode};
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayUnion([contact])
    });

    // Co-parent ko bhi de do
    final user = await getUser(parentUid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'emergencyContacts': FieldValue.arrayUnion([contact])
      });
    }
  }

  // Emergency contact hatao (delete)
  Future<void> removeEmergencyContact(String parentUid, Map<String, dynamic> contact) async {
    await _db.collection('users').doc(parentUid).update({
      'emergencyContacts': FieldValue.arrayRemove([contact])
    });

    // Co-parent se bhi hatao
    final user = await getUser(parentUid);
    if (user != null && user['coParent'] != null) {
      await _db.collection('users').doc(user['coParent']).update({
        'emergencyContacts': FieldValue.arrayRemove([contact])
      });
    }
  }

  // Tamam emergency contacts mangwana
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    if (data != null && data['emergencyContacts'] != null) {
      return List<Map<String, dynamic>>.from(data['emergencyContacts']);
    }
    return [];
  }

  // Purana contact theek (update) karna
  Future<void> updateEmergencyContact(String parentUid, Map<String, dynamic> oldContact, Map<String, dynamic> newContact) async {
    final user = await getUser(parentUid);
    final coParentUid = user?['coParent'];
    
    // Pehle walidein (Primary) me theek karo
    await _updateSingleParentContact(parentUid, oldContact, newContact);
    
    // Dusre (Co-parent) me theek karo
    if (coParentUid != null) {
      await _updateSingleParentContact(coParentUid, oldContact, newContact);
    }
  }

  Future<void> _updateSingleParentContact(String uid, Map<String, dynamic> oldContact, Map<String, dynamic> newContact) async {
    final docRef = _db.collection('users').doc(uid);
    // Database mein Transaction chalana (takay koi aur cheez update hote waqt na chere)
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      final contacts = List<Map<String, dynamic>>.from(doc.get('emergencyContacts') ?? []);
      final index = contacts.indexWhere((c) => c['phone'] == oldContact['phone']); // Purana number dhundna
      if (index != -1) {
        contacts[index] = newContact; // Naye number se badal do
        transaction.update(docRef, {'emergencyContacts': contacts});
      }
    });
  }


  // Partner (Shohar/Biwi) ko link karne ka system (Request bhejna)
  Future<bool> sendPartnerRequest(String code, String myUid, String myName) async {
    final query = await _db.collection('users')
        .where('connectionCode', isEqualTo: code)
        .where('role', isEqualTo: 'parent').limit(1).get(); // Sirf parent ko code jayega
    
    if (query.docs.isEmpty) return false;
    final targetUid = query.docs.first.id;
    if (targetUid == myUid) return false; // Apne aap ko request nahi bhej sakte

    // Dusre ki profile mein "requests" folder me apni darkhwast (request) rakh do
    await _db.collection('users').doc(targetUid).collection('requests').doc(myUid).set({
      'fromUid': myUid,
      'fromName': myName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'partner'
    });
    return true;
  }

  // Apne pas ayi hui darkhastain (Requests) live dekhna
  Stream<QuerySnapshot> getPartnerRequests(String myUid) {
    return _db.collection('users').doc(myUid).collection('requests').snapshots();
  }

  // Request manzoor karna (Accept)
  Future<void> acceptPartnerRequest(String myUid, String partnerUid) async {
    final myDoc = await _db.collection('users').doc(myUid).get();
    final partnerDoc = await _db.collection('users').doc(partnerUid).get();
    
    final myData = myDoc.data()!;
    final partnerData = partnerDoc.data()!;

    // 1. Ek dusre ke sath jorna
    // Jisne request bheji thi, usko mera saara data (bachay, zone, contacts) de do
    await _db.collection('users').doc(partnerUid).update({
      'coParent': myUid,
      'connectionCode': myData['connectionCode'], // Code bhi aapas me share ho gaya
      'children': myData['children'] ?? [],
      'emergencyContacts': myData['emergencyContacts'] ?? [],
      'safeZones': myData['safeZones'] ?? [],
    });
    
    // Mere paas bhi likh lo ke wo mera partner hai
    await _db.collection('users').doc(myUid).update({'coParent': partnerUid});
    
    // 2. Request wali notification ab mita do
    await _db.collection('users').doc(myUid).collection('requests').doc(partnerUid).delete();
  }

  // Request radd (Reject) karna
  Future<void> rejectPartnerRequest(String myUid, String partnerUid) async {
    await _db.collection('users').doc(myUid).collection('requests').doc(partnerUid).delete();
  }
}
