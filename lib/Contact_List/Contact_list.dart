import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../PAGES/chats/Chat_page.dart';
import '../loadingindicator.dart';

class ContactListPage extends StatefulWidget {
  @override
  _ContactListPageState createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final userPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

  List<Contact> _contacts = [];
  List<String> _registeredNumbers = [];
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final isloading = false;
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    var permissionStatus = await Permission.contacts.status;
    if (!permissionStatus.isGranted) {
      permissionStatus = await Permission.contacts.request();
      if (!permissionStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contacts permission denied")),
        );
        return;
      }
    }
    Future<void> _refreshData() async {
      setState(() => isLoading = true);
      await Future.delayed(
        const Duration(seconds: 2),
      ); // fetch from API/Firestore
      setState(() => isLoading = false);
    }

    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      setState(() {
        _contacts = contacts;
      });

      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection("client")
              .where('isUsingApp', isEqualTo: true)
              .get();

      List<String> activeUsers =
          snapshot.docs
              .map(
                (doc) =>
                    doc['phone'].toString().replaceAll(RegExp(r'\s+|-'), ''),
              )
              .toList();

      setState(() {
        _registeredNumbers = activeUsers;
      });
    }
  }

  bool _isRegistered(String number) {
    String cleaned = number.replaceAll(RegExp(r'\s+|-'), '');
    return _registeredNumbers.contains(cleaned);
  }

  Future<void> _addNewContact() async {
    final newContact =
        Contact()
          ..name.first = ''
          ..name.last = ''
          ..phones = [Phone("")];

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ContactEditPage(contact: newContact)),
    );

    if (saved == true) {
      await _loadContacts();
    }
  }

  Future<void> _createNewGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                NewGroupPage(contacts: _contacts, currentUserPhone: userPhone),
      ),
    );
  }

  Widget _buildTopButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(icon, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(
      const Duration(seconds: 2),
    ); // fetch from API/Firestore
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts =
        _contacts.where((contact) {
          return contact.displayName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contacts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have ${_contacts.length} contacts',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
      body:
          _contacts.isEmpty
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : LoadingWrapper(
                isLoading: isLoading,
                onRefresh: _refreshData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredContacts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔍 Search Field
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search contacts...',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: Colors.white24,
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 16,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),

                          _buildTopButton(
                            Icons.group_add,
                            'New group',
                            _createNewGroup,
                          ),
                          const SizedBox(height: 12),
                          _buildTopButton(
                            Icons.person_add,
                            'New contact',
                            _addNewContact,
                            trailing: const Icon(
                              Icons.qr_code,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTopButton(Icons.groups, 'New community', () {}),
                          const SizedBox(height: 12),
                        ],
                      );
                    }

                    final contact = filteredContacts[index - 1];
                    final phoneNumber =
                        contact.phones.isNotEmpty
                            ? contact.phones.first.number.replaceAll(
                              RegExp(r'\s+|-'),
                              '',
                            )
                            : '';

                    if (phoneNumber.isEmpty) return const SizedBox();

                    final isRegistered = _isRegistered(phoneNumber);

                    return GestureDetector(
                      onTap: () async {
                        if (isRegistered) {
                          final snapshot =
                              await FirebaseFirestore.instance
                                  .collection('client')
                                  .where('phone', isEqualTo: phoneNumber)
                                  .get();

                          if (snapshot.docs.isNotEmpty) {
                            final doc = snapshot.docs.first;
                            final peerId = doc.id;
                            final peerMobile = doc['phone'];

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatScreen(
                                      currentUserId: currentUser!.uid,
                                      peerId: peerId,
                                      peerName: contact.displayName,
                                      PeerMobile: peerMobile,
                                      contacts: [],
                                    ),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(
                                'https://randomuser.me/api/portraits/men/75.jpg',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phoneNumber,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isRegistered
                                ? ElevatedButton(
                                  onPressed: () async {
                                    final snapshot =
                                        await FirebaseFirestore.instance
                                            .collection('client')
                                            .where(
                                              'phone',
                                              isEqualTo: phoneNumber,
                                            )
                                            .get();

                                    if (snapshot.docs.isNotEmpty) {
                                      final doc = snapshot.docs.first;
                                      final peerId = doc.id;
                                      final peerMobile = doc['phone'];

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ChatScreen(
                                                currentUserId: currentUser!.uid,
                                                peerId: peerId,
                                                peerName: contact.displayName,
                                                PeerMobile: peerMobile,
                                                contacts: [],
                                              ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text("Message"),
                                )
                                : ElevatedButton(
                                  onPressed: () {
                                    final message =
                                        "Hey! ${contact.displayName}, I’m using this awesome app and thought you’d love it too.\n"
                                        "Download it now from the Play Store:\n"
                                        "https://play.google.com/store/apps/details?id=com.yourcompany.yourapp";
                                    Share.share(message);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text("Invite"),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

extension on Contact {
  void operator [](String other) {}
}

Widget _buildTopButton(
  IconData icon,
  String label,
  VoidCallback onTap, {
  Widget? trailing,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    ),
  );
}

/////ADD NEW CONTACT SECTION CODE>>...............
class ContactEditPage extends StatefulWidget {
  final Contact contact;

  ContactEditPage({required this.contact});

  @override
  _ContactEditPageState createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.contact.name.first,
    );
    _lastNameController = TextEditingController(text: widget.contact.name.last);
    _phoneController = TextEditingController(
      text:
          widget.contact.phones.isNotEmpty
              ? widget.contact.phones.first.number
              : '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (_firstNameController.text.trim().isEmpty &&
        _lastNameController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one field.")),
      );
      return;
    }

    widget.contact.name.first = _firstNameController.text.trim();
    widget.contact.name.last = _lastNameController.text.trim();
    widget.contact.phones = [Phone(_phoneController.text.trim())];

    try {
      await widget.contact.insert();
      Navigator.of(context).pop(true);
    } catch (e) {
      print("Error saving contact: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save contact.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        title: const Text(
          'Add New Contact',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _buildInputField(
              controller: _firstNameController,
              label: 'first_name',
              icon: Icons.person,
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _lastNameController,
              label: 'last_name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _phoneController,
              label: 'phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Save Contact',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/////ADD NEW GROUP SECTION CODE>>...............

class NewGroupPage extends StatefulWidget {
  final List<Contact> contacts;
  final String currentUserPhone;
  const NewGroupPage({
    super.key,
    required this.contacts,
    required this.currentUserPhone,
  });

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedContactIds = {};
  File? _groupImageFile;
  bool _isUploading = false;

  List<Contact> _filteredContacts = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
    _searchController.addListener(_filterContacts);
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts =
          widget.contacts.where((contact) {
            final name = contact.displayName.toLowerCase();
            final first = contact.name.first.toLowerCase();
            final last = contact.name.last.toLowerCase();
            return name.contains(query) ||
                first.contains(query) ||
                last.contains(query);
          }).toList();
    });
  }

  void _toggleContactSelection(Contact contact) {
    setState(() {
      if (_selectedContactIds.contains(contact.id)) {
        _selectedContactIds.remove(contact.id);
      } else {
        _selectedContactIds.add(contact.id);
      }
    });
  }

  String getContactInitials(Contact contact) {
    final first = contact.name.first.isNotEmpty ? contact.name.first : '';
    final last = contact.name.last.isNotEmpty ? contact.name.last : '';
    return (first.isNotEmpty ? first[0] : '') +
        (last.isNotEmpty ? last[0] : '');
  }

  Future<void> _pickGroupImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // 🔽 compress for better performance
    );
    if (image != null) {
      setState(() => _groupImageFile = File(image.path));
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      _showSnackBar('Please enter a group name');
      return;
    }

    if (_selectedContactIds.isEmpty) {
      _showSnackBar('Please select at least one contact');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final selectedContacts = widget.contacts
          .where((c) => _selectedContactIds.contains(c.id))
          .toList(growable: false);

      final memberPhones =
          selectedContacts
              .map(
                (c) =>
                    c.phones.isNotEmpty
                        ? c.phones.first.number.replaceAll(
                          RegExp(r'\s+|[-()]'),
                          '',
                        )
                        : null,
              )
              .whereType<String>()
              .where((p) => p.isNotEmpty)
              .toSet()
              .toList();

      // 👇 Add creator's phone number
      memberPhones.add(widget.currentUserPhone);

      // 👇 Remove duplicates (just in case)
      final uniqueMemberPhones = memberPhones.toSet().toList();

      String? groupImageBase64;
      if (_groupImageFile != null) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          _groupImageFile!.path,
          quality: 30,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes != null && compressedBytes.length < 950000) {
          groupImageBase64 = base64Encode(compressedBytes);
        } else {
          _showSnackBar('Image too large to upload. Try another.');
          setState(() => _isUploading = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection('groups').add({
        'name': groupName,
        'members': uniqueMemberPhones,
        'created_by':
            widget.currentUserPhone, // 👈 Optionally store creator separately
        'groupImageBase64': groupImageBase64 ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Group created successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Group creation failed: $e');
      _showSnackBar('Error creating group. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('New Group', style: TextStyle(color: Colors.white)),
      ),
      body:
          widget.contacts.isEmpty
              ? const Center(
                child: Text(
                  'No contacts available.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        hintText: 'Search Contacts',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickGroupImage,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white24,
                            backgroundImage:
                                _groupImageFile != null
                                    ? FileImage(_groupImageFile!)
                                    : null,
                            child:
                                _groupImageFile == null
                                    ? const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _groupNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Group Name',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white54,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final isSelected = _selectedContactIds.contains(
                          contact.id,
                        );
                        return ListTile(
                          onTap: () => _toggleContactSelection(contact),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Text(
                              getContactInitials(contact),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            contact.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.green : Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  if (!_isUploading)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _createGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Create Group',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
    );
  }
}
