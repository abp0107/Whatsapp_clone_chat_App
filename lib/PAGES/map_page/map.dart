import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

class GoogleMapScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final bool isSharedLocationViewOnly;
  final double? sharedLat;
  final double? sharedLng;

  GoogleMapScreen({
    Key? key,
    required this.chatId,
    required this.receiverId,
    this.isSharedLocationViewOnly = false,
    this.sharedLat,
    this.sharedLng,
  }) : super(key: key);

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? mapController;
  final Location _location = Location();
  LatLng? _currentLatLng;
  StreamSubscription<LocationData>? _liveLocationSubscription;
  bool _isSharingLiveLocation = false;
  final Set<Marker> _markers = {};
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _initLocationAndPermission();
  }

  Future<void> _initLocationAndPermission() async {
    if (widget.isSharedLocationViewOnly &&
        widget.sharedLat != null &&
        widget.sharedLng != null) {
      _currentLatLng = LatLng(widget.sharedLat!, widget.sharedLng!);
      _updateMarker(_currentLatLng!, 'shared', 'Shared Location');
      setState(() {});
      return;
    }

    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) return;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    final locationData = await _location.getLocation();
    if (locationData.latitude == null || locationData.longitude == null) return;

    _currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);
    _updateMarker(_currentLatLng!, 'current', 'You are here');

    if (_mapReady && mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
    }

    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _mapReady = true;

    if (_currentLatLng != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
    }
  }

  void _updateMarker(LatLng latLng, String id, String title) {
    _markers.removeWhere((m) => m.markerId.value == id);
    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: latLng,
        infoWindow: InfoWindow(title: title),
        icon:
            id == 'live'
                ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                )
                : BitmapDescriptor.defaultMarker,
      ),
    );
  }

  void _sendCurrentLocation() async {
    if (_currentLatLng != null) {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.chatId)
          .collection('chats')
          .add({
            'type': 'location',
            'lat': _currentLatLng!.latitude,
            'lng': _currentLatLng!.longitude,
            'isLive': false,
            'senderId': FirebaseAuth.instance.currentUser!.uid,
            'receiverId': widget.receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'locationSharedAt': FieldValue.serverTimestamp(), // ✅ ADDED
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📍 Sent Current Location!")),
      );

      Navigator.pop(context); // 👈 Navigate back to chat
    }
  }

  void _toggleLiveLocation() async {
    if (_isSharingLiveLocation) {
      await _liveLocationSubscription?.cancel();
      setState(() => _isSharingLiveLocation = false);
      Navigator.pop(context); // 👈 Navigate back to chat
      return;
    }

    final permission = await Permission.locationAlways.request();
    if (!permission.isGranted) return;

    _liveLocationSubscription = _location.onLocationChanged.listen((
      locationData,
    ) async {
      if (locationData.latitude == null || locationData.longitude == null)
        return;

      LatLng liveLatLng = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      _currentLatLng = liveLatLng;

      _updateMarker(liveLatLng, 'live', 'Live Location');

      if (_mapReady && mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(liveLatLng));
      }

      await FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.chatId)
          .collection('chats')
          .add({
            'type': 'location',
            'lat': liveLatLng.latitude,
            'lng': liveLatLng.longitude,
            'isLive': true,
            'senderId': FirebaseAuth.instance.currentUser!.uid,
            'receiverId': widget.receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'locationSharedAt': FieldValue.serverTimestamp(), // ✅ ADDED
          });

      setState(() {});
    });

    setState(() => _isSharingLiveLocation = true);
    Navigator.pop(context); // 👈 After starting live, navigate back to chat
  }

  @override
  void dispose() {
    _liveLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: Stack(
        children: [
          _currentLatLng == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                markers: _markers,
              ),
          if (!widget.isSharedLocationViewOnly)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 10,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send, color: Colors.white),
                              label: const Text(
                                "Send Current Location",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _sendCurrentLocation,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                _isSharingLiveLocation
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isSharingLiveLocation
                                    ? "Stop Live Location"
                                    : "Start Live Location",
                                style: const TextStyle(
                                  fontSize: 19,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _toggleLiveLocation,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
