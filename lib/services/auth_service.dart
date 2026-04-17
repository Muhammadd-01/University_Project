// ============================================
// auth_service.dart - Authentication ka kaam (Login, Register, Logout)
// ============================================
// Yeh file Firebase Authentication se related sab kaam karti hai
// Ismein 3 main functions hain:
// 1. login() - email aur password se user ko login karao
// 2. register() - naya user account banao
// 3. logout() - user ko logout karao
// FirebaseAuth ka instance use hota hai jo Firebase se baat karta hai

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // FirebaseAuth ka instance - isse hum Firebase ke auth system se baat karte hain
  // _auth private hai (underscore _ se shuru hota hai) taake bahar se access na ho
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // currentUser - abhi jo user logged in hai uski info deta hai
  // Agar koi logged in nahi hai toh null return karega
  // Getter use kiya hai (get keyword) taake directly access ho sake: authService.currentUser
  User? get currentUser => _auth.currentUser;

  // login() - Email aur password se user ko login karao
  // async hai kyunke Firebase se baat karna time leta hai (network call)
  // UserCredential return karta hai jismein user ki info hoti hai (uid, email etc)
  Future<UserCredential> login(String email, String password) async {
    // signInWithEmailAndPassword - Firebase ka built-in function hai
    // Yeh check karta hai email aur password sahi hain ya nahi
    // Agar galat hain toh exception throw karega
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // register() - Naya user account banao Firebase mein
  // Yeh Firebase Authentication mein naya record create karta hai
  // Har user ko ek unique uid milti hai (jaise: "abc123xyz")
  Future<UserCredential> register(String email, String password) async {
    // createUserWithEmailAndPassword - Firebase mein naya user banata hai
    // Agar email pehle se registered hai toh error aayega
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // logout() - User ko app se logout karao
  // signOut() ke baad currentUser null ho jayega
  Future<void> logout() async {
    await _auth.signOut();
  }
}
