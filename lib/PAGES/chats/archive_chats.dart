import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../chats/Chat_page.dart';

class ArchivedChatsPage extends StatelessWidget {
  final List<QueryDocumentSnapshot> archivedChats;
  final List<Contact>? phoneContacts;
  final User currentUser;

  const ArchivedChatsPage({
    super.key,
    required this.archivedChats,
    required this.phoneContacts,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Archived Chats"),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: archivedChats.length,
        itemBuilder: (context, index) {
          final doc = archivedChats[index];
          final chatData = doc.data() as Map<String, dynamic>;
          final peerId = chatData['peerId'];
          final peerName = chatData['peerName'] ?? '';
          final peerMobile = chatData['peerMobile'] ?? '';
          final lastMessage = chatData['lastMessage'] ?? '';

          String displayName = '';
          if (phoneContacts != null) {
            final matchedContact = phoneContacts!.firstWhereOrNull((contact) {
              return contact.phones.any((phone) {
                final contactNum = phone.number
                    .replaceAll(RegExp(r'\D'), '')
                    .replaceAll('91', '');
                final firebaseNum = peerMobile
                    .replaceAll(RegExp(r'\D'), '')
                    .replaceAll('91', '');
                return contactNum.endsWith(firebaseNum) ||
                    firebaseNum.endsWith(contactNum);
              });
            });

            if (matchedContact != null) {
              displayName = matchedContact.displayName;
            }
          }

          if (displayName.isEmpty) {
            displayName =
                peerName.isNotEmpty
                    ? peerName
                    : (peerMobile.startsWith('+91')
                        ? peerMobile.substring(3)
                        : peerMobile);
          }

          return FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('client')
                    .doc(peerId)
                    .get(),
            builder: (context, snapshot) {
              ImageProvider? avatar;
              if (snapshot.hasData && snapshot.data!.exists) {
                final clientData =
                    snapshot.data!.data() as Map<String, dynamic>;
                final profileBase64 = clientData['profile_photo_base64'] ?? '';
                if (profileBase64.isNotEmpty) {
                  try {
                    avatar = MemoryImage(base64Decode(profileBase64));
                  } catch (_) {}
                }
              }

              return GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C3E50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          title: const Text(
                            'Choose Action',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.unarchive_rounded,
                                  color: Colors.white,
                                ),
                                title: const Text(
                                  "Remove From Archive",
                                  style: TextStyle(color: Colors.white),
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await FirebaseFirestore.instance
                                      .collection('chatList')
                                      .doc(currentUser.uid)
                                      .collection('chats')
                                      .doc(doc.id)
                                      .update({'archived': false});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Unarchived')),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                title: const Text(
                                  "Delete Chat",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await FirebaseFirestore.instance
                                      .collection('chatList')
                                      .doc(currentUser.uid)
                                      .collection('chats')
                                      .doc(doc.id)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chat deleted'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                  );
                },
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ChatScreen(
                              currentUserId: currentUser.uid,
                              peerId: peerId,
                              peerName: displayName,
                              PeerMobile: peerMobile,
                              contacts: [],
                            ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: avatar,
                          child:
                              avatar == null
                                  ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastMessage,
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
