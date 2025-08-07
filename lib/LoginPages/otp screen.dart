import 'dart:async';

import 'package:TwinBox/LoginPages/SPlash_screen.dart';
import 'package:TwinBox/LoginPages/signup_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile_card.dart';

class VerificationPage extends StatefulWidget {
  final String verificationId;
  VerificationPage({Key? key, required this.verificationId}) : super(key: key);

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  int _start = 0;
  bool _canResend = true;

  void startTimer() {
    setState(() {
      _start = 30;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void resendCode() {
    if (_canResend) {
      // Implement resend logic if needed
      startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              SizedBox(
                height: 160,
                width: 160,
                child: Image.asset("assets/Images/cropped_circle_image.png"),
              ),
              const SizedBox(height: 35),
              const Text(
                'Enter the 6-digit code sent to your phone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        hintText: "000000",
                        labelText: "OTP Code",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          EasyLoading.show(status: 'Verifying...');
                          try {
                            final credential = PhoneAuthProvider.credential(
                              verificationId: widget.verificationId,
                              smsCode: _otpController.text.trim(),
                            );

                            // Sign in
                            UserCredential userCredential = await FirebaseAuth
                                .instance
                                .signInWithCredential(credential);
                            User? user = userCredential.user;

                            if (user != null) {
                              DocumentSnapshot userDoc =
                                  await FirebaseFirestore.instance
                                      .collection(
                                        'client',
                                      ) // ✅ your correct collection name
                                      .doc(user.uid)
                                      .get();

                              SharedPreferences sharedpref =
                                  await SharedPreferences.getInstance();
                              await sharedpref.setBool(
                                SplashScreenState.KEYLOGIN,
                                true,
                              );

                              EasyLoading.dismiss();

                              if (userDoc.exists) {
                                Get.to(() => ProfileCardPage());
                              } else {

                                Get.to(() => CreateAccountPage(uid: user.uid));
                              }
                            } else {
                              EasyLoading.dismiss();
                              EasyLoading.showError('User sign-in failed');
                            }
                          } catch (ex) {
                            EasyLoading.dismiss();
                            EasyLoading.showError('OTP Verification failed');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Verify',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_canResend)
                      Text(
                        'Resend code in $_start seconds',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    if (_canResend)
                      TextButton(
                        onPressed: resendCode,
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
