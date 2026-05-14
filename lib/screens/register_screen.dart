// register_screen.dart - Naya account banao
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';
import 'home_screen.dart';

// Yeh screen naya account banane ke liye hai
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameC = TextEditingController(); // Naam likhne ka dabba
  final _emailC = TextEditingController(); // Email likhne ka dabba
  final _passC = TextEditingController(); // Password likhne ka dabba
  final _confirmPassC = TextEditingController(); // Dobara password likhne ka dabba (confirm karne ke liye)
  final _auth = AuthService();
  String _role = 'parent'; // Shuru mein by default 'parent' set hoga
  bool _loading = false;
  bool _obscurePassword = true; // Password chupana
  bool _obscureConfirm = true;

  // Account banane wala function
  void _register() async {
    // Agar koi box khali hai toh rok do
    if (_nameC.text.isEmpty || _emailC.text.isEmpty || _passC.text.isEmpty || _confirmPassC.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    // Check karo ke dono passwords aapas mein milte hain ya nahi
    if (_passC.text != _confirmPassC.text) {
      _showError('Passwords do not match');
      return;
    }
    // Password kam az kam 6 lafzon ka hona chahiye
    if (_passC.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true); // Spinner chalao
    try {
      // 1. Firebase Authentication mein user banao
      final cred = await _auth.register(_emailC.text.trim(), _passC.text.trim());
      // 2. Firebase Database mein user ki mazeed maloomat (role, name) save karo
      await FirestoreService().createUser(cred.user!.uid, _emailC.text.trim(), _role, _nameC.text.trim());
      
      // Sab ho gaya toh Home Screen par le jao
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(role: _role, uid: cred.user!.uid)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(_getFriendlyError(e.toString())); // Error message dikhao
      }
    }
  }

  // Ajeeb ghareeb Firebase errors ko asan zaban mein dikhana
  String _getFriendlyError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered. Try logging in.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet.';
    }
    return 'Registration failed. Please try again.';
  }

  // Lal rang ka error message
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingWidget(message: 'Creating your account...'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context), // Peechay jane ka button
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Khush Amdeed wali text
            Text(
              'Join ChildGuard',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 8),
            Text(
              'Fill in your details to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 40),
            
            // Name Field (Naam)
            _buildFieldLabel('Full Name').animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 10),
            TextField(
              controller: _nameC,
              textCapitalization: TextCapitalization.words, // Har lafz ka pehla harf bada hoga
              decoration: const InputDecoration(
                hintText: 'John Doe',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 20),
            
            // Email Field (Email)
            _buildFieldLabel('Email Address').animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 10),
            TextField(
              controller: _emailC, 
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 20),
            
            // Password Field (Password)
            _buildFieldLabel('Password').animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 10),
            TextField(
              controller: _passC, 
              obscureText: _obscurePassword, // Password chupana
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), // Aankh wala icon
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 20),
            
            // Confirm Password (Dobara password)
            _buildFieldLabel('Confirm Password').animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPassC, 
              obscureText: _obscureConfirm, 
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 30),
            
            // Role selection (Bacha ya Parent?)
            _buildFieldLabel('Select your role').animate().fadeIn(delay: 700.ms),
            const SizedBox(height: 16),
            Row(
              children: [
                // Parent wala daba
                Expanded(child: _roleChip('parent', Icons.person_rounded, 'Parent')),
                const SizedBox(width: 16),
                // Child wala daba
                Expanded(child: _roleChip('child', Icons.child_care_rounded, 'Child')),
              ],
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: 40),
            
            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _register,
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Heading bananay ka asan tareeka
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
    );
  }

  // Role select karne wale box ka design
  Widget _roleChip(String value, IconData icon, String label) {
    final selected = _role == value; // Agar select hua wa hai toh true
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey[400]!;
    
    return GestureDetector(
      onTap: () => setState(() => _role = value), // Click par role change karo
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey[200]!,
            width: selected ? 2 : 1, // Select hone par border mota ho jayega
          ),
          // Select hone par halka sa saya (shadow) ayega
          boxShadow: selected ? [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

