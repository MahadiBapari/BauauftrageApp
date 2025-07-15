import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bauauftrage/core/network/safe_http.dart';

class EditProfileFormClient extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function onProfileUpdated;

  const EditProfileFormClient({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileFormClient> createState() => _EditProfileFormClientState();
}

class _EditProfileFormClientState extends State<EditProfileFormClient> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  late String _email; // Store email locally

  // No need for _emailController as it's readOnly and initialValue is used.
  // The email will be passed directly from widget.userData.

  @override
  void initState() {
    super.initState();

    _phoneController.text = widget.userData['meta_data']?['user_phone_']?[0] ?? '';
    _firstNameController.text = widget.userData['meta_data']?['first_name']?[0] ?? '';
    _lastNameController.text = widget.userData['meta_data']?['last_name']?[0] ?? '';
    _email = widget.userData['user_email'] ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'user_id': widget.userData['ID'].toString(),
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'user_phone_': _phoneController.text,
        // Use the correct key for the API
        'email': _email,
      };

      const apiKey = '1234567890abcdef';
      const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/';

      try {
        final response = await SafeHttp.safePost(context, Uri.parse(url), headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-API-Key': apiKey,
        }, body: updatedData);

        // Ensure widget is still mounted before accessing context
        if (!mounted) return;

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          widget.onProfileUpdated(); // Callback to refresh parent data
          Navigator.of(context).pop(); // Close the dialog
        } else {
          _showError(responseData['message'] ?? 'Failed to update profile.');
        }
      } catch (e) {
        _showError('Error updating profile: $e');
      }
    }
  }

  void _showError(String message) {
    // Ensure widget is still mounted before accessing context
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with X icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const SizedBox(width: 48), // To balance the close button
              ],
            ),
          ),
          const Divider(height: 1),

          // Flexible content area for the form fields
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (readonly)
                      TextFormField(
                        initialValue: _email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email (not editable)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Save Button - positioned outside the scrollable area
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}