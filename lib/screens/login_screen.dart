// login_screen.dart - Email password se login
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
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscurePassword = true; // State for password visibility

  void _login() async {
    if (_emailC.text.isEmpty || _passC.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    
    setState(() => _loading = true);
    try {
      final cred = await _auth.login(_emailC.text.trim(), _passC.text.trim());
      final data = await FirestoreService().getUser(cred.user!.uid);
      if (data != null && mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(role: data['role'], uid: cred.user!.uid)));
      }
    } catch (e) {
      if (mounted) _showError(_getFriendlyError(e.toString()));
    }
    if (mounted) setState(() => _loading = true); // Keep loading true while navigating
    if (mounted) setState(() => _loading = false);
  }

  // Friendly error messages instead of technical codes
  String _getFriendlyError(String error) {
    if (error.contains('user-not-found') || error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'Invalid email or password. Please try again.';
    } else if (error.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Header icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield, size: 50, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Welcome Back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sign in to continue', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 40),
              // Email field
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              // Password field with Toggle
              TextField(
                controller: _passC, 
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password', 
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    if (_emailC.text.isEmpty) {
                      _showError('Enter your email to reset password');
                      return;
                    }
                    try {
                      await _auth.sendPasswordResetEmail(_emailC.text.trim());
                      _showSuccess('Password reset email sent!');
                    } catch (e) {
                      _showError('Error: Could not send reset email');
                    }
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),
              // Login button
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(onPressed: _login, child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 24),
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Register', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
