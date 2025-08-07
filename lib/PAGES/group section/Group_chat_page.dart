import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../chats/camera_in_chat.dart';
import '../chats/group_info.dart';
import 'group_video_call.dart';
import 'group_voice_call.dart';
import 'groupimagesend.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<Contact> contacts;
  final String currentUserName;
  final String currentUserId;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.contacts,
    required this.currentUserName,
    required this.currentUserId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? groupImageBase64;
  bool isTyping = false;
  String? senderPhoneNumber;

  @override
  void initState() {
    super.initState();
    _loadGroupImage();
    _loadSenderPhone();
    _messageController.addListener(() {
      setState(() {
        isTyping = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  void _loadGroupImage() async {
    final doc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        groupImageBase64 = data['groupImageBase64'];
      });
    }
  }

  void _loadSenderPhone() async {
    final userDoc =
        await _firestore.collection('users').doc(widget.currentUserId).get();
    if (userDoc.exists && userDoc.data()!.containsKey('phoneNumber')) {
      senderPhoneNumber = userDoc['phoneNumber'];
    }
  }

  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userDoc =
        await _firestore.collection('client').doc(widget.currentUserId).get();
    final firstName = userDoc['first_name'] ?? widget.currentUserName;
    final phone = userDoc['phone'] ?? "";

    await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
          'text': text,
          'senderName': firstName,
          'senderId': widget.currentUserId,
          'senderPhone': phone,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _messageController.clear();
  }

  String _getFormattedDate(DateTime timestamp) {
    final now = DateTime.now();
    if (timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day) {
      return "Today";
    } else if (timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day - 1) {
      return "Yesterday";
    } else {
      return DateFormat('dd MMM yyyy').format(timestamp);
    }
  }

  String getDisplayName(String senderPhone, String? fallbackName) {
    final matchedContact = widget.contacts.firstWhere(
      (contact) =>
          contact.phones.isNotEmpty &&
          senderPhone.isNotEmpty &&
          contact.phones.any(
            (p) =>
                p.normalizedNumber
                    .replaceAll(' ', '')
                    .contains(senderPhone.replaceAll(' ', '')) ||
                senderPhone
                    .replaceAll(' ', '')
                    .contains(p.normalizedNumber.replaceAll(' ', '')),
          ),
      orElse: () => Contact(),
    );

    if (matchedContact.displayName != null &&
        matchedContact.displayName.isNotEmpty) {
      return matchedContact.displayName;
    } else if (senderPhone.isNotEmpty) {
      return senderPhone;
    } else {
      return fallbackName ?? 'User';
    }
  }

  Widget buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    String displayName = 'You';

    if (!isMe) {
      final senderPhone = data['senderPhone']?.toString() ?? '';
      displayName = getDisplayName(senderPhone, data['senderName']);
    }

    if (data['type'] == 'image' && data['imageData'] != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(data['imageData']),
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(data['text'] ?? '', style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Future<void> clearGroupChat() async {
    final ref = _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages');
    final snapshot = await ref.get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Group chat cleared")));
  }

  Future<void> deleteGroup() async {
    final ref = _firestore.collection('groups').doc(widget.groupId);
    final messages = await ref.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(ref);
    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Group deleted")));
    }
  }

  Future<void> startGroupCall({required bool isVideo}) async {
    final groupDoc =
        await _firestore.collection('groups').doc(widget.groupId).get();
    if (!groupDoc.exists) return;
    final data = groupDoc.data()!;
    final List members = data['members'] ?? [];

    for (String uid in members) {
      if (uid != widget.currentUserId) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('incomingCalls')
            .add({
              'groupId': widget.groupId,
              'groupName': widget.groupName,
              'callerId': widget.currentUserId,
              'callerName': widget.currentUserName,
              'isVideo': isVideo,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
    }

    if (isVideo) {
      Get.to(() => JoinChannelGroupVideo(groupName: widget.groupName));
    } else {
      Get.to(() => JoinGroupVoiceCall(groupName: widget.groupName));
    }
  }

  Future<void> sendGroupImageMessage(File imageFile) async {
    try {
      // Compress
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 640,
        minHeight: 640,
        quality: 50,
      );

      if (compressedBytes == null) {
        Fluttertoast.showToast(msg: "Image compression failed");
        return;
      }

      // Base64 encode
      final base64Image = base64Encode(compressedBytes);
      if (base64Image.length > 1000000) {
        Fluttertoast.showToast(msg: "Image too large. Try smaller image.");
        return;
      }

      // Get user data from `client`
      final userDoc =
          await _firestore.collection('client').doc(widget.currentUserId).get();
      final senderName = userDoc['first_name'] ?? widget.currentUserName;
      final senderPhone = userDoc['phone'] ?? '';

      final imageMessage = {
        'senderId': widget.currentUserId,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'imageData': base64Image,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save in Firestore
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add(imageMessage);

      Fluttertoast.showToast(msg: "Image sent to group");
    } catch (e) {
      print("Error sending group image: $e");
      Fluttertoast.showToast(msg: "Failed to send group image");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Column(
        children: [
          // AppBar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(45),
              ),
              child: Row(
                children: [
                  const BackButton(color: Colors.black),

                  // 👉 GestureDetector only wraps the tappable group info (image + name)
                  GestureDetector(
                    onTap: () {
                      Get.to(
                        () => GroupInfoPage(
                          groupId: widget.groupId,
                          groupName: widget.groupName,
                          contacts: widget.contacts,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        if (groupImageBase64 != null &&
                            groupImageBase64!.isNotEmpty)
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: MemoryImage(
                              base64Decode(groupImageBase64!),
                            ),
                          )
                        else
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.group),
                          ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.30,
                          child: Text(
                            widget.groupName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 📞 Call buttons (not wrapped by GestureDetector)
                  IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () => startGroupCall(isVideo: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () => startGroupCall(isVideo: true),
                  ),

                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'clear') await clearGroupChat();
                      if (value == 'delete') await deleteGroup();
                    },
                    itemBuilder:
                        (ctx) => const [
                          PopupMenuItem(
                            value: 'clear',
                            child: Text("Clear Chat"),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text("Delete Group"),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                Map<String, List<DocumentSnapshot>> grouped = {};

                for (final doc in docs) {
                  final ts =
                      (doc['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final dateKey = _getFormattedDate(ts);
                  grouped.putIfAbsent(dateKey, () => []).add(doc);
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children:
                      grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...entry.value.map((doc) {
                              final data = doc.data()! as Map<String, dynamic>;
                              final isMe =
                                  data['senderId'] == widget.currentUserId;
                              return buildMessageBubble(data, isMe);
                            }).toList(),
                          ],
                        );
                      }).toList(),
                );
              },
            ),
          ),

          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Colors.white70,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white70,
                          ),
                          onPressed: () async {
                            final File? image = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CameraCapturePage(),
                              ),
                            );
                            if (image != null) {
                              final File? selected = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ImagePreviewPagegroup(
                                        imageFile: image,
                                      ),
                                ),
                              );

                              if (selected != null) {
                                sendGroupImageMessage(
                                  selected,
                                ); // base64 convert & send
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTyping ? Icons.send : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
