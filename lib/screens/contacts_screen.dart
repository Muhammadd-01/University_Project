import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';

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
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl, 
                decoration: InputDecoration(
                  labelText: 'Name', 
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+923001234567',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty && phone.startsWith('+')) {
                await _fs.addEmergencyContact(_parentUid!, name, phone, '');
                Navigator.pop(ctx);
                _loadContacts();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter name and phone number with country code (e.g. +92...)')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
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

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == 'parent';
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(onPressed: _loadContacts, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: isParent ? FloatingActionButton.extended(
        onPressed: _addContact,
        label: const Text('Add Contact'),
        icon: const Icon(Icons.add),
      ) : null,
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _contacts.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No emergency contacts added yet.', style: TextStyle(color: Colors.grey[600])),
                  if (isParent) TextButton(onPressed: _addContact, child: const Text('Add one now')),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.primaryContainer,
                          child: Text(contact['name'][0].toUpperCase(), style: TextStyle(color: color.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(contact['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  if (contact['countryCode'] != null)
                                    Text('(${contact['countryCode']})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              Text(contact['phone'], style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                        ),
                        // Call Button
                        IconButton(
                          onPressed: () => _makeCall(contact['phone']),
                          icon: const Icon(Icons.call, color: Colors.blue),
                          tooltip: 'Call',
                        ),
                        // WhatsApp Button
                        IconButton(
                          onPressed: () => _openWhatsApp(contact['phone']),
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                          tooltip: 'WhatsApp',
                        ),
                        if (isParent)
                          IconButton(
                            onPressed: () => _deleteContact(contact),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
