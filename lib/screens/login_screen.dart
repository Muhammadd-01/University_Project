// login_screen.dart - Email password se login
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';
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
  bool _obscurePassword = true;

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
      if (mounted) {
        setState(() => _loading = false);
        _showError(_getFriendlyError(e.toString()));
      }
    }
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingWidget(message: 'Verifying your credentials...'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Header animation
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ).animate()
                 .scale(duration: 600.ms, curve: Curves.easeOutBack)
                 .rotate(begin: -0.2, end: 0, duration: 600.ms),
              ),
              const SizedBox(height: 40),
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
              const SizedBox(height: 8),
              Text(
                'Sign in to your ChildGuard account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
              const SizedBox(height: 50),
              
              // Email Field
              Text(
                'Email Address',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 10),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 24),
              
              // Password Field
              Text(
                'Password',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 10),
              TextField(
                controller: _passC, 
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 12),
              
              // Forgot Password
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
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ),
              
              const SizedBox(height: 40),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.9, 0.9)),
              
              const SizedBox(height: 30),
              
              // Register Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

