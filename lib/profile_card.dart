import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';

import 'Contact_List/Contact_list.dart';
import 'PAGES/STATUS_BAR_PAGE/STORY.dart';
import 'PAGES/calls_page/call_history.dart';
import 'PAGES/chats/Chat_page.dart';
import 'PAGES/group section/Group_chat_page.dart';
import 'Setting_Dart/Setting.dart' show SettingsPage;
import 'loadingindicator.dart';

class ProfileCardPage extends StatefulWidget {
  const ProfileCardPage({Key? key, this.phoneContacts}) : super(key: key);
  final List<Contact>? phoneContacts;
  @override
  @override
  State<ProfileCardPage> createState() => _ProfileCardPageState();
}

class _ProfileCardPageState extends State<ProfileCardPage>
    with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  String getChatId(String currentUserId, String peerId) {
    return currentUserId.hashCode <= peerId.hashCode
        ? '$currentUserId-$peerId'
        : '$peerId-$currentUserId';
  }

  final userPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  int _currentBottomIndex = 0;
  bool isLoading = false;
  List<Contact>? phoneContacts;
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Contact> _contacts = [];

  String _selectedTab = 'All';

  final List<String> tabs = ['All', 'Unread', 'Favourites', 'Groups'];
  final Color pageBackgroundColor = const Color(0xFF4267B2);

  @override
  void initState() {
    super.initState();
    loadPhoneContacts();
    _fetchContacts();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );
    _fabController.forward();

    _pageController.addListener(() {
      int page = _pageController.page?.round() ?? 0;
      if (page != _currentBottomIndex) {
        setState(() {
          _currentBottomIndex = page;
          _selectedTab = tabs[page]; // sync tab with page
        });
      }
    });
  }

  void loadPhoneContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        phoneContacts = contacts;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(
      const Duration(seconds: 2),
    ); // fetch from API/Firestore
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onFabTap() {
    if (_fabController.status == AnimationStatus.completed) {
      _fabController.reverse();
    } else {
      _fabController.forward();
    }
    Get.to(ContactListPage());
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final fetched = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        _contacts = fetched;
      });
    }
  }

  Widget _buildCustomTabBar() {
    final selectedIndex = tabs.indexOf(_selectedTab);
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: pageBackgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = tabs[index];
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white38 : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.6),
                              offset: const Offset(0, 0),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                          : [],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainContent() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentBottomIndex = index;
          _selectedTab = tabs[index]; // sync tab with page swipe
        });
      },
      children: [
        _buildChatMainContent(),

        //STATUS WALU PAGE AHIYA ADD KARAVANU CHE OK
        //  Statusscreen(),STATUS
        StatusScreen(),
        ContactListPage(),

        /// communicartion page ne ahiya navigate karavo
        CallHistoryPage(
          phoneContacts: _contacts,
        ), // call history page ne karayvu che navigate
      ],
    );
  }

  Widget _buildChatMainContent() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_selectedTab == 'Groups') {
      final currentUserPhone = currentUser?.phoneNumber?.replaceAll(' ', '');
      if (currentUserPhone == null) {
        return const Center(
          child: Text(
            'User not logged in',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      return StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('groups')
                .where('members', arrayContains: currentUserPhone)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No groups found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final groupDoc = snapshot.data!.docs[index];
              final groupData = groupDoc.data() as Map<String, dynamic>;
              final groupName = groupData['name'] ?? 'Unnamed Group';
              final base64Image = groupData['groupImageBase64'] ?? '';
              ImageProvider? imageProvider;

              if (base64Image.isNotEmpty) {
                try {
                  imageProvider = MemoryImage(base64Decode(base64Image));
                } catch (_) {}
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => GroupChatScreen(
                            groupId: groupDoc.id,
                            groupName: groupName,
                            contacts: _contacts,
                            currentUserName: currentUser?.displayName ?? 'You',
                            currentUserId: currentUser!.uid,
                          ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: imageProvider,
                        child:
                            imageProvider == null
                                ? const Icon(Icons.group, color: Colors.white)
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          groupName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chatList')
              .doc(currentUser?.uid)
              .collection('chats')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> chatDocs = snapshot.data!.docs;

        // Filter by tab
        if (_selectedTab == 'Unread') {
          chatDocs =
              chatDocs.where((doc) => (doc['unreadCount'] ?? 0) > 0).toList();
        } else if (_selectedTab == 'Read') {
          chatDocs =
              chatDocs.where((doc) => (doc['unreadCount'] ?? 0) == 0).toList();
        }

        if (chatDocs.isEmpty) {
          return const Center(
            child: Text(
              'No chats found.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatData = chatDocs[index].data() as Map<String, dynamic>;
            final peerId = chatData['peerId'];
            final peerName = chatData['peerName'] ?? '';
            final peerMobile = chatData['peerMobile'] ?? '';
            final lastMessage = chatData['lastMessage'] ?? '';
            final unreadCount = chatData['unreadCount'] ?? 0;

            String displayName = peerName;
            if (widget.phoneContacts != null) {
              final matchedContact = widget.phoneContacts!.firstWhereOrNull((
                contact,
              ) {
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
                  final base64Img = clientData['profile_photo_base64'] ?? '';
                  if (base64Img.isNotEmpty) {
                    try {
                      avatar = MemoryImage(base64Decode(base64Img));
                    } catch (_) {}
                  }
                }

                return GestureDetector(
                  onTap: () {
                    Get.to(
                      () => ChatScreen(
                        currentUserId: FirebaseAuth.instance.currentUser!.uid,
                        peerId: peerId, // 👈 should be Firebase UID of peer
                        peerName: displayName,
                        contacts: [],
                        PeerMobile: peerMobile,
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
                                _getFormattedLastMessage(lastMessage),
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (unreadCount > 0)
                          CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 10,
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getFormattedLastMessage(String message) {
    if (message == '[Image]') return '📷 Photo';
    if (message == '[Video]') return '🎥 Video';
    if (message == '[Audio]') return '🎵 Audio';
    if (message == '[File]') return '📎 File';
    if (message == '[Sticker]') return '💬 Sticker';
    return message;
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
      key: _scaffoldKey,
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: LoadingWrapper(
          isLoading: isLoading,
          onRefresh: _refreshData,
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    if (_currentBottomIndex == 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.message_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F2027),
                                      Color(0xFF203A43),
                                      Color(0xFF2C5364),
                                    ],
                                  ).createShader(bounds),
                              child: const Text(
                                "Let's Talk",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              onSelected: (value) async {
                                if (value == 'new_group') {
                                  Get.to(
                                    NewGroupPage(
                                      contacts: _contacts,
                                      currentUserPhone: userPhone,
                                    ),
                                  );
                                } else if (value == 'settings') {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    final userDoc =
                                        await FirebaseFirestore.instance
                                            .collection('client')
                                            .doc(user.uid)
                                            .get();
                                    if (userDoc.exists) {
                                      final userData = userDoc.data()!;
                                      userData['uid'] = user.uid;
                                      Get.to(
                                        () => SettingsPage(client: userData),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder:
                                  (context) => const [
                                    PopupMenuItem(
                                      value: 'new_group',
                                      child: Text('New Group'),
                                    ),
                                    PopupMenuItem(
                                      value: 'settings',
                                      child: Text('Settings'),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                      ),
                      LoadingWrapper(
                        isLoading: isLoading,
                        onRefresh: _refreshData,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: 50,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCustomTabBar(),
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: LoadingWrapper(
                        isLoading: isLoading,
                        onRefresh: _refreshData,
                        child: _buildMainContent(),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                right: 30,
                child: ElevatedButton(
                  onPressed: _onFabTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    elevation: 8,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      "assets/Images/WhatsApp Image 2025-06-11 at 4.53.41 PM.jpeg",
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LoadingWrapper(
        isLoading: isLoading,
        onRefresh: _refreshData,
        child: _buildCustomBottomNavigation(),
      ),
    );
  }

  Widget _buildCustomBottomNavigation() {
    final tabs = ['Chats', "updates", 'Communication', 'Calls'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentBottomIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentBottomIndex = index;
                _pageController.jumpToPage(index);
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blueAccent : Colors.grey[200],
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : [],
                  ),
                  child: Icon(
                    index == 0
                        ? Icons.chat
                        : index == 1
                        ? Icons.tips_and_updates_rounded
                        : index == 2
                        ? Icons.people_alt_sharp
                        : Icons.call,
                    size: 24,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.blueAccent : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Placeholder for your profile content
class ProfileContentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your Profile Content Here',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

Future<void> deleteChat(String currentUserId, String peerId) async {
  final chatId =
      currentUserId.hashCode <= peerId.hashCode
          ? '$currentUserId-$peerId'
          : '$peerId-$currentUserId';

  try {
    // Delete all messages inside the chat
    var messages =
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(chatId)
            .collection('chats')
            .get();

    for (var doc in messages.docs) {
      await doc.reference.delete();
    }

    // Delete from chatList
    await FirebaseFirestore.instance
        .collection('chatList')
        .doc(currentUserId)
        .collection('chats')
        .doc(peerId)
        .delete();

    // Optionally delete from peer's chat list too
    await FirebaseFirestore.instance
        .collection('chatList')
        .doc(peerId)
        .collection('chats')
        .doc(currentUserId)
        .delete();
  } catch (e) {
    print("Error deleting chat: $e");
  }
}
