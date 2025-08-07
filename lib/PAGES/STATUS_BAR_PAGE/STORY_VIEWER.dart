import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StatusViewerPage extends StatefulWidget {
  final String uploaderId;
  final Map<String, String>? phoneToNameMap;
  final String? uploaderPhone;

  const StatusViewerPage({
    Key? key,
    required this.uploaderId,
    this.phoneToNameMap,
    this.uploaderPhone,
  }) : super(key: key);

  @override
  State<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends State<StatusViewerPage> {
  List<Map<String, dynamic>> statuses = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool showViews = false;
  Timer? _timer;
  double progress = 0.0;
  bool isMyStatus = false;
  String? uploaderName;
  Map<String, String> uidToPhoneMap = {};

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    final snap =
        await FirebaseFirestore.instance
            .collection('whatsappstatus')
            .doc(widget.uploaderId)
            .collection('statuses')
            .orderBy('timestamp')
            .get();

    final now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser!;
    isMyStatus = widget.uploaderId == user.uid;

    // Set uploader name from passed contact map
    if (widget.phoneToNameMap != null && widget.uploaderPhone != null) {
      final phone = widget.uploaderPhone!.replaceAll(RegExp(r'\D'), '');
      if (phone.length >= 10) {
        final last10 = phone.substring(phone.length - 10);
        uploaderName = widget.phoneToNameMap![last10];
      }
    }

    List<Map<String, dynamic>> list = [];

    for (var doc in snap.docs) {
      final ts = doc['timestamp'];
      if (now.difference(DateTime.fromMillisecondsSinceEpoch(ts)).inHours >= 24)
        continue;

      final base64Img = doc['image'];
      final decoded = base64Decode(base64Img);
      final compressed = await FlutterImageCompress.compressWithList(
        decoded,
        quality: 50,
      );

      list.add({
        'id': doc.id,
        'image': compressed ?? decoded,
        'views': List<String>.from(doc['views'] ?? []),
        'timestamp': ts,
      });
    }

    if (list.isNotEmpty) {
      // Fetch phone numbers for all viewers
      final allViewers = list.expand((s) => s['views']).toSet();
      for (final uid in allViewers) {
        if (!uidToPhoneMap.containsKey(uid)) {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('client')
                  .doc(uid)
                  .get();
          final phone = userDoc.data()?['mobile']?.replaceAll(
            RegExp(r'\D'),
            '',
          );
          if (phone != null && phone.length >= 10) {
            final last10 = phone.substring(phone.length - 10);
            uidToPhoneMap[uid] = last10;
          }
        }
      }

      setState(() {
        statuses = list;
        isLoading = false;
      });
      _markViewed(list[0]);
      _startTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _startTimer() {
    progress = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      setState(() {
        progress += 0.01;
        if (progress >= 1.0) {
          _nextStatus();
        }
      });
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _startTimer();
  }

  Future<void> _markViewed(Map<String, dynamic> status) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final views = status['views'];
    if (!views.contains(userId)) {
      views.add(userId);
      await FirebaseFirestore.instance
          .collection('whatsappstatus')
          .doc(widget.uploaderId)
          .collection('statuses')
          .doc(status['id'])
          .update({'views': views});
    }
  }

  void _nextStatus() {
    if (currentIndex + 1 < statuses.length) {
      setState(() {
        currentIndex++;
        progress = 0.0;
        showViews = false;
      });
      _markViewed(statuses[currentIndex]);
      _resetTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  void _previousStatus() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        progress = 0.0;
        showViews = false;
      });
      _markViewed(statuses[currentIndex]);
      _resetTimer();
    }
  }

  void _deleteCurrentStatus() async {
    final id = statuses[currentIndex]['id'];
    await FirebaseFirestore.instance
        .collection('whatsappstatus')
        .doc(widget.uploaderId)
        .collection('statuses')
        .doc(id)
        .delete();

    setState(() {
      statuses.removeAt(currentIndex);
      currentIndex = currentIndex > 0 ? currentIndex - 1 : 0;
      showViews = false;
    });

    if (statuses.isEmpty) {
      Navigator.pop(context);
    } else {
      _startTimer();
    }
  }

  String _getTimeAgo(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String _getViewerDisplayName(String uid) {
    final phone = uidToPhoneMap[uid];
    if (phone != null &&
        widget.phoneToNameMap != null &&
        widget.phoneToNameMap!.containsKey(phone)) {
      return widget.phoneToNameMap![phone]!;
    }
    return phone ?? uid;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || statuses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = statuses[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < -10 && isMyStatus) {
            setState(() => showViews = true);
          } else if (details.delta.dy > 10) {
            setState(() => showViews = false);
          }
        },
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.globalPosition.dx;
          if (dx < width / 2) {
            _previousStatus();
          } else {
            _nextStatus();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.memory(
                status['image'] as Uint8List,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(statuses.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            index < currentIndex
                                ? Colors.white
                                : index == currentIndex
                                ? Colors.white.withOpacity(progress)
                                : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 50,
              left: 16,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMyStatus ? "You" : (uploaderName ?? "Status"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getTimeAgo(status['timestamp']),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isMyStatus)
              Positioned(
                bottom: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                  onPressed: _deleteCurrentStatus,
                ),
              ),
            if (showViews)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Viewed by",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: status['views'].length,
                          itemBuilder: (context, index) {
                            final uid = status['views'][index];
                            final name = _getViewerDisplayName(uid);
                            return ListTile(
                              leading: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
