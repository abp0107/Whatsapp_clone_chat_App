import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';

import '../../loadingindicator.dart';

class CallHistoryPage extends StatefulWidget {
  final List<Contact> phoneContacts;

  const CallHistoryPage({super.key, required this.phoneContacts});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  List<Contact> phoneContacts = [];
  String? currentUserId;
  final Map<String, Uint8List?> profileCache = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    phoneContacts = widget.phoneContacts;
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
    }
  }

  String getContactName(String? number) {
    if (number == null || number.isEmpty) return "Unknown";
    final cleaned = number.replaceAll(RegExp(r'\s+|^\+91'), '');
    final match = phoneContacts.firstWhere(
      (c) => c.phones.any(
        (p) => p.number.replaceAll(RegExp(r'\s+|^\+91'), '').contains(cleaned),
      ),
      orElse: () => Contact(),
    );
    return match.displayName.isNotEmpty ? match.displayName : number;
  }

  IconData getCallIcon(String type) {
    return type == 'video' ? Icons.videocam : Icons.call;
  }

  Color getCallColor(String status) {
    return status == 'missed' ? Colors.red : Colors.green;
  }

  Future<Uint8List?> fetchProfileImage(String phone) async {
    if (profileCache.containsKey(phone)) return profileCache[phone];

    try {
      final query =
          await FirebaseFirestore.instance
              .collection('client')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final base64String = data['profile_photo_base64'];
        if (base64String != null &&
            base64String is String &&
            base64String.isNotEmpty) {
          final imageBytes = base64Decode(base64String);
          profileCache[phone] = imageBytes;
          return imageBytes;
        }
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    }

    profileCache[phone] = null;
    return null;
  }

  Widget buildCallTile(Map<String, dynamic> call) {
    final rawPhone = call['receiverPhone'];
    final callerPhone = call['callerPhone'];
    final phone = rawPhone?.toString() ?? '';
    final name = getContactName(phone);
    final type = call['type'] ?? 'voice';
    final time = (call['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final duration = call['duration'] ?? 0;
    final status = call['status'] ?? 'ended';
    final callerId = call['callerId'];

    final isOutgoing = callerId == currentUserId;
    final directionIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    final directionColor = isOutgoing ? Colors.blue : Colors.orange;

    final otherPersonPhone = isOutgoing ? phone : callerPhone;

    return FutureBuilder<Uint8List?>(
      future: fetchProfileImage(otherPersonPhone ?? ""),
      builder: (context, snapshot) {
        final profileImage = snapshot.data;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    profileImage != null ? MemoryImage(profileImage) : null,
                child:
                    profileImage == null
                        ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(directionIcon, size: 18, color: directionColor),
                ],
              ),
              subtitle: Text(
                "${DateFormat.yMMMd().add_jm().format(time)} • ${duration}s",
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Icon(getCallIcon(type), color: getCallColor(status)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4267B2),
        title: const Text(
          'Call History',
          style: TextStyle(color: Colors.white, fontSize: 23),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('calls')
                .where('callerId', isEqualTo: currentUserId)
                .orderBy('startTime', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Firestore error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No call history found.'));
          }

          return LoadingWrapper(
            isLoading: isLoading,
            onRefresh: _refreshData,
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return buildCallTile(data);
              },
            ),
          );
        },
      ),
    );
  }
}
