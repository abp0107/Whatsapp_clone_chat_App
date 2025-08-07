import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../chats/Chat_page.dart';

class JoinChannelAudio extends StatefulWidget {
  final String currentUserId;
  final String peerId;
  final String peerName;
  final String peerPhone;

  const JoinChannelAudio({
    Key? key,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.peerPhone,
  }) : super(key: key);

  @override
  State<JoinChannelAudio> createState() => _JoinChannelAudioState();
}

class _JoinChannelAudioState extends State<JoinChannelAudio> {
  late final RtcEngine _engine;
  final String channelId = "hello";
  bool isJoined = false;
  bool remoteUserJoined = false;
  bool muteMicrophone = false;
  bool enableSpeakerphone = true;

  Timer? _timer;
  int _seconds = 0;

  Uint8List? peerProfileImage;
  Uint8List? callerProfileImage;

  @override
  void initState() {
    super.initState();
    _initEngine().then((_) => _joinChannel());
    _loadProfileImages();
  }

  Future<void> _loadProfileImages() async {
    try {
      final peerDoc =
          await FirebaseFirestore.instance
              .collection("client")
              .doc(widget.peerId)
              .get();
      final callerDoc =
          await FirebaseFirestore.instance
              .collection("client")
              .doc(widget.currentUserId)
              .get();

      if (peerDoc.exists) {
        final base64 = peerDoc['profile_photo_base64'] ?? "";
        if (base64.isNotEmpty) peerProfileImage = base64Decode(base64);
      }

      if (callerDoc.exists) {
        final base64 = callerDoc['profile_photo_base64'] ?? "";
        if (base64.isNotEmpty) callerProfileImage = base64Decode(base64);
      }

      setState(() {});
    } catch (e) {
      print("Error loading profile images: $e");
    }
  }

  String get callStatusText {
    if (!remoteUserJoined) return "Ringing...";
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _leaveChannel();
    super.dispose();
  }

  Future<void> _initEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(appId: "e88c979e392f42d284dc07aed8b1f315"),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => isJoined = true);
          if (remoteUserJoined) _startTimer();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => remoteUserJoined = true);
          if (isJoined) _startTimer();
        },
        onUserOffline: (_, __, ___) {
          setState(() => remoteUserJoined = false);
          _stopTimer();
        },
        onLeaveChannel: (_, __) {
          setState(() => isJoined = false);
          _stopTimer();
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
  }

  Future<void> _joinChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.microphone.request();
    }

    await _engine.joinChannel(
      token:
          "007eJxTYPg48f8Wq2mlTwNP/st7NrHd427UuYm/SpLcwzzf35nVxb5LgSHVwiLZ0twy1djSKM3EKMXIwiQl2cA8MTXFIskwzdjQdO7VlIyGQEYGt0BmZkYGCATxWRkyUnNy8hkYAJ5XItg=",
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection("calls").add({
      'callerId': user?.uid ?? "unknown",
      'callerPhone': user?.phoneNumber ?? "unknown",
      'callerName': widget.peerName,
      'receiverPhone': widget.peerPhone,
      'receiverName': widget.peerName,
      'channelId': channelId,
      'startTime': FieldValue.serverTimestamp(),
      'type': 'voice',
      'status': 'ongoing',
    });
  }

  Future<void> _leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _seconds = 0);
  }

  void _toggleMute() async {
    await _engine.muteLocalAudioStream(!muteMicrophone);
    setState(() => muteMicrophone = !muteMicrophone);
  }

  void _toggleSpeaker() async {
    await _engine.setEnableSpeakerphone(!enableSpeakerphone);
    setState(() => enableSpeakerphone = !enableSpeakerphone);
  }

  void _endCall() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
      final query =
          await FirebaseFirestore.instance
              .collection("calls")
              .where('callerId', isEqualTo: userId)
              .where('channelId', isEqualTo: channelId)
              .where('type', isEqualTo: 'voice')
              .where('status', isEqualTo: 'ongoing')
              .orderBy('startTime', descending: true)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'endTime': FieldValue.serverTimestamp(),
          'status': 'ended',
          'duration': _seconds,
        });
      }

      await _leaveChannel();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(
                currentUserId: widget.currentUserId,
                peerId: widget.peerId,
                peerName: widget.peerName,
                PeerMobile: widget.peerPhone,
                contacts: [],
              ),
        ),
      );
    } catch (e) {
      print("Error ending call: $e");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/Images/voice-cal.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          callerProfileImage != null
                              ? MemoryImage(callerProfileImage!)
                              : const AssetImage("assets/Images/myavator.png")
                                  as ImageProvider,
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.double_arrow, color: Colors.white),
                    const SizedBox(width: 20),
                    CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          peerProfileImage != null
                              ? MemoryImage(peerProfileImage!)
                              : const AssetImage("assets/Images/peeravator.png")
                                  as ImageProvider,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "In Call with",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  callStatusText,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const Spacer(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        child: SizedBox(
          height: 125,
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.only(left: 30, right: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          enableSpeakerphone
                              ? Colors.greenAccent
                              : Colors.transparent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: _toggleSpeaker,
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          muteMicrophone
                              ? Colors.redAccent
                              : Colors.transparent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: _toggleMute,
                    child: Icon(
                      muteMicrophone ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.red,
          onPressed: _endCall,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.call_end, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
