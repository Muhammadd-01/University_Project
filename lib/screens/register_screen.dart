// ============================================
// register_screen.dart - Register Screen (Naya Account Banao)
// ============================================
// Is screen pe naya user apna account banata hai
// User ko 3 cheezein deni hoti hain:
// 1. Email address
// 2. Password
// 3. Role select karo: Parent ya Child
//
// Register hone pe 2 kaam hote hain:
// 1. Firebase Auth mein naya user banta hai (email + password)
// 2. Firestore mein user ka data save hota hai (email, role, connectionCode)
// Agar role parent hai toh automatically 6-digit connection code generate hota hai

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Input controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Services
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // Default role parent hai - user dropdown se change kar sakta hai
  String _role = 'parent';
  bool _loading = false;

  // _register() - Register button dabane pe naya account banao
  void _register() async {
    setState(() => _loading = true);

    try {
      // Step 1: Firebase Auth mein naya user banao
      // Yeh user ko unique uid deta hai (jaise: "xYz123AbC")
      final cred = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Step 2: Firestore mein user ka data save karo
      // createUser() mein agar parent hai toh 6-digit code bhi generate hota hai
      await _firestoreService.createUser(
        cred.user!.uid,
        _emailController.text.trim(),
        _role,
      );

      // Step 3: Home Screen pe navigate karo
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(role: _role, uid: cred.user!.uid),
          ),
        );
      }
    } catch (e) {
      // Register fail hua - error dikhao
      // Common errors: email already exists, password too short, invalid email
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Register failed: $e')),
        );
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email input field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Password input field
            TextField(
              controller: _passwordController,
              obscureText: true, // Password dots mein dikhao
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Role selection dropdown - Parent ya Child
            // DropdownButtonFormField ek dropdown menu deta hai form style mein
            DropdownButtonFormField<String>(
              initialValue: _role, // Default value: parent
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              // Dropdown ke items - 2 options
              items: const [
                DropdownMenuItem(value: 'parent', child: Text('Parent')),
                DropdownMenuItem(value: 'child', child: Text('Child')),
              ],
              // Jab user role change kare toh _role update karo
              onChanged: (val) => setState(() => _role = val!),
            ),
            const SizedBox(height: 20),

            // Register button ya Loading spinner
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: const Text('Register'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
