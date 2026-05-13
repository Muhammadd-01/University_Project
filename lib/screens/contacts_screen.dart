import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_widget.dart';

class ContactsScreen extends StatefulWidget {
  final String uid, role;
  const ContactsScreen({super.key, required this.uid, required this.role});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _fs = FirestoreService();
  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  String? _parentUid;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() async {
    setState(() => _loading = true);
    String targetUid = widget.uid;
    
    if (widget.role == 'child') {
      final user = await _fs.getUser(widget.uid);
      if (user != null && user['connectedTo'] != null) {
        targetUid = user['connectedTo'];
        _parentUid = targetUid;
      }
    } else {
      _parentUid = widget.uid;
    }

    final contacts = await _fs.getEmergencyContacts(targetUid);
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  void _addContact() {
    final nameCtrl = TextEditingController();
    String fullPhone = '';
    String countryCode = 'PK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(
                    labelText: 'Name', 
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                IntlPhoneField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                  ),
                  initialCountryCode: countryCode,
                  onChanged: (phone) {
                    fullPhone = phone.completeNumber;
                    countryCode = phone.countryISOCode;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty && fullPhone.isNotEmpty) {
                  await _fs.addEmergencyContact(_parentUid!, name, fullPhone, countryCode);
                  Navigator.pop(ctx);
                  _loadContacts();
                }
              },
              child: const Text('Add to SOS'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteContact(Map<String, dynamic> contact) async {
    await _fs.removeEmergencyContact(_parentUid!, contact);
    _loadContacts();
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'parent';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Emergency Contacts', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _loadContacts, icon: const Icon(Icons.refresh_rounded, color: Colors.black)),
        ],
      ),
      body: _loading 
        ? const LoadingWidget(message: 'Syncing contacts...')
        : _contacts.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('No SOS contacts yet.', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                  if (isParent) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addContact, 
                      icon: const Icon(Icons.add_rounded), 
                      label: const Text('Add First Contact'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return _buildContactCard(contact, isParent, colorScheme)
                    .animate(delay: (index * 100).ms)
                    .fadeIn()
                    .slideY(begin: 0.1, end: 0);
              },
            ),
      floatingActionButton: isParent ? FloatingActionButton.extended(
        onPressed: _addContact,
        label: const Text('New SOS Contact'),
        icon: const Icon(Icons.person_add_rounded),
        elevation: 4,
      ).animate().scale(delay: 400.ms, curve: Curves.elasticOut) : null,
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact, bool isParent, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Text(
              contact['name'][0].toUpperCase(), 
              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(contact['phone'], style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _makeCall(contact['phone']),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.call_rounded, color: Colors.green, size: 20),
            ),
          ),
          if (isParent)
            IconButton(
              onPressed: () => _deleteContact(contact),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

