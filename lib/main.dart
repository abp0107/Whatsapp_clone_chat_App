import 'package:TwinBox/LoginPages/SPlash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupFCM();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TwinBox',
      theme: ThemeData(),
      home: const SplashScreen(),
      builder: EasyLoading.init(),
    );
  }
}

/// 🔔 Firebase Messaging Setup
Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission();
  print('🔔 Notification permission: ${settings.authorizationStatus}');

  // Get FCM token
  String? token = await messaging.getToken();
  print('📲 FCM Token: $token');

  // Foreground handling
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 Foreground message received!');
    print('🔔 Title: ${message.notification?.title}');
    print('📝 Body: ${message.notification?.body}');

    Get.snackbar(
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      backgroundColor: Colors.blueAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  });
}
