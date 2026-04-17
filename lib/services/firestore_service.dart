// ============================================
// firestore_service.dart - Database ka sara kaam (CRUD operations)
// ============================================
// Yeh file Cloud Firestore (Firebase ka database) se related sab kaam karti hai
// Firestore ek NoSQL database hai jismein data collections aur documents mein store hota hai
// Jaise: users collection mein har user ka ek document hai
//
// Is file mein yeh functions hain:
// - createUser: naye user ka data save karo
// - getUser: user ka data fetch karo
// - connectChild: parent aur child ko code se connect karo
// - updateLocation: child ki GPS location save karo
// - getChildLocation: child ki last location fetch karo
// - sendAlert: panic ya boundary alert save karo
// - getAlerts: alerts ki list fetch karo (real-time)
// - setBoundary: parent boundary (safe zone) set kare
// - getBoundary: boundary ki details fetch karo

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // Random number generate karne ke liye

class FirestoreService {
  // Firestore ka instance - isse database se baat karte hain
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================
  // USER RELATED FUNCTIONS
  // ============================================

  // createUser() - Register ke baad user ka data Firestore mein save karo
  // uid: Firebase Auth se mila unique id
  // email: user ka email
  // role: "parent" ya "child"
  Future<void> createUser(String uid, String email, String role) async {
    // User ka data Map mein dalo
    Map<String, dynamic> data = {
      'email': email,          // User ka email address
      'role': role,            // Role: parent ya child
      'connectedTo': null,     // Abhi kisi se connected nahi hai
    };

    // Agar role parent hai toh unique 6-digit code generate karo
    // Yeh code child ko diya jayega taake woh connect ho sake
    if (role == 'parent') {
      data['connectionCode'] = _generateCode();
    }

    // Firestore mein "users" collection mein document save karo
    // doc(uid) matlab document ka naam user ki uid hogi
    // set() se data save hota hai
    await _db.collection('users').doc(uid).set(data);
  }

  // _generateCode() - 6 digit random code banao (100000 se 999999 ke beech)
  // Private function hai (underscore _) kyunke sirf is class mein use hota hai
  // Random().nextInt(900000) se 0-899999 milta hai, 100000 add karke 6 digit banta hai
  String _generateCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  // getUser() - User ka data Firestore se fetch karo
  // uid dena padta hai, Map return karta hai jismein user ki sab info hai
  // Agar user nahi mila toh null return karega
  Future<Map<String, dynamic>?> getUser(String uid) async {
    // .get() se document fetch hota hai
    final doc = await _db.collection('users').doc(uid).get();
    // .data() se Map milta hai (ya null agar document nahi hai)
    return doc.data();
  }

  // ============================================
  // CONNECTION RELATED FUNCTIONS
  // ============================================

  // connectChild() - Child ko parent se connect karo code ke zariye
  // code: parent ka 6-digit code jo child enter karta hai
  // childUid: child ki uid
  // true return karta hai agar connection successful ho, false agar code invalid ho
  Future<bool> connectChild(String code, String childUid) async {
    // Pehle Firestore mein dhundho kaunsa parent hai jiska yeh code hai
    // where() se filter lagate hain: connectionCode == entered code
    // limit(1) se sirf pehla result lete hain (performance ke liye)
    final query = await _db
        .collection('users')
        .where('connectionCode', isEqualTo: code)
        .limit(1)
        .get();

    // Agar koi parent nahi mila is code se toh false return karo
    if (query.docs.isEmpty) return false;

    // Parent mila! Uski uid nikalo
    final parentDoc = query.docs.first;
    final parentUid = parentDoc.id;

    // Ab dono ko connect karo:
    // Parent ke document mein child ki uid dalo
    await _db.collection('users').doc(parentUid).update({'connectedTo': childUid});
    // Child ke document mein parent ki uid dalo
    await _db.collection('users').doc(childUid).update({'connectedTo': parentUid});

    return true; // Connection successful!
  }

  // ============================================
  // LOCATION RELATED FUNCTIONS
  // ============================================

  // updateLocation() - Child ki current location Firebase mein save karo
  // Yeh function har 30 second mein call hota hai (home_screen.dart se)
  // uid: child ki uid
  // lat: latitude (GPS coordinate - north/south position)
  // lng: longitude (GPS coordinate - east/west position)
  Future<void> updateLocation(String uid, double lat, double lng) async {
    // "locations" collection mein child ki uid ke naam se document save karo
    // set() use kiya hai taake purana data replace ho jaye (sirf latest location chahiye)
    // FieldValue.serverTimestamp() se Firebase apna time lagata hai
    await _db.collection('locations').doc(uid).set({
      'latitude': lat,
      'longitude': lng,
      'timestamp': FieldValue.serverTimestamp(), // Server ka time
    });
  }

  // getChildLocation() - Child ki last saved location fetch karo
  // Parent Map screen se yeh call karta hai
  Future<Map<String, dynamic>?> getChildLocation(String childUid) async {
    final doc = await _db.collection('locations').doc(childUid).get();
    return doc.data(); // {latitude, longitude, timestamp} ya null
  }

  // ============================================
  // ALERT RELATED FUNCTIONS
  // ============================================

  // sendAlert() - Panic ya boundary alert Firebase mein save karo
  // type: "panic" (emergency button) ya "boundary" (safe zone se bahar)
  // senderId: kis user ne bheja (child ki uid)
  // parentId: kis parent ko bheja
  // message: alert ka message text
  Future<void> sendAlert(String type, String senderId, String parentId, String message) async {
    // "alerts" collection mein naya document add karo
    // add() se auto-generated unique ID milti hai (doc id Firebase khud banata hai)
    await _db.collection('alerts').add({
      'type': type,            // "panic" ya "boundary"
      'senderId': senderId,    // Child ki uid
      'parentId': parentId,    // Parent ki uid
      'message': message,      // Alert ka message
      'timestamp': FieldValue.serverTimestamp(), // Kab bheja
    });
  }

  // getAlerts() - Parent ke sab alerts real-time mein fetch karo
  // Stream return karta hai (matlab jab naya alert aaye toh automatically update ho)
  // snapshots() use kiya hai jo Firestore ka real-time listener hai
  Stream<QuerySnapshot> getAlerts(String userId) {
    return _db
        .collection('alerts')
        .where('parentId', isEqualTo: userId) // Sirf is parent ke alerts
        .orderBy('timestamp', descending: true) // Naye pehle dikhao
        .snapshots(); // Real-time stream
  }

  // getChildAlerts() - Child ke bheje hue sab alerts dikhao
  // Yeh child ko apne alerts dekhne ke liye hai
  Stream<QuerySnapshot> getChildAlerts(String childId) {
    return _db
        .collection('alerts')
        .where('senderId', isEqualTo: childId) // Sirf is child ke alerts
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ============================================
  // BOUNDARY (GEOFENCE) RELATED FUNCTIONS
  // ============================================

  // setBoundary() - Parent safe zone (boundary) set kare
  // lat, lng: boundary ka center point (usually child ki current location)
  // radius: kitne meters tak safe hai
  Future<void> setBoundary(String uid, double lat, double lng, double radius) async {
    // Parent ke user document mein boundary data update karo
    await _db.collection('users').doc(uid).update({
      'boundaryLat': lat,       // Center ka latitude
      'boundaryLng': lng,       // Center ka longitude
      'boundaryRadius': radius, // Radius meters mein
    });
  }

  // getBoundary() - Parent ki set ki hui boundary fetch karo
  // Agar boundary set nahi hai toh null return karega
  Future<Map<String, dynamic>?> getBoundary(String parentUid) async {
    final doc = await _db.collection('users').doc(parentUid).get();
    final data = doc.data();
    // Check karo boundary set hai ya nahi (boundaryRadius null nahi hona chahiye)
    if (data != null && data['boundaryRadius'] != null) {
      return {
        'lat': data['boundaryLat'],
        'lng': data['boundaryLng'],
        'radius': data['boundaryRadius'],
      };
    }
    return null; // Boundary set nahi hai
  }
}
