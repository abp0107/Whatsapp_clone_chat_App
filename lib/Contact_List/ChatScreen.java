import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String peerId;
  final String peerName;
  final String PeerMobile;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.PeerMobile,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? currentUserName;
  String? currentUserMobile;
  String? nameSavedByPeer;
  String? localContactName;
  String? localContactMobile;
  bool isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _loadNameSavedByPeer();
    _loadLocalContactDetails();
    _checkIfBlocked();

    _firestore
        .collection('chatList')
        .doc(widget.currentUserId)
        .collection('chats')
        .doc(widget.peerId)
        .update({'unreadCount': 0}).catchError((e) {});

    _messageController.addListener(() {
      setState(() {});
    });
  }

  void _loadCurrentUserData() async {
    final userDoc =
        await _firestore.collection('client').doc(widget.currentUserId).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        currentUserName = "${data['firstName']} ${data['lastName']}".trim();
        currentUserMobile = data['phone'] ?? '';
      });
    }
  }

  void _loadNameSavedByPeer() async {
    final contactDoc = await _firestore
        .collection('client')
        .doc(widget.peerId)
        .collection('contacts')
        .doc(widget.currentUserId)
        .get();

    if (contactDoc.exists) {
      setState(() {
        nameSavedByPeer = contactDoc.data()?['name']?.toString();
      });
    }
  }

  void _loadLocalContactDetails() async {
    if (await Permission.contacts.request().isGranted) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      String peerPhone = widget.PeerMobile.replaceAll(RegExp(r'\D'), '');
      if (peerPhone.length > 10) {
        peerPhone = peerPhone.substring(peerPhone.length - 10);
      }

      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String contactPhone = phone.number.replaceAll(RegExp(r'\D'), '');
          if (contactPhone.length > 10) {
            contactPhone = contactPhone.substring(contactPhone.length - 10);
          }

          if (peerPhone == contactPhone) {
            setState(() {
              localContactName = contact.displayName;
              localContactMobile = phone.number;
            });
            return;
          }
        }
      }
    }
  }

  Future<void> _checkIfBlocked() async {
    final blockDoc = await _firestore
        .collection('client')
        .doc(widget.currentUserId)
        .collection('blocked')
        .doc(widget.peerId)
        .get();

    setState(() {
      isBlocked = blockDoc.exists;
    });
  }

  Future<void> _blockUser() async {
    await _firestore
        .collection('client')
        .doc(widget.currentUserId)
        .collection('blocked')
        .doc(widget.peerId)
        .set({'blockedAt': FieldValue.serverTimestamp()});
    setState(() => isBlocked = true);
    Fluttertoast.showToast(msg: "User blocked");
  }

  Future<void> _unblockUser() async {
    await _firestore
        .collection('client')
        .doc(widget.currentUserId)
        .collection('blocked')
        .doc(widget.peerId)
        .delete();
    setState(() => isBlocked = false);
    Fluttertoast.showToast(msg: "User unblocked");
  }

  String getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  void sendMessage() async {
    if (isBlocked) {
      Fluttertoast.showToast(msg: "You have blocked this user");
      return;
    }

    if (_messageController.text.trim().isEmpty ||
        currentUserName == null ||
        currentUserMobile == null) return;

    String chatId = getChatId(widget.currentUserId, widget.peerId);
    String messageText = _messageController.text.trim();
    _messageController.clear();

    final timestamp = FieldValue.serverTimestamp();

    final messageData = {
      'senderId': widget.currentUserId,
      'receiverId': widget.peerId,
      'message': messageText,
      'timestamp': timestamp,
      'isRead': false,
      'senderName': currentUserName,
      'receiverName': widget.peerName,
    };

    await _firestore
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .add(messageData);

    await _firestore
        .collection('chatList')
        .doc(widget.currentUserId)
        .collection('chats')
        .doc(widget.peerId)
        .set({
      'peerId': widget.peerId,
      'peerName': widget.peerName,
      'peerMobile': widget.PeerMobile,
      'lastMessage': messageText,
      'timestamp': timestamp,
      'unreadCount': 0,
    });

    final receiverRef = _firestore
        .collection('chatList')
        .doc(widget.peerId)
        .collection('chats')
        .doc(widget.currentUserId);

    final receiverSnapshot = await receiverRef.get();
    int unreadCount = 1;
    if (receiverSnapshot.exists) {
      unreadCount = (receiverSnapshot.data()?['unreadCount'] ?? 0) + 1;
    }

    await receiverRef.set({
      'peerId': widget.currentUserId,
      'peerName': currentUserName,
      'peerMobile': currentUserMobile,
      'lastMessage': messageText,
      'timestamp': timestamp,
      'unreadCount': unreadCount,
    });
  }

  @override
  Widget build(BuildContext context) {
    String chatId = getChatId(widget.currentUserId, widget.peerId);
    final isTyping = _messageController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(32)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Get.back(),
                  ),
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        AssetImage("assets/Images/cropped_circle_image.png"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      localContactName ?? widget.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, size: 30),
                    onPressed: () {
                      Fluttertoast.showToast(msg: "Calling...");
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, size: 30),
                    onPressed: () {
                      Fluttertoast.showToast(msg: "Video calling...");
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'block') await _blockUser();
                      if (value == 'unblock') await _unblockUser();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: isBlocked ? 'unblock' : 'block',
                        child: Text(isBlocked ? 'Unblock' : 'Block'),
                      )
                    ],
                  )
                ],
              ),
            ),

            // Message List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('messages')
                    .doc(chatId)
                    .collection('chats')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == widget.currentUserId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isMe ? Colors.white : Colors.lightBlue.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            msg['message'],
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input area
            if (!isBlocked)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            if (!isTyping)
                              IconButton(
                                icon: const Icon(Icons.emoji_emotions_outlined,
                                    color: Colors.white70),
                                onPressed: () {
                                  Fluttertoast.showToast(
                                      msg: "Emoji picker opened");
                                },
                              ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 5,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  hintStyle:
                                      TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (!isTyping) ...[
                              IconButton(
                                icon: const Icon(Icons.currency_rupee,
                                    color: Colors.white70),
                                onPressed: () {
                                  Fluttertoast.showToast(msg: "Payment feature");
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.white70),
                                onPressed: () {
                                  Fluttertoast.showToast(msg: "Open camera");
                                },
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.attach_file,
                                  color: Colors.white70),
                              onPressed: () {
                                Fluttertoast.showToast(
                                    msg: "Open file picker");
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        if (isTyping) {
                          sendMessage();
                        } else {
                          Fluttertoast.showToast(
                              msg: "Voice message feature");
                        }
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
