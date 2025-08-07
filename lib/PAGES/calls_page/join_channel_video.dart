import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class JoinChannelVideo extends StatefulWidget {
  final String peerName;
  final String peerPhone;

  const JoinChannelVideo({
    Key? key,
    required this.peerName,
    required this.peerPhone,
  }) : super(key: key);

  @override
  State<JoinChannelVideo> createState() => _JoinChannelVideoState();
}

class _JoinChannelVideoState extends State<JoinChannelVideo> {
  late final RtcEngine _engine;

  final String appId = "e88c979e392f42d284dc07aed8b1f315";
  final String token =
      "007eJxTYPg48f8Wq2mlTwNP/st7NrHd427UuYm/SpLcwzzf35nVxb5LgSHVwiLZ0twy1djSKM3EKMXIwiQl2cA8MTXFIskwzdjQdO7VlIyGQEYGt0BmZkYGCATxWRkyUnNy8hkYAJ5XItg=";
  final String channelId = "hello";

  bool _engineReady = false;
  bool isJoined = false;
  Set<int> remoteUids = {};
  bool muteLocalAudio = false;

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
            'receiverName': widget.peerName,
            'receiverPhone': widget.peerPhone,
            'channelId': channelId,
            'type': 'video',
            'startTime': FieldValue.serverTimestamp(),
            'status': 'ongoing',
          });

          _callDocId = doc.id;
          _startTime = DateTime.now();
        },
        onUserJoined: (connection, uid, elapsed) {
          setState(() => remoteUids.add(uid));
        },
        onUserOffline: (connection, uid, reason) {
          setState(() => remoteUids.remove(uid));
        },
        onLeaveChannel: (connection, stats) {
          setState(() {
            isJoined = false;
            remoteUids.clear();
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

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Widget _buildLocalView() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _buildRemoteView(int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();

    if (_callDocId != null) {
      final endTime = DateTime.now();
      final duration =
          _startTime != null ? endTime.difference(_startTime!).inSeconds : 0;

      await FirebaseFirestore.instance
          .collection("calls")
          .doc(_callDocId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'duration': duration,
            'status': 'ended',
          });
    }

    Navigator.pop(context);
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

          // 🧑‍💻 Remote view as small overlay
          if (remoteUids.isNotEmpty)
            Positioned(
              top: 80,
              right: 20,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildRemoteView(remoteUids.first),
              ),
            ),

          // 👤 Receiver name and status at top center
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Text(
                      widget.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      remoteUids.isEmpty ? "Ringing..." : "Connected",
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

          // 🔘 Bottom controls
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
            radius: 28,
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

class BasicVideoConfigurationWidget extends StatefulWidget {
  const BasicVideoConfigurationWidget({
    Key? key,
    required this.rtcEngine,
    required this.setConfigButtonText,
    required this.title,
    this.width = 960,
    this.height = 540,
    this.frameRate = 15,
    this.bitrate = 0,
    this.onConfigChanged,
  }) : super(key: key);

  final RtcEngine rtcEngine;

  final String title;
  final int width;
  final int height;
  final int frameRate;
  final int bitrate;

  final Widget setConfigButtonText;
  final Function(int width, int height, int frameRate, int bitrate)?
  onConfigChanged;

  @override
  State<BasicVideoConfigurationWidget> createState() =>
      _BasicVideoConfigurationWidgetState();
}

class _BasicVideoConfigurationWidgetState
    extends State<BasicVideoConfigurationWidget> {
  late TextEditingController _heightController;
  late TextEditingController _widthController;
  late TextEditingController _frameRateController;
  late TextEditingController _bitrateController;

  @override
  void initState() {
    super.initState();

    _widthController = TextEditingController(text: widget.width.toString());
    _heightController = TextEditingController(text: widget.height.toString());
    _frameRateController = TextEditingController(
      text: widget.frameRate.toString(),
    );
    _bitrateController = TextEditingController(text: widget.bitrate.toString());
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    _widthController.dispose();
    _heightController.dispose();
    _frameRateController.dispose();
    _bitrateController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: const BorderRadius.all(Radius.circular(4.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('width: '),
                    TextField(
                      controller: _widthController,
                      decoration: const InputDecoration(
                        hintText: 'width',
                        border: OutlineInputBorder(gapPadding: 0.0),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('heigth: '),
                    TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        hintText: 'height',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('frame rate: '),
                    TextField(
                      controller: _frameRateController,
                      decoration: const InputDecoration(
                        hintText: 'frame rate',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('bitrate: '),
                    TextField(
                      controller: _bitrateController,
                      decoration: const InputDecoration(
                        hintText: 'bitrate',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            child: widget.setConfigButtonText,
            onPressed: () {
              widget.onConfigChanged?.call(
                int.parse(_widthController.text),
                int.parse(_heightController.text),
                int.parse(_frameRateController.text),
                int.parse(_bitrateController.text),
              );
            },
          ),
        ],
      ),
    );
  }
}

typedef ExampleActionsBuilder =
    Widget Function(BuildContext context, bool isLayoutHorizontal);

class ExampleActionsWidget extends StatelessWidget {
  const ExampleActionsWidget({
    Key? key,
    required this.displayContentBuilder,
    this.actionsBuilder,
  }) : super(key: key);

  final ExampleActionsBuilder displayContentBuilder;

  final ExampleActionsBuilder? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final mediaData = MediaQuery.of(context);
    final bool isLayoutHorizontal =
        mediaData.size.aspectRatio >= 1.5 ||
        (kIsWeb ||
            !(defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS));

    if (actionsBuilder == null) {
      return displayContentBuilder(context, isLayoutHorizontal);
    }

    const actionsTitle = Text(
      'Actions',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
    );

    if (isLayoutHorizontal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    actionsTitle,
                    actionsBuilder!(context, isLayoutHorizontal),
                  ],
                ),
              ),
            ),
          ),
          Container(color: Colors.grey.shade100, width: 20),
          Expanded(
            flex: 2,
            child: displayContentBuilder(context, isLayoutHorizontal),
          ),
        ],
      );
    }

    return Stack(
      children: [
        SizedBox.expand(
          child: Container(
            padding: const EdgeInsets.only(bottom: 150),
            child: displayContentBuilder(context, isLayoutHorizontal),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.25,
          snap: true,
          maxChildSize: 0.7,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 253, 253, 253),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
                boxShadow: [BoxShadow(blurRadius: 20.0, color: Colors.grey)],
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    actionsTitle,
                    actionsBuilder!(context, isLayoutHorizontal),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class StatsMonitoringWidget extends StatelessWidget {
  const StatsMonitoringWidget({
    Key? key,
    required this.rtcEngine,
    required this.uid,
    this.channelId,
    required this.child,
  }) : super(key: key);

  final RtcEngine rtcEngine;

  final int uid;

  final String? channelId;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 0,
          left: 0,
          child: _StatsMonitoringInternalWidget(
            rtcEngine: rtcEngine,
            uid: uid,
            channelId: "hello",
          ),
        ),
      ],
    );
  }
}

class _StatsMonitoringInternalWidget extends StatefulWidget {
  const _StatsMonitoringInternalWidget({
    Key? key,
    required this.rtcEngine,
    required this.uid,
    this.channelId,
  }) : super(key: key);

  final RtcEngine rtcEngine;

  final int uid;

  final String? channelId;

  @override
  State<_StatsMonitoringInternalWidget> createState() =>
      __StatsMonitoringInternalWidgetState();
}

class __StatsMonitoringInternalWidgetState
    extends State<_StatsMonitoringInternalWidget> {
  late final RtcEngineEventHandler _eventHandler;

  RtcStats? _rtcStats;
  LocalAudioStats? _localAudioStats;
  LocalVideoStats? _localVideoStats;
  RemoteAudioStats? _remoteAudioStats;
  RemoteVideoStats? _remoteVideoStats;
  int _volume = 0;

  @override
  void initState() {
    super.initState();

    _init();
  }

  void _init() {
    _eventHandler = RtcEngineEventHandler(
      onRtcStats: (connection, stats) {
        setState(() {
          _rtcStats = stats;
        });
      },
      onLocalAudioStats: (connection, stats) {
        setState(() {
          _localAudioStats = stats;
        });
      },
      onLocalVideoStats: (connection, stats) {
        setState(() {
          _localVideoStats = stats;
        });
      },
      onRemoteAudioStats: (connection, stats) {
        setState(() {
          _remoteAudioStats = stats;
        });
      },
      onRemoteVideoStats: (connection, stats) {
        setState(() {
          _remoteVideoStats = stats;
        });
      },
      onAudioVolumeIndication: (
        connection,
        speakers,
        speakerNumber,
        totalVolume,
      ) {
        final volume =
            speakers.firstWhereOrNull((e) => e.uid == widget.uid)?.volume ?? 0;
        if (volume != 0) {
          setState(() {
            _volume = volume;
          });
        }
      },
    );
    widget.rtcEngine.registerEventHandler(_eventHandler);
    widget.rtcEngine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: false,
    );
  }

  @override
  void dispose() {
    widget.rtcEngine.unregisterEventHandler(_eventHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = widget.channelId;
    final isRemote = isLocal;

    final width =
        (isLocal != null
            ? _localVideoStats?.captureFrameWidth
            : _remoteVideoStats?.width) ??
        0;
    final height =
        (isLocal != null
            ? _localVideoStats?.captureFrameHeight
            : _remoteVideoStats?.height) ??
        0;
    final fps =
        (isLocal != null
            ? _remoteVideoStats?.decoderOutputFrameRate
            : _localVideoStats?.captureFrameRate) ??
        0;
    final lastmileDelay = _rtcStats?.lastmileDelay ?? 0;

    final videoSentBitrate = _localVideoStats?.sentBitrate ?? 0;
    final _audioSentBitrate = _localAudioStats?.sentBitrate ?? 0;
    final cpuTotalUsage = _rtcStats?.cpuTotalUsage ?? 0.0;
    final cpuAppUsage = _rtcStats?.cpuAppUsage ?? 0.0;
    final txPacketLossRate = _rtcStats?.txPacketLossRate ?? 0;

    final videoReceivedBitrate = _remoteVideoStats?.receivedBitrate ?? 0;
    final audioReceivedBitrate = _remoteAudioStats?.receivedBitrate ?? 0;
    final packetLossRate = _remoteVideoStats?.packetLossRate ?? 0;
    final audioLossRate = _remoteAudioStats?.audioLossRate ?? 0;
    final quality =
        _remoteAudioStats?.quality != null
            ? QualityTypeExt.fromValue(_remoteAudioStats!.quality!)
            : QualityType.qualityUnknown;

    const style = TextStyle(color: Colors.white, fontSize: 10);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$width x $height, $fps fps', style: style),
        Text('LM Delay: ${lastmileDelay}ms', style: style),
        Text('Volume: $_volume', style: style),
        if (isLocal != null) ...[
          Text('VSend: ${videoSentBitrate}kbps', style: style),
          Text('ASend: ${_audioSentBitrate}kbps', style: style),
          Text('CPU: $cpuAppUsage% | $cpuTotalUsage%', style: style),
          Text('Send Loss: $txPacketLossRate%', style: style),
        ],
        if (isRemote != null) ...[
          Text('VRecv: ${videoReceivedBitrate}kbps', style: style),
          Text('ARecv: ${audioReceivedBitrate}kbps', style: style),
          Text('VLoss: $packetLossRate%', style: style),
          Text('ALoss: $audioLossRate%', style: style),
          Text(
            'AQuality: ${quality.toString().replaceFirst('QualityType.', '')}',
            style: style,
          ),
        ],
      ],
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final item in this) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
