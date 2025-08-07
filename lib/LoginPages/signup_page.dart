import 'dart:convert';
import 'dart:io';

import 'package:TwinBox/LoginPages/phone_auth.dart';
import 'package:TwinBox/profile_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class CreateAccountPage extends StatefulWidget {
  final String uid;

  const CreateAccountPage({Key? key, required this.uid}) : super(key: key);

  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final String _countryCode = '+91';

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();

  File? _selectedImage;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _countryCode;
    _phoneController.addListener(() {
      if (!_phoneController.text.startsWith(_countryCode)) {
        _phoneController.text = _countryCode;
        _phoneController.selection = TextSelection.fromPosition(
          TextPosition(offset: _phoneController.text.length),
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 512,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final bytes = await file.readAsBytes();

        if (!mounted) return;

        setState(() {
          _selectedImage = file;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _address1Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildFieldLabel(String labelText) {
    return Row(
      children: [
        Text(
          labelText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const Text(' *', style: TextStyle(fontSize: 14, color: Colors.red)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4267B2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.to(() => const PhoneInputPage()),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : null,
                      child:
                          _selectedImage == null
                              ? const Icon(
                                Icons.add_a_photo,
                                size: 32,
                                color: Colors.grey,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create An Account',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Please Sign Up or Registration',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel("First_name"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: _inputDecoration("Enter first_name"),
                            validator:
                                (val) => val!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel("Last_name"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: _inputDecoration("Enter last_name"),
                            validator:
                                (val) => val!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel("Phone"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration("Phone Number"),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+]'),
                              ),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            validator: (val) {
                              if (val == null ||
                                  !val.startsWith(_countryCode)) {
                                return "Invalid";
                              }
                              if (val.length != 13) {
                                return "Phone number must be 10 digits";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel("Company_name"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _companyController,
                            decoration: _inputDecoration("Enter company_name"),
                            validator:
                                (val) => val!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel("Address"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _address1Controller,
                            decoration: _inputDecoration("Enter Address"),
                            validator:
                                (val) => val!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("City"),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _cityController,
                                      decoration: _inputDecoration("City"),
                                      validator:
                                          (val) =>
                                              val!.isEmpty ? "Required" : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("State"),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _stateController,
                                      decoration: _inputDecoration("State"),
                                      validator:
                                          (val) =>
                                              val!.isEmpty ? "Required" : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel("Zipcode"),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _zipcodeController,
                            decoration: _inputDecoration("Zipcode"),
                            validator:
                                (val) => val!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting
                                      ? null
                                      : () async {
                                        if (_formKey.currentState!.validate()) {
                                          setState(() => _isSubmitting = true);

                                          await FirebaseFirestore.instance
                                              .collection('client')
                                              .doc(widget.uid)
                                              .set({
                                                'first_name':
                                                    _firstNameController.text,
                                                'last_name':
                                                    _lastNameController.text,
                                                'company_name':
                                                    _companyController.text,
                                                'phone': _phoneController.text,
                                                'address':
                                                    _address1Controller.text,
                                                'city': _cityController.text,
                                                'state': _stateController.text,
                                                'zipcode':
                                                    _zipcodeController.text,
                                                'profile_photo_base64':
                                                    _base64Image ?? '',
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                                'isUsingApp': true,
                                                'isFavourite': false,
                                              });

                                          Get.snackbar(
                                            "Success",
                                            "Registration completed!",
                                            backgroundColor: Colors.green,
                                            colorText: Colors.white,
                                            snackPosition: SnackPosition.TOP,
                                          );

                                          Future.delayed(
                                            const Duration(seconds: 1),
                                            () {
                                              Get.to(
                                                () => const ProfileCardPage(),
                                              );
                                            },
                                          );

                                          setState(() => _isSubmitting = false);
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
