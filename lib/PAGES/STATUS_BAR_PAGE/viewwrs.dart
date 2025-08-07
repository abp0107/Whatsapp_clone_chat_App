import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatusViewerPage extends StatefulWidget {
  final String uploaderId;
  final List<Map<String, dynamic>>
  statuses; // List of status maps (image, timestamp, phone)
  final String fullName;
  final String profileBase64;

  const StatusViewerPage({
    super.key,
    required this.uploaderId,
    required this.statuses,
    required this.fullName,
    required this.profileBase64,
  });

  @override
  State<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends State<StatusViewerPage> {
  int currentIndex = 0;
  Timer? _timer;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    _startStatusTimer();
  }

  void _startStatusTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _nextStatus);
  }

  void _nextStatus() {
    if (currentIndex < widget.statuses.length - 1) {
      setState(() {
        currentIndex++;
      });
      _startStatusTimer();
    } else {
      Navigator.pop(context); // Exit viewer after last status
    }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => isPaused = true);
    _timer?.cancel();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => isPaused = false);
    _startStatusTimer();
  }

  void _onTap() {
    _nextStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildProgressBars() {
    return Row(
      children:
          widget.statuses.asMap().entries.map((entry) {
            int idx = entry.key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: LinearProgressIndicator(
                  value:
                      idx < currentIndex
                          ? 1
                          : idx == currentIndex
                          ? isPaused
                              ? null
                              : 1
                          : 0,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.statuses[currentIndex];
    final Uint8List imageBytes = base64Decode(currentStatus['image']);
    final timestamp = currentStatus['timestamp'];
    final time =
        timestamp != null ? DateFormat('jm').format(timestamp.toDate()) : '';

    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onVerticalDragEnd: (_) => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: Image.memory(imageBytes, fit: BoxFit.cover)),
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBars(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: MemoryImage(
                            base64Decode(widget.profileBase64),
                          ),
                          radius: 22,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              time,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
