import 'dart:convert';
import 'dart:io';

import 'package:TwinBox/loadingindicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';

import 'PREVIEW.dart';
import 'STORY_VIEWER.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  Map<String, String> myContactsMap = {}; // mobile → name
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => isLoading = true);
      await Future.wait([fetchStatuses(), _loadMyContacts()]);
      setState(() => isLoading = false);
    });
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => isLoading = false);
  }

  Future<void> _loadMyContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          if (normalized.length >= 10) {
            final last10 = normalized.substring(normalized.length - 10);
            myContactsMap[last10] = contact.displayName;
          }
        }
      }
      setState(() {});
    }
  }

  Future<List<Map<String, dynamic>>> fetchStatuses() async {
    final user = FirebaseAuth.instance.currentUser!;
    final List<Map<String, dynamic>> allStatuses = [];

    final snapshot =
        await FirebaseFirestore.instance.collection('whatsappstatus').get();

    print("📂 Total users with status: ${snapshot.docs.length}");

    final futures =
        snapshot.docs.map((doc) async {
          final uploaderId = doc.id;
          final statusSnap =
              await doc.reference
                  .collection('statuses')
                  .orderBy('timestamp', descending: true)
                  .get();

          final statuses = statusSnap.docs.map((d) => d.data()).toList();

          if (statuses.isEmpty) {
            print("❌ No statuses for $uploaderId");
            return null;
          }

          final firstStatus = statuses.first;
          final phone = (firstStatus['phone'] ?? "").replaceAll(
            RegExp(r'\D'),
            '',
          );
          final last10 =
              phone.length >= 10 ? phone.substring(phone.length - 10) : phone;

          final contactName =
              uploaderId == user.uid ? "You" : myContactsMap[last10] ?? last10;

          return {
            'uploaderId': uploaderId,
            'phone': last10,
            'contactName': contactName,
            'statuses': statuses,
          };
        }).toList();

    final results = await Future.wait(futures);
    allStatuses.addAll(results.whereType<Map<String, dynamic>>());

    print("✅ Total fetched statuses: ${allStatuses.length}");
    return allStatuses;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusPreviewPage(imageFile: File(image.path)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        title: const Text("Status"),
        backgroundColor: const Color(0xFF4267B2),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _pickImage),
        ],
      ),
      body: LoadingWrapper(
        isLoading: isLoading,
        onRefresh: _refreshData,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchStatuses(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = snapshot.data!;
            final myStatus = all.firstWhere(
              (s) => s['uploaderId'] == currentUser!.uid,
              orElse: () => {},
            );
            final others =
                all.where((s) => s['uploaderId'] != currentUser!.uid).toList();

            return ListView.builder(
              itemCount: others.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildMyStatusTile(myStatus);
                } else if (index == 1 && others.isNotEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      "Recent updates",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                } else {
                  final status = others[index - 2];
                  return _buildOtherStatusTile(status);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyStatusTile(Map<String, dynamic> myStatus) {
    final hasStatus =
        myStatus.isNotEmpty && (myStatus['statuses']?.isNotEmpty ?? false);
    final latestImage =
        hasStatus ? base64Decode(myStatus['statuses'].last['image']) : null;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage:
                hasStatus
                    ? MemoryImage(latestImage!)
                    : const NetworkImage(
                          'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                        )
                        as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              height: 20,
              width: 20,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
      title: Text(
        myStatus['contactName'] ?? "My Status",
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        hasStatus
            ? "${myStatus['statuses'].length} status update${myStatus['statuses'].length > 1 ? 's' : ''}"
            : "Tap to add status",
        style: const TextStyle(color: Colors.white70),
      ),
      onTap: () {
        if (hasStatus) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StatusViewerPage(uploaderId: currentUser!.uid),
            ),
          );
        } else {
          _pickImage();
        }
      },
    );
  }

  Widget _buildOtherStatusTile(Map<String, dynamic> status) {
    final statuses = status['statuses'] ?? [];
    if (statuses.isEmpty) return const SizedBox.shrink();

    final imageBytes = base64Decode(statuses.last['image']);
    final contactName = status['contactName'] ?? status['phone'];

    return ListTile(
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: MemoryImage(imageBytes),
      ),
      title: Text(contactName, style: const TextStyle(color: Colors.white)),
      subtitle: const Text(
        "Tap to view",
        style: TextStyle(color: Colors.white70),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatusViewerPage(uploaderId: status['uploaderId']),
          ),
        );
      },
    );
  }
}
