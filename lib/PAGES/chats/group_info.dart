import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';

class GroupInfoPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<Contact> contacts;

  const GroupInfoPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.contacts,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late Future<DocumentSnapshot> groupFuture;

  @override
  void initState() {
    super.initState();
    groupFuture =
        FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .get();
  }

  void removeMember(String phone) async {
    final groupRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId);

    await groupRef.update({
      'members': FieldValue.arrayRemove([phone]),
    });

    setState(() {
      groupFuture = groupRef.get();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Member removed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.white54,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: groupFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final String? groupImageBase64 = groupData['groupImageBase64'];
          final List<dynamic> memberIds = groupData['members'] ?? [];

          final memberData =
              memberIds.map((id) {
                final contact = widget.contacts.firstWhere(
                  (c) =>
                      c.phones.isNotEmpty &&
                      c.phones.first.number.replaceAll(' ', '').contains(id),
                  orElse: () => Contact(),
                );
                final name =
                    contact.displayName.isEmpty ? id : contact.displayName;
                return {'id': id, 'name': name};
              }).toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (groupImageBase64 != null &&
                          groupImageBase64.isNotEmpty)
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: MemoryImage(
                            base64Decode(groupImageBase64),
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blueGrey,
                          child: Icon(
                            Icons.group,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        widget.groupName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Members (${memberData.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...memberData.map(
                        (member) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(member['name']),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'remove') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title: const Text("Remove Member"),
                                        content: Text(
                                          "Are you sure you want to remove ${member['name']}?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text("Remove"),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirmed ?? false) {
                                  removeMember(member['id']);
                                }
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove Member'),
                                  ),
                                ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 30,
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Member'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AddMemberPage(
                              groupId: widget.groupId,
                              existingMemberIds: memberIds,
                              contacts: widget.contacts,
                            ),
                      ),
                    );
                    setState(() {
                      groupFuture =
                          FirebaseFirestore.instance
                              .collection('groups')
                              .doc(widget.groupId)
                              .get();
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AddMemberPage extends StatefulWidget {
  final String groupId;
  final List<dynamic> existingMemberIds;
  final List<Contact> contacts;

  const AddMemberPage({
    super.key,
    required this.groupId,
    required this.existingMemberIds,
    required this.contacts,
  });

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  List<String> selectedMemberPhones = [];
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredContacts =
        widget.contacts.where((contact) {
          final phone =
              contact.phones.isNotEmpty
                  ? contact.phones.first.number.replaceAll(' ', '')
                  : '';
          final name = contact.displayName.toLowerCase();

          return phone.isNotEmpty &&
              !widget.existingMemberIds.contains(phone) &&
              (name.contains(searchQuery.toLowerCase()) ||
                  phone.contains(searchQuery));
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Members"),
        backgroundColor: Colors.blueAccent,
        actions: [
          TextButton(
            onPressed:
                selectedMemberPhones.isEmpty
                    ? null
                    : () async {
                      final groupRef = FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.groupId);

                      await groupRef.update({
                        'members': FieldValue.arrayUnion(selectedMemberPhones),
                      });

                      Navigator.pop(context);
                    },
            child: const Text(
              "Add",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search by name or number",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          // 📋 Contact List
          Expanded(
            child:
                filteredContacts.isEmpty
                    ? const Center(child: Text("No contacts found"))
                    : ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        final phone =
                            contact.phones.isNotEmpty
                                ? contact.phones.first.number.replaceAll(
                                  ' ',
                                  '',
                                )
                                : '';

                        final isSelected = selectedMemberPhones.contains(phone);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(contact.displayName),
                            subtitle: Text(phone),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) {
                                setState(() {
                                  if (isSelected) {
                                    selectedMemberPhones.remove(phone);
                                  } else {
                                    selectedMemberPhones.add(phone);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedMemberPhones.remove(phone);
                                } else {
                                  selectedMemberPhones.add(phone);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
