import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class JoinChannelGroupVideo extends StatefulWidget {
  final String groupName;

  const JoinChannelGroupVideo({Key? key, required this.groupName})
    : super(key: key);

  @override
  State<JoinChannelGroupVideo> createState() => _JoinChannelGroupVideoState();
}

class _JoinChannelGroupVideoState extends State<JoinChannelGroupVideo> {
  late final RtcEngine _engine;

  final String appId = "e88c979e392f42d284dc07aed8b1f315";
  final String token =
      "007eJxTYPg48f8Wq2mlTwNP/st7NrHd427UuYm/SpLcwzzf35nVxb5LgSHVwiLZ0twy1djSKM3EKMXIwiQl2cA8MTXFIskwzdjQdO7VlIyGQEYGt0BmZkYGCATxWRkyUnNy8hkYAJ5XItg=";
  final String channelId = "hello";

  Set<int> remoteUids = {};
  bool _engineReady = false;
  bool isJoined = false;
  bool muteLocalAudio = false;
  Timer? _ringingTimer;
  bool callConnected = false;

  String? _callDocId;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) async {
          setState(() => isJoined = true);
          _startRingingTimer();

          final user = FirebaseAuth.instance.currentUser;
          final uid = user?.uid ?? "unknown";

          final snapshot =
              await FirebaseFirestore.instance
                  .collection('client')
                  .doc(uid)
                  .get();

          final callerName = snapshot.data()?['name'] ?? "Unknown";
          final callerPhone = snapshot.data()?['mobile'] ?? "Unknown";

          final doc = await FirebaseFirestore.instance.collection("calls").add({
            'callerId': uid,
            'callerName': callerName,
            'callerPhone': callerPhone,
            'receiverName': widget.groupName,
            'channelId': channelId,
            'type': 'group_video',
            'startTime': FieldValue.serverTimestamp(),
            'status': 'ongoing',
          });

          _callDocId = doc.id;
          _startTime = DateTime.now();
        },
        onUserJoined: (connection, uid, elapsed) {
          setState(() {
            remoteUids.add(uid);
            callConnected = true;
          });
          _cancelRingingTimer();
        },
        onUserOffline: (connection, uid, reason) {
          setState(() {
            remoteUids.remove(uid);
            if (remoteUids.isEmpty) callConnected = false;
          });
        },
        onLeaveChannel: (connection, stats) {
          setState(() {
            remoteUids.clear();
            isJoined = false;
            callConnected = false;
          });
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    setState(() => _engineReady = true);
  }

  void _startRingingTimer() {
    _ringingTimer = Timer(const Duration(seconds: 15), () {
      if (remoteUids.isEmpty) {
        _endCall();
      }
    });
  }

  void _cancelRingingTimer() {
    _ringingTimer?.cancel();
    _ringingTimer = null;
  }

  @override
  void dispose() {
    _cancelRingingTimer();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Future<void> _endCall() async {
    _cancelRingingTimer();
    await _engine.leaveChannel();

    if (_callDocId != null) {
      final endTime = DateTime.now();
      final duration =
          _startTime != null ? endTime.difference(_startTime!).inSeconds : 0;

      await FirebaseFirestore.instance
          .collection("calls")
          .doc(_callDocId!)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'duration': duration,
            'status': 'ended',
          });
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildLocalView() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  List<Widget> _buildRemoteViews() {
    return remoteUids.map((uid) {
      return Container(
        margin: const EdgeInsets.all(6),
        width: 100,
        height: 140,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: uid),
              connection: RtcConnection(channelId: channelId),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_engineReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildLocalView()),

          if (remoteUids.isNotEmpty)
            Positioned(
              top: 60,
              right: 16,
              child: Column(children: _buildRemoteViews()),
            ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      callConnected ? "Connected" : "Ringing...",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  muteLocalAudio ? Icons.mic_off : Icons.mic,
                  "Mute",
                  () {
                    _engine.muteLocalAudioStream(!muteLocalAudio);
                    setState(() => muteLocalAudio = !muteLocalAudio);
                  },
                ),
                _buildControlButton(
                  Icons.call_end,
                  "End",
                  _endCall,
                  color: Colors.red,
                ),
                _buildControlButton(Icons.flip_camera_ios, "Flip", () {
                  _engine.switchCamera();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.black45,
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
