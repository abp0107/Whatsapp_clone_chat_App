import 'dart:async';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class JoinGroupVoiceCall extends StatefulWidget {
  final String groupName;

  const JoinGroupVoiceCall({super.key, required this.groupName});

  @override
  State<JoinGroupVoiceCall> createState() => _JoinGroupVoiceCallState();
}

class _JoinGroupVoiceCallState extends State<JoinGroupVoiceCall> {
  late final RtcEngine _engine;
  bool isJoined = false;
  Map<int, Map<String, dynamic>> connectedUsers = {}; // uid: {name, photoUrl}
  bool muteMicrophone = false;
  bool enableSpeakerphone = true;

  Timer? _timer;
  Timer? _ringingTimeout;
  int _seconds = 0;

  String get callStatusText {
    if (connectedUsers.isEmpty) return "Ringing...";
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _initEngine().then((_) => _joinChannel());
    _startRingingTimeout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringingTimeout?.cancel();
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
        },
        onUserJoined: (
          RtcConnection connection,
          int remoteUid,
          int elapsed,
        ) async {
          await _fetchUserInfo(remoteUid);
          _ringingTimeout?.cancel();
          _startTimer();
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          setState(() {
            connectedUsers.remove(remoteUid);
          });
          if (connectedUsers.isEmpty) _stopTimer();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          setState(() {
            isJoined = false;
            connectedUsers.clear();
          });
          _stopTimer();
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
  }

  Future<void> _fetchUserInfo(int uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid.toString())
              .get();
      if (doc.exists) {
        setState(() {
          connectedUsers[uid] = {
            'name': doc['name'] ?? 'Unknown',
            'profileUrl': doc['profileUrl'] ?? '',
          };
        });
      } else {
        // fallback
        connectedUsers[uid] = {'name': 'User $uid', 'profileUrl': ''};
      }
    } catch (e) {
      connectedUsers[uid] = {'name': 'User $uid', 'profileUrl': ''};
    }
  }

  Future<void> _joinChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.microphone.request();
    }

    await _engine.joinChannel(
      token:
          "007eJxTYPg48f8Wq2mlTwNP/st7NrHd427UuYm/SpLcwzzf35nVxb5LgSHVwiLZ0twy1djSKM3EKMXIwiQl2cA8MTXFIskwzdjQdO7VlIyGQEYGt0BmZkYGCATxWRkyUnNy8hkYAJ5XItg=",
      channelId: "hello",
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _seconds = 0);
  }

  void _startRingingTimeout() {
    _ringingTimeout = Timer(const Duration(seconds: 12), () {
      if (connectedUsers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No response. Call ended.")),
        );
        _endCall();
      }
    });
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
    await _leaveChannel();
    Navigator.pop(context);
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isMe) {
    final name = user['name'] ?? 'You';
    final profileUrl = user['profileUrl'] ?? '';
    final bgColor =
        isMe
            ? Colors.grey.shade700
            : Colors
                .primaries[name.hashCode % Colors.primaries.length]
                .shade300;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage:
                profileUrl.isNotEmpty
                    ? NetworkImage(profileUrl)
                    : const AssetImage("assets/Images/default.png")
                        as ImageProvider,
          ),
          const SizedBox(height: 10),
          Text(
            isMe ? 'You' : name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userTiles =
        connectedUsers.entries
            .map((entry) => _buildUserTile(entry.value, false))
            .toList();

    // Add self tile
    userTiles.insert(
      0,
      _buildUserTile({
        'name': 'You',
        'profileUrl': '', // or your own profile URL
      }, true),
    );

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
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
                const SizedBox(height: 50),
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  callStatusText,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    children: userTiles,
                  ),
                ),
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
