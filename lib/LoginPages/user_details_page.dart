import 'package:flutter/material.dart';

class UserDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const UserDetailsPage({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4267B2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        (data['profile_photo'] != null &&
                                data['profile_photo'].toString().isNotEmpty)
                            ? NetworkImage(data['profile_photo'])
                            : const AssetImage(
                                  'assets/Images/cropped_circle_image.png',
                                )
                                as ImageProvider,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${data['first_name']} ${data['last_name']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data['company_name'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  _buildDetailRow(Icons.phone, 'Phone', data['phone']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.home, 'Address', data['address']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_city, 'City', data['city']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.map, 'State', data['state']),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.local_post_office,
                    'Zipcode',
                    data['zipcode'],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label: ${value ?? 'N/A'}',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
