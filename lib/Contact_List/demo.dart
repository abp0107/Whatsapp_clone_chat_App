import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Contact {
  final String displayName;
  final Name name;
  final List<Phone> phones;

  Contact({
    required this.displayName,
    required this.name,
    required this.phones,
  });
}

class Name {
  final String first;
  final String last;

  Name({required this.first, required this.last});
}

class Phone {
  final String number;

  Phone({required this.number});
}

class NewGroupPage extends StatefulWidget {
  final List<Contact> contacts;

  const NewGroupPage({super.key, required this.contacts});

  @override
  _NewGroupPageState createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<Contact> _selectedContacts = {};
  File? _groupImageFile;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  List<Contact> _filteredContacts = [];

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

  String getContactInitials(Contact contact) {
    final first = contact.name.first.isNotEmpty ? contact.name.first : '';
    final last = contact.name.last.isNotEmpty ? contact.name.last : '';
    return (first.isNotEmpty ? first[0] : '') +
        (last.isNotEmpty ? last[0] : '');
  }

  void _toggleContactSelection(Contact contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Future<void> _pickGroupImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _groupImageFile = File(image.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() => _isUploading = true);

    String? base64Image;
    try {
      if (_groupImageFile != null) {
        final bytes = await _groupImageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }
    } catch (e) {
      debugPrint("Image encoding failed: $e");
    }

    List<String> memberPhones =
        _selectedContacts
            .map(
              (c) =>
                  c.phones.isNotEmpty
                      ? c.phones.first.number.replaceAll(
                        RegExp(r'\s+|[-()]'),
                        '',
                      )
                      : '',
            )
            .where((phone) => phone.isNotEmpty)
            .toSet()
            .toList();

    await FirebaseFirestore.instance.collection('groups').add({
      'name': _groupNameController.text.trim(),
      'members': memberPhones,
      'groupImageBase64': base64Image ?? '',
      'created_at': FieldValue.serverTimestamp(),
    });

    setState(() => _isUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
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
          // Group info input
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
                            ? const Icon(Icons.camera_alt, color: Colors.white)
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
                  ),
                ),
              ],
            ),
          ),
          // Contacts list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                final isSelected = _selectedContacts.contains(contact);
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
                  trailing:
                      isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(
                            Icons.radio_button_unchecked,
                            color: Colors.white,
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
