import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';

class ContactsScreen extends StatefulWidget {
  final String uid, role;
  const ContactsScreen({Key? key, required this.uid, required this.role}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _fs = FirestoreService();
  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  String? _parentUid;
  static const _platform = MethodChannel('com.childguard.childguard/sms');

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

  Future<bool> _isNumberOnWhatsApp(String phone) async {
    try {
      final bool onWhatsApp = await _platform.invokeMethod('isNumberOnWhatsApp', {'phone': phone});
      return onWhatsApp;
    } catch (e) {
      debugPrint('WhatsApp check error: $e');
      return false;
    }
  }

  Future<void> _syncContacts() async {
    if (await Permission.contacts.request().isGranted) {
      setState(() => _loading = true);
      final contacts = await fc.FlutterContacts.getAll(
        properties: {fc.ContactProperty.name, fc.ContactProperty.phone},
      );
      setState(() => _loading = false);

      if (mounted) {
        _showContactSelectionDialog(contacts);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
    }
  }

  void _showContactSelectionDialog(List<fc.Contact> allContacts) {
    // Filter contacts that have phone numbers
    final validContacts = allContacts.where((c) => c.phones.isNotEmpty).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Text("Select Emergency Contacts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: validContacts.length,
                  itemBuilder: (context, index) {
                    final contact = validContacts[index];
                    final String? name = contact.displayName;
                    final String phone = contact.phones.first.number;
                    final isAlreadyAdded = _contacts.any((c) => c['phone'] == phone.replaceAll(RegExp(r'\s+'), ''));

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Text((name != null && name.isNotEmpty) ? name[0].toUpperCase() : "?"),
                      ),
                      title: Text(name ?? 'No Name'),
                      subtitle: Text(phone),
                      trailing: isAlreadyAdded 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.add_circle_outline, color: Colors.blue),
                      onTap: isAlreadyAdded ? null : () async {
                        Navigator.pop(context); // Close picker
                        setState(() => _loading = true);
                        final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
                        
                        // Check WhatsApp status before adding
                        final onWhatsApp = await _isNumberOnWhatsApp(cleanPhone);
                        
                        if (mounted) {
                          if (onWhatsApp) {
                            // Add with WhatsApp alert enabled by default
                            await _fs.addEmergencyContact(_parentUid!, name ?? 'No Name', cleanPhone, '');
                            _loadContacts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${name ?? "Contact"} added to emergency contacts')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${name ?? "Contact"} is not active on WhatsApp')),
                            );
                          }
                          setState(() => _loading = false);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addContact() {
    final nameCtrl = TextEditingController();
    String fullPhone = '';
    String countryCode = 'PK';
    bool isOnWhatsApp = false;
    bool checkingWhatsApp = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                IntlPhoneField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialCountryCode: countryCode,
                  onChanged: (phone) async {
                    fullPhone = phone.completeNumber;
                    countryCode = phone.countryISOCode;
                    
                    // Auto check WhatsApp
                    if (fullPhone.length > 8) {
                      setState(() => checkingWhatsApp = true);
                      final onWA = await _isNumberOnWhatsApp(fullPhone);
                      setState(() {
                        isOnWhatsApp = onWA;
                        checkingWhatsApp = false;
                      });
                    }
                  },
                ),
                if (checkingWhatsApp)
                  const LinearProgressIndicator()
                else if (fullPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isOnWhatsApp ? Icons.check_circle : Icons.error_outline,
                          color: isOnWhatsApp ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnWhatsApp ? 'Available on WhatsApp' : 'Not detected on WhatsApp',
                          style: TextStyle(
                            color: isOnWhatsApp ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty && fullPhone.isNotEmpty) {
                  await _fs.addEmergencyContact(_parentUid!, name, fullPhone, countryCode);
                  // Ensure newly added contacts have the flag in local state too if needed, 
                  // but _loadContacts() will refresh everything.
                  Navigator.pop(ctx);
                  _loadContacts();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter name and valid phone number')),
                  );
                }
              },
              child: const Text('Add'),
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
      floatingActionButton: isParent ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'sync',
            onPressed: _syncContacts,
            label: const Text('Sync WhatsApp'),
            icon: const Icon(Icons.sync),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _addContact,
            label: const Text('Add Contact'),
            icon: const Icon(Icons.add),
          ),
        ],
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
                        // WhatsApp Alert Toggle
                        if (isParent)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Alert", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                              Switch(
                                value: contact['whatsappAlert'] ?? true,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) async {
                                  final newContact = Map<String, dynamic>.from(contact);
                                  newContact['whatsappAlert'] = val;
                                  await _fs.updateEmergencyContact(_parentUid!, contact, newContact);
                                  _loadContacts();
                                },
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        const SizedBox(width: 8),
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
