// register_screen.dart - Naya account banao
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
  final _nameC = TextEditingController(); // Added name controller
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmPassC = TextEditingController(); // Added confirm password controller
  final _auth = AuthService();
  String _role = 'parent';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  void _register() async {
    // Validation checks
    if (_nameC.text.isEmpty || _emailC.text.isEmpty || _passC.text.isEmpty || _confirmPassC.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (_passC.text != _confirmPassC.text) {
      _showError('Passwords do not match');
      return;
    }
    if (_passC.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await _auth.register(_emailC.text.trim(), _passC.text.trim());
      // Pass both name and email to Firestore
      await FirestoreService().createUser(cred.user!.uid, _emailC.text.trim(), _role, _nameC.text.trim());
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(role: _role, uid: cred.user!.uid)));
      }
    } catch (e) {
      if (mounted) _showError(_getFriendlyError(e.toString()));
    }
    if (mounted) setState(() => _loading = false);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Icon(Icons.person_add, size: 60, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Join ChildGuard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _nameC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailC, 
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))
            ),
            const SizedBox(height: 16),
            // Password Field with Toggle
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
            const SizedBox(height: 16),
            // Confirm Password Field with Toggle
            TextField(
              controller: _confirmPassC, 
              obscureText: _obscureConfirm, 
              decoration: InputDecoration(
                labelText: 'Confirm Password', 
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Role selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select your role:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _roleChip('parent', Icons.person, 'Parent')),
                        const SizedBox(width: 12),
                        Expanded(child: _roleChip('child', Icons.child_care, 'Child')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(onPressed: _register, child: const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      ),
    );
  }

  // Role selection chip widget
  Widget _roleChip(String value, IconData icon, String label) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
