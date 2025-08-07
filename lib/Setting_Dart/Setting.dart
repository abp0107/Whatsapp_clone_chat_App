import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../LoginPages/editprofile page.dart';
import '../LoginPages/phone_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required Map<String, dynamic> client});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? userData;
  String? userUID;
  bool isLoading = true;
  final user = FirebaseAuth.instance.currentUser;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final doc =
          await FirebaseFirestore.instance.collection('client').doc(uid).get();

      if (doc.exists) {
        setState(() {
          userUID = uid;
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _logoutUser() async {
    await FirebaseAuth.instance.signOut();
    Get.snackbar(
      "Success",
      "Logged out successfully",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    Get.offAll(() => const PhoneInputPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF4267B2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : userData == null
              ? const Center(
                child: Text(
                  'Failed to load user data.',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            userData!['profile_photo_base64'] != null &&
                                    userData!['profile_photo_base64'] != ''
                                ? MemoryImage(
                                  base64Decode(
                                    userData!['profile_photo_base64'],
                                  ),
                                )
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${userData!['first_name']} ${userData!['last_name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'edit_profile') {
                                      // Placeholder: You can replace with actual EditProfilePage
                                      Get.to(
                                        EditProfilePage(
                                          docId: userUID!,
                                          userData: userData!,
                                        ),
                                      );
                                    } else if (value == 'logout') {
                                      _logoutUser();
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(
                                          value: 'edit_profile',
                                          child: Text('Edit Profile'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'logout',
                                          child: Text('Log Out'),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userData!['status'] ??
                                  'Hey there! I am using the app.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'UID: $userUID',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white30),
                  _settingItem(Icons.lock, "Privacy"),
                  _settingItem(Icons.person, "Avatar"),
                  _settingItem(Icons.people, "Lists"),
                  _settingItem(Icons.chat, "Chats"),
                  _settingItem(Icons.notifications, "Notifications"),
                  _settingItem(Icons.data_usage, "Storage and Data"),
                  _settingItem(Icons.language, "App Language"),
                  _settingItem(Icons.help_outline, "Help"),
                  _settingItem(Icons.group_add, "Invite a Friend"),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white30),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: _logoutUser,
                  ),
                ],
              ),
    );
  }

  Widget _settingItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {},
    );
  }
}
