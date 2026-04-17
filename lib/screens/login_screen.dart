// ============================================
// login_screen.dart - Login Screen
// ============================================
// Is screen pe user apna email aur password daal ke login karta hai
// Login hone ke baad Firestore se user ka role (parent/child) fetch hota hai
// Phir HomeScreen pe navigate hota hai role ke saath
// Agar login fail ho (galat email/password) toh error message dikhta hai
// "Register karo" button se RegisterScreen pe ja sakte hain

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // TextEditingController - TextField mein jo text likha jaye wo control karta hai
  // .text se hum value le sakte hain
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Services ke instances
  final _authService = AuthService();
  bool _loading = false; // Loading state - jab login ho raha ho toh true

  // _login() - Login button dabane pe yeh function chalta hai
  void _login() async {
    // Loading state on karo (button ki jagah loading spinner dikhega)
    setState(() => _loading = true);

    try {
      // Firebase se login karo - email aur password bhejo
      // .trim() se extra spaces hat jaate hain (user galti se space daal de)
      final cred = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Login successful! Ab user ka role fetch karo Firestore se
      final data = await FirestoreService().getUser(cred.user!.uid);

      if (data != null && mounted) {
        // pushReplacement use karte hain taake back button se login pe na aa sake
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(role: data['role'], uid: cred.user!.uid),
          ),
        );
      }
    } catch (e) {
      // Login fail hua - error message dikhao (galat email/password etc)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }

    // Loading state off karo
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20), // Charon taraf 20 pixel padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center mein rakho
          children: [
            // App icon
            const Icon(Icons.shield, size: 60, color: Colors.blue),
            const SizedBox(height: 20),

            // Email input field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(), // Border wala style
              ),
            ),
            const SizedBox(height: 10),

            // Password input field
            TextField(
              controller: _passwordController,
              obscureText: true, // Password hide karo (dots dikhao)
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Login button ya Loading spinner
            _loading
                ? const CircularProgressIndicator() // Loading ho rahi hai
                : SizedBox(
                    width: double.infinity, // Button poori width le
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                    ),
                  ),

            // Register page pe jane ka button
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text('Register karo'),
            ),
          ],
        ),
      ),
    );
  }
}
