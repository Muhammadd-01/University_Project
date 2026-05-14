// auth_service.dart - Firebase Auth ka kaam (login, register, logout)
import 'package:firebase_auth/firebase_auth.dart';

// Ye class app mein login, naya account banane aur logout ke tamam kamo ko sambhalti hai
class AuthService {
  // Firebase ki tijori (auth instance) ka darwaza
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Pata lagana ke abhi app mein kon sa user (shakhs) login hai
  User? get currentUser => _auth.currentUser;

  // Purane account se login karna (Email aur password ke zariye)
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Naya account banana (Sign up)
  Future<UserCredential> register(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Agar user password bhool jaye toh uski email par reset link bhejna
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // App se bahir aana (Logout karna)
  Future<void> logout() async => await _auth.signOut();
}
