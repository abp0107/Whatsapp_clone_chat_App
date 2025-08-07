import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> userData;

  const EditProfilePage({
    super.key,
    required this.docId,
    required this.userData,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController companyController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController cityController;
  late TextEditingController stateController;
  late TextEditingController zipController;
  late TextEditingController bioController;

  String? profileBase64;

  @override
  void initState() {
    super.initState();

    firstNameController = TextEditingController(text: widget.userData['first_name']);
    lastNameController = TextEditingController(text: widget.userData['last_name']);
    companyController = TextEditingController(text: widget.userData['company_name']);
    phoneController = TextEditingController(text: widget.userData['phone']);
    addressController = TextEditingController(text: widget.userData['address']);
    cityController = TextEditingController(text: widget.userData['city']);
    stateController = TextEditingController(text: widget.userData['state']);
    zipController = TextEditingController(text: widget.userData['zipcode']);
    bioController = TextEditingController(
      text: widget.userData['status'] ?? 'Hey there! I am using the app.',
    );

    profileBase64 = widget.userData['profile_photo_base64'];
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndChangeImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      final bytes = await File(pickedImage.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      // Update Firestore with new base64 image
      await FirebaseFirestore.instance
          .collection('client')
          .doc(widget.docId)
          .update({'profile_photo_base64': base64Image});

      setState(() {
        profileBase64 = base64Image;
      });

      Get.snackbar(
        'Success',
        'Profile photo updated',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('client')
          .doc(widget.docId)
          .update({
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
        'company_name': companyController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'city': cityController.text,
        'state': stateController.text,
        'zipcode': zipController.text,
        'status': bioController.text,
      });

      Get.back();
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (profileBase64 != null && profileBase64!.isNotEmpty)
                      ? MemoryImage(base64Decode(profileBase64!))
                      : null,
                  child: (profileBase64 == null || profileBase64!.isEmpty)
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
              ),
              TextButton(
                onPressed: _pickAndChangeImage,
                child: const Text(
                  "CHANGE IMAGE",
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(firstNameController, 'First Name'),
              _buildTextField(lastNameController, 'Last Name'),
              _buildTextField(companyController, 'Company Name'),
              _buildTextField(phoneController, 'Phone'),
              _buildTextField(addressController, 'Address'),
              _buildTextField(cityController, 'City'),
              _buildTextField(stateController, 'State'),
              _buildTextField(zipController, 'Zipcode'),
              _buildTextField(bioController, 'Bio'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffFFFFFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Enter $label' : null,
      ),
    );
  }
}
