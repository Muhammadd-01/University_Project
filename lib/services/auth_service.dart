import 'package:firebase_auth/firebase_auth.dart';

// Authentication service - login, register, logout
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current logged in user
  User? get currentUser => _auth.currentUser;

  // Login with email and password
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Register new user with email and password
  Future<UserCredential> register(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
