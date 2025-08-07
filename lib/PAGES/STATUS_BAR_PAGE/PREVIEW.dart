import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // ✅ Added

class StatusPreviewPage extends StatefulWidget {
  final File imageFile;

  const StatusPreviewPage({super.key, required this.imageFile});

  @override
  State<StatusPreviewPage> createState() => _StatusPreviewPageState();
}

class _StatusPreviewPageState extends State<StatusPreviewPage> {
  bool _isUploading = false;

  // ✅ Compress the image before uploading
  Future<String> _compressAndEncode(File file) async {
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 720,
      minHeight: 720,
      quality: 70,
    );
    if (compressedBytes == null) {
      throw Exception("❌ Compression failed");
    }
    return base64Encode(compressedBytes);
  }

  Future<void> _uploadStatus(BuildContext context) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final base64Image = await _compressAndEncode(
        widget.imageFile,
      ); // ✅ compressed
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print("❌ No authenticated user found.");
        throw Exception("User not signed in");
      }

      print(
        "Uploading status for UID: ${user.uid}, phone: ${user.phoneNumber}",
      );

      final docRef = FirebaseFirestore.instance
          .collection('whatsappstatus')
          .doc(user.uid);

      await docRef.set({'exists': true}, SetOptions(merge: true));
      print("✅ Parent document created/merged");

      await docRef.collection('statuses').add({
        "phone": user.phoneNumber ?? "unknown",
        'image': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'views': [],
      });

      print("✅ Status uploaded to Firestore!");
      _showSuccessDialog(context);
    } catch (e, stack) {
      print("❌ Error uploading status: $e");
      print(stack);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to upload status: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text(
                  "Status Uploaded!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your status has been successfully uploaded.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // go back to Status screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      "OK",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Image.file(widget.imageFile, fit: BoxFit.contain)),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () => _uploadStatus(context),
              backgroundColor: Colors.green,
              child:
                  _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
