import 'dart:convert';
import 'dart:io';

import 'package:TwinBox/PAGES/chats/profile_show.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../loadingindicator.dart';
import '../../profile_card.dart';
import '../calls_page/Join_Channel_Audio.dart';
import '../calls_page/join_channel_video.dart';
import '../map_page/map.dart';
import 'camera_in_chat.dart';
import 'image_preview_page.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;

  final String peerId;
  final String peerName;
  final String PeerMobile;
  final bool isGroupChat;

  String getChatId(String user1Id, String user2Id) {
    return user1Id.compareTo(user2Id) < 0
        ? '${user1Id}_$user2Id'
        : '${user2Id}_$user1Id';
  }

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.PeerMobile,

    this.isGroupChat = false,
    required List contacts,
  });
  void updateLastRead() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('chatList')
        .doc(currentUserId)
        .collection('chats')
        .doc(peerId) // or correct chatId based on your logic
        .update({'lastRead': FieldValue.serverTimestamp()});
  }

  void initState() {
    updateLastRead();
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late var chatId = getChatId(
    currentUserId,
    widget.peerId,
  ); // however you build it// should already be available in ChatScreen
  final TextEditingController _messageController = TextEditingController();
  List<File> selectedImages = [];
  String? currentUserName;
  String? currentUserMobile;
  String? nameSavedByPeer;
  String? localContactName;
  String peerStatus = 'offline'; // default offline
  String? localContactMobile;
  bool isBlocked = false;
  bool isGroupChat = false; // set to true manually if this is a group chat
  ImageProvider? peerProfileImage;

  void _showAttachmentBottomSheet(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3), // Dim background
      builder: (context) {
        return Center(
          child: Stack(
            children: [
              Positioned(
                bottom: 85, // WhatsApp-style popup position
                left: 20,
                right: 24,
                child: Material(
                  color: const Color(0xFF224787),
                  borderRadius: BorderRadius.circular(20),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconTile(
                              context,
                              Icons.image,
                              "Gallery",
                              () {},
                            ),
                            _buildIconTile(
                              context,
                              Icons.camera_alt,
                              "Camera",
                              () {},
                            ),
                            _buildIconTile(
                              context,
                              Icons.location_on,
                              "Location",
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => GoogleMapScreen(
                                          chatId: chatId,
                                          receiverId: widget.peerId,
                                        ),
                                  ),
                                );
                              },
                            ),
                            _buildIconTile(
                              context,
                              Icons.person,
                              "Contact",
                              () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconTile(
                              context,
                              Icons.insert_drive_file,
                              "Document",
                              () {},
                            ),
                            _buildIconTile(
                              context,
                              Icons.headphones,
                              "Audio",
                              () {},
                            ),
                            _buildIconTile(context, Icons.poll, "Poll", () {}),
                            _buildIconTile(
                              context,
                              Icons.payment,
                              "Payment",
                              () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white10,
            radius: 24,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void initState() {
    super.initState();
    // ✅ now valid
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final peerId = widget.peerId; // assuming peerId is passed via constructor
    chatId = getChatId(currentUserId, peerId);
    _loadCurrentUserData();
    _loadNameSavedByPeer();
    _loadLocalContactDetails();
    _loadPeerStatus();
    _checkIfBlocked();
    _loadPeerProfilePhoto();
    markMessagesAsRead();
    _firestore
        .collection('chatList')
        .doc(widget.currentUserId)
        .collection('chats')
        .doc(widget.peerId)
        .update({'unreadCount': 0})
        .catchError((_) {});

    _messageController.addListener(() {
      setState(() {});
    });
  }

  void _loadPeerStatus() {
    _firestore.collection('client').doc(widget.peerId).snapshots().listen((
      doc,
    ) {
      if (doc.exists && doc.data()!.containsKey('status')) {
        setState(() {
          peerStatus = doc['status']; // "online" or "offline"
        });
      }
    });
  }

  void markMessagesAsRead() async {
    final chatId = getChatId(widget.currentUserId, widget.peerId);
    final unreadMessages =
        await _firestore
            .collection('messages')
            .doc(chatId)
            .collection('chats')
            .where('receiverId', isEqualTo: widget.currentUserId)
            .where('isRead', isEqualTo: false)
            .get();

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  void _loadCurrentUserData() async {
    final userDoc =
        await _firestore.collection('client').doc(widget.currentUserId).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        currentUserName = "${data['first_name']} ${data['last_name']}".trim();
        currentUserMobile = data['phone'] ?? '';
      });
    }
  }

  void _loadNameSavedByPeer() async {
    final contactDoc =
        await _firestore
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

  void _loadPeerProfilePhoto() async {
    try {
      final peerDoc =
          await _firestore.collection('client').doc(widget.peerId).get();
      if (peerDoc.exists) {
        final base64Str = peerDoc.data()?['profile_photo_base64'];
        if (base64Str != null && base64Str is String && base64Str.isNotEmpty) {
          final bytes = base64Decode(base64Str);
          setState(() {
            peerProfileImage = MemoryImage(bytes);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile photo: $e");
    }
  }

  Future<void> _checkIfBlocked() async {
    final blockDoc =
        await _firestore
            .collection('client')
            .doc(widget.currentUserId)
            .collection('blocked')
            .doc(widget.peerId)
            .get();
    setState(() => isBlocked = blockDoc.exists);
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

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(
      const Duration(seconds: 2),
    ); // fetch from API/Firestore
    setState(() => isLoading = false);
  }

  void sendMessage() async {
    if (isBlocked) {
      Fluttertoast.showToast(msg: "You have blocked this user");
      return;
    }

    if (_messageController.text.trim().isEmpty) return;

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
    final chatId = getChatId(widget.currentUserId, widget.peerId);

    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: LoadingWrapper(
          isLoading: isLoading,
          onRefresh: _refreshData,
          child: Column(
            children: [
              /// Top Bar
              Padding(
                padding: const EdgeInsets.only(right: 10, left: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(40)),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Get.to(
                        UserProfilePage(
                          userId: widget.peerId,
                          userName: widget.peerName,
                          phoneNumber: widget.PeerMobile,
                          currentUserId: currentUserId,
                          peerId: widget.peerId,
                          peerName: widget.peerName,
                          PeerMobile: "",
                          isGroupChat: false,
                        ),
                      );
                      print("ONtap Successfully");

                      ///ahiya user details page banavo
                    },
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                          onPressed:
                              () => Get.to(() => const ProfileCardPage()),
                        ),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: peerProfileImage,
                          child:
                              peerProfileImage == null
                                  ? const Icon(
                                    Icons.person,
                                    color: Colors.black,
                                  )
                                  : null,
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
                            if (localContactName != null &&
                                localContactMobile != null) {
                              Get.to(
                                JoinChannelAudio(
                                  currentUserId: widget.currentUserId,
                                  peerId: widget.peerId,
                                  peerName: localContactName!,
                                  peerPhone: localContactMobile!,
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam, size: 30),
                          onPressed: () {
                            if (localContactName != null &&
                                localContactMobile != null) {
                              Get.to(
                                JoinChannelVideo(
                                  peerName: localContactName!,
                                  peerPhone: localContactMobile!,
                                ),
                              );
                            }
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'clear_chat') {
                              await _clearChat();
                            } else if (value == 'block') {
                              await _blockUser();
                            } else if (value == 'unblock') {
                              await _unblockUser();
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'clear_chat',
                                  child: Text('Clear Chat'),
                                ),
                                PopupMenuItem(
                                  value: isBlocked ? 'unblock' : 'block',
                                  child: Text(isBlocked ? 'Unblock' : 'Block'),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// Messages List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('messages')
                          .doc(chatId)
                          .collection('chats')
                          .orderBy('timestamp')
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final data = msg.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == widget.currentUserId;
                        final isImage = data['type'] == 'image';
                        final isLocation = data['type'] == 'location';

                        final timestamp = data['timestamp'] as Timestamp?;
                        final timeStr =
                            timestamp != null
                                ? DateFormat(
                                  'hh:mm a',
                                ).format(timestamp.toDate())
                                : '';

                        final Icon tickIcon =
                            isMe
                                ? Icon(
                                  data['isRead'] == true
                                      ? Icons.done_all
                                      : peerStatus == 'online'
                                      ? Icons.done_all
                                      : Icons.check,
                                  size: 14,
                                  color:
                                      data['isRead'] == true
                                          ? Colors.blue
                                          : Colors.grey,
                                )
                                : const Icon(null);

                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe ? const Color(0xFFDCF8C6) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft:
                                    isMe
                                        ? const Radius.circular(16)
                                        : Radius.zero,
                                bottomRight:
                                    isMe
                                        ? Radius.zero
                                        : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe && isGroupChat)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      data['senderName'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),

                                // Handle message types
                                if (isImage)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ImagePreviewPage2(
                                                base64ImageData:
                                                    data['imageData'],
                                              ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode(data['imageData']),
                                        width: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else if (isLocation)
                                  GestureDetector(
                                    onTap: () async {
                                      final lat = data['lat'] as double?;
                                      final lng = data['lng'] as double?;
                                      final isLive = data['isLive'] == true;
                                      final peerId = widget.peerId ?? '';
                                      final sharedAt =
                                          data['locationSharedAt']
                                              as Timestamp?;

                                      if (lat == null ||
                                          lng == null ||
                                          sharedAt == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Location data is missing.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final now = DateTime.now();
                                      final diff = now.difference(
                                        sharedAt.toDate(),
                                      );

                                      if (diff.inHours >= 8) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'This location has expired.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (isLive) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => GoogleMapScreen(
                                                  isSharedLocationViewOnly:
                                                      true,
                                                  sharedLat: lat,
                                                  sharedLng: lng,
                                                  chatId: chatId,
                                                  receiverId: peerId,
                                                ),
                                          ),
                                        );
                                      } else {
                                        final googleMapsUrl = Uri.parse(
                                          "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                                        );
                                        if (await canLaunchUrl(googleMapsUrl)) {
                                          await launchUrl(
                                            googleMapsUrl,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not open Google Maps',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlue[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            data['isLive'] == true
                                                ? 'Live Location'
                                                : 'Shared Location',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    data['message'] ?? '',
                                    style: const TextStyle(fontSize: 15),
                                  ),

                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (isMe) tickIcon,
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              /// Typing area
              if (!isBlocked)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 10,
                    left: 10,
                    bottom: 15,
                  ),
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
                              IconButton(
                                icon: const Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: Colors.white70,
                                ),
                                onPressed: () {},
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 5,
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
                                onPressed:
                                    () => _showAttachmentBottomSheet(context),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.currency_rupee,
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
                                            (_) => ImagePreviewPage(
                                              imageFile: image,
                                            ),
                                      ),
                                    );

                                    if (selected != null) {
                                      _sendImageMessage(
                                        selected,
                                      ); // base64 convert & send
                                    }
                                  }
                                },

                                //camera page ne navigate karavo
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          if (_messageController.text.trim().isEmpty) {
                            // Mic logic here
                          } else {
                            sendMessage();
                          }
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            _messageController.text.trim().isEmpty
                                ? Icons.mic
                                : Icons.send,
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
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      final chatId = getChatId(widget.currentUserId, widget.peerId);
      final chatRef = FirebaseFirestore.instance
          .collection('messages')
          .doc(chatId)
          .collection('chats');

      final messagesSnapshot = await chatRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final senderChatRef = FirebaseFirestore.instance
          .collection('chatList')
          .doc(widget.currentUserId)
          .collection('chats')
          .doc(widget.peerId);
      batch.delete(senderChatRef);

      await batch.commit();
      Navigator.of(context).pop();
      Fluttertoast.showToast(msg: 'Chat cleared');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error clearing chat: $e');
    }
  }

  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        selectedImages.add(File(picked.path));
      });
    }
  }

  Future<void> pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        selectedImages.add(File(picked.path));
      });
    }
  }

  Future<void> _updateChatList(String lastMessage, FieldValue timestamp) async {
    await _firestore
        .collection('chatList')
        .doc(widget.currentUserId)
        .collection('chats')
        .doc(widget.peerId)
        .set({
          'peerId': widget.peerId,
          'peerName': widget.peerName,
          'peerMobile': widget.PeerMobile,
          'lastMessage': lastMessage,
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
      'lastMessage': lastMessage,
      'timestamp': timestamp,
      'unreadCount': unreadCount,
    });
  }

  Future<void> _sendImageMessage(File imageFile) async {
    try {
      //  Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 640,
        minHeight: 640,
        quality: 50, // adjust if needed
      );

      if (compressedBytes == null) {
        Fluttertoast.showToast(msg: "Image compression failed");
        return;
      }

      //  Encode to base64
      final base64Image = base64Encode(compressedBytes);

      // Optional: print length (Firestore doc must be <1MB)
      print("Base64 size = ${base64Image.length} chars");

      final chatId = getChatId(widget.currentUserId, widget.peerId);
      final timestamp = FieldValue.serverTimestamp();

      final messageData = {
        'senderId': widget.currentUserId,
        'receiverId': widget.peerId,
        'imageData': base64Image,
        'type': 'image',
        'timestamp': timestamp,
        'isRead': false,
        'senderName': currentUserName,
        'receiverName': widget.peerName,
        'locationSharedAt': FieldValue.serverTimestamp(),
      };

      // /messages/chatId/chats
      await _firestore
          .collection('messages')
          .doc(chatId)
          .collection('chats')
          .add(messageData);

      //  Update chatList (sender)
      await _firestore
          .collection('chatList')
          .doc(widget.currentUserId)
          .collection('chats')
          .doc(widget.peerId)
          .set({
            'peerId': widget.peerId,
            'peerName': widget.peerName,
            'peerMobile': widget.PeerMobile,
            'lastMessage': '[Image]',
            'type': 'image',
            'imageData': base64Image,
            'timestamp': timestamp,
            'unreadCount': 0,
          });

      // Update chatList (receiver)
      final receiverRef = _firestore
          .collection('chatList')
          .doc(widget.peerId)
          .collection('chats')
          .doc(widget.currentUserId);
      final snapshot = await receiverRef.get();
      int unreadCount = 1;
      if (snapshot.exists) {
        unreadCount = (snapshot['unreadCount'] ?? 0) + 1;
      }

      await receiverRef.set({
        'peerId': widget.currentUserId,
        'peerName': currentUserName,
        'peerMobile': currentUserMobile,
        'lastMessage': '[Image]',
        'type': 'image',
        'imageData': base64Image,
        'timestamp': timestamp,
        'unreadCount': unreadCount,
      });

      Fluttertoast.showToast(msg: "Image sent successfully");
    } catch (e, stack) {
      print("Error sending image message: $e");
      print(stack);
      Fluttertoast.showToast(msg: "Failed to send image");
    }
  }
}

class ImagePreviewPage2 extends StatefulWidget {
  final String base64ImageData;

  const ImagePreviewPage2({Key? key, required this.base64ImageData})
    : super(key: key);

  @override
  State<ImagePreviewPage2> createState() => _ImagePreviewPage2State();
}

class _ImagePreviewPage2State extends State<ImagePreviewPage2> {
  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(widget.base64ImageData);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: ClipOval(
              child: Material(
                color: Colors.black54,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // (Removed the download button logic)
        ],
      ),
    );
  }
}
