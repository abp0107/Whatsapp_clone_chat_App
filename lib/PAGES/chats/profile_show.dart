import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../calls_page/Join_Channel_Audio.dart';
import '../calls_page/join_channel_video.dart';

final Color pageBackgroundColor = const Color(0xFF4267B2);

class UserProfilePage extends StatelessWidget {
  final String currentUserId;

  final String peerId;
  final String peerName;
  final String PeerMobile;
  final bool isGroupChat;
  final String userId;
  final String userName;
  final String phoneNumber;
  final String? imageBase64;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    this.imageBase64,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.PeerMobile,
    required this.isGroupChat,
  });

  // Call function: start voice call
  void startVoiceCall(BuildContext context) {
    // Make sure your call page exists and accepts these parameters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => JoinChannelAudio(
              currentUserId: currentUserId,
              peerId: peerId,
              peerName: peerName,
              peerPhone: PeerMobile,
            ),
      ),
    );
  }

  // Call function: start video call
  void startVideoCall(BuildContext context) {
    // Make sure your call page exists and accepts these parameters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => JoinChannelVideo(peerName: peerName, peerPhone: PeerMobile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(userName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('client').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final rawData = snapshot.data!.data();
          if (rawData == null || rawData is! Map<String, dynamic>) {
            return const Center(
              child: Text(
                "User data not found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final String? base64Image = rawData['profile_photo_base64'];
          final String company = rawData['company_name'] ?? '';
          final String address = rawData['address'] ?? '';
          final String city = rawData['city'] ?? '';
          final String state = rawData['state'] ?? '';
          final String zipcode = rawData['zipcode'] ?? '';
          final Timestamp? createdAtTs = rawData['createdAt'];
          final String createdAt =
              createdAtTs != null
                  ? "${createdAtTs.toDate().day}-${createdAtTs.toDate().month}-${createdAtTs.toDate().year}"
                  : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      base64Image != null
                          ? MemoryImage(base64Decode(base64Image))
                          : null,
                  backgroundColor: Colors.white24,
                  child:
                      base64Image == null
                          ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                          : null,
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phoneNumber,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 20),

                /// Action Row with Call Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.call,
                      label: 'Audio',
                      onPressed: () => startVoiceCall(context),
                    ),
                    _ActionButton(
                      icon: Icons.videocam,
                      label: 'Video',
                      onPressed: () => startVideoCall(context),
                    ),
                    _ActionButton(
                      icon: Icons.payment,
                      label: 'Pay',
                      onPressed: () {
                        // Optional payment logic
                      },
                    ),
                    _ActionButton(
                      icon: Icons.search,
                      label: 'Search',
                      onPressed: () {
                        // Open media/search page
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: Colors.white30),

                _InfoSection(
                  icon: Icons.business,
                  title: company.isNotEmpty ? company : "No company info",
                  subtitle: createdAt,
                ),
                const SizedBox(height: 10),

                _MediaPreviewSection(userId: userId),
                const SizedBox(height: 10),

                const _InfoSection(
                  icon: Icons.notifications,
                  title: 'Notifications',
                ),
                const _InfoSection(
                  icon: Icons.image,
                  title: 'Media visibility',
                ),
                const _InfoSection(icon: Icons.star, title: 'Starred messages'),
                const _InfoSection(
                  icon: Icons.lock,
                  title: 'Encryption',
                  subtitle: 'Messages are end-to-end encrypted.',
                ),
                const _InfoSection(
                  icon: Icons.timer,
                  title: 'Disappearing messages',
                  subtitle: 'Off',
                ),

                const Divider(color: Colors.white30),

                _InfoSection(
                  icon: Icons.location_on,
                  title: 'Address',
                  subtitle: '$address, $city',
                ),
                _InfoSection(icon: Icons.map, title: 'State', subtitle: state),
                _InfoSection(
                  icon: Icons.pin_drop,
                  title: 'Zipcode',
                  subtitle: zipcode,
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Helper widgets remain unchanged
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _InfoSection({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              )
              : null,
    );
  }
}

class _MediaPreviewSection extends StatelessWidget {
  final String userId;

  const _MediaPreviewSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('messages')
              .doc(userId)
              .collection('chats')
              .where('type', isEqualTo: 'image')
              .limit(10)
              .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final images =
            snapshot.data!.docs
                .map(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['imageData']
                          as String?,
                )
                .where((img) => img != null)
                .toList();

        if (images.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                "Media, links and docs",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(images[i]!),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
