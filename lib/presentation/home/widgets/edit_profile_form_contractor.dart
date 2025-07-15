import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_select_flutter/multi_select_flutter.dart';

class EditProfileFormContractor extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function onProfileUpdated;

  const EditProfileFormContractor({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileFormContractor> createState() =>
      _EditProfileFormContractorState();
}

class _EditProfileFormContractorState
    extends State<EditProfileFormContractor> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _phoneController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _uidNumberController = TextEditingController();
  final _availableTimeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  late String _email; // Store email locally

  // New state for service categories
  List<Map<String, dynamic>> _allServiceCategories = [];
  List<String> _selectedServiceCategoryIds = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing user data
    _phoneController.text = widget.userData['meta_data']?['user_phone_']?[0] ?? '';
    _firmNameController.text = widget.userData['meta_data']?['firmenname_']?[0] ?? '';
    _uidNumberController.text = widget.userData['meta_data']?['uid_nummer']?[0] ?? '';
    _availableTimeController.text = widget.userData['meta_data']?['available_time']?[0] ?? '';
    _firstNameController.text = widget.userData['meta_data']?['first_name']?[0] ?? '';
    _lastNameController.text = widget.userData['meta_data']?['last_name']?[0] ?? '';

    _email = widget.userData['user_email'] ?? '';

    // Initialize selected categories from user data
    final serviceCategories = widget.userData['meta_data']?['_service_category_'];
    if (serviceCategories is List) {
      _selectedServiceCategoryIds = serviceCategories
          .map((cat) => cat is Map ? cat['id']?.toString() : null)
          .where((id) => id != null)
          .cast<String>()
          .toList();
    }

    // Fetch all categories
    _fetchServiceCategories();
  }

  Future<void> _fetchServiceCategories() async {
    const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100';
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _allServiceCategories = data.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'],
          }).toList();
        });
      }
    } catch (e) {
      // Handle or log error
      debugPrint('Failed to load categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    _phoneController.dispose();
    _firmNameController.dispose();
    _uidNumberController.dispose();
    _availableTimeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'user_id': widget.userData['ID'].toString(),
        'email': _email,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'user_phone_': _phoneController.text,
        'firmenname_': _firmNameController.text,
        'uid_nummer': _uidNumberController.text,
        'available_time': _availableTimeController.text,
        '_service_category_': _selectedServiceCategoryIds.map((id) => int.tryParse(id) ?? 0).where((id) => id > 0).toList(),
      };

      const apiKey = '1234567890abcdef';
      const url =
          'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/';

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey,
          },
          body: json.encode(updatedData),
        );

        // Ensure widget is still mounted before interacting with the UI
        if (!mounted) return;

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profil erfolgreich aktualisiert!'),
              backgroundColor: const Color.fromARGB(103, 0, 0, 0),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
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
    // Ensure widget is still mounted before interacting with the UI
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(162, 244, 67, 54),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Column( // This outer Column manages the layout of header, scrollable content, and button
        mainAxisSize: MainAxisSize.min, // Ensures dialog takes minimum vertical space
        children: [
          // Header with X icon and Title
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
                  'Profil bearbeiten',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const SizedBox(width: 48), // To balance the close button
              ],
            ),
          ),

          const Divider(height: 1),

          // Flexible content area for the form fields
          // This allows the SingleChildScrollView to take available height and scroll if needed
          Flexible( // Use Flexible to allow content to take available height but not overflow
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // Dismiss keyboard on scroll
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Inner column should still shrink-wrap its children
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vorname',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nachname',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (readonly)
                      TextFormField(
                        initialValue: _email, // Use local variable for readOnly
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'E-Mail (nicht bearbeitbar)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Telefon',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Firm Name
                      TextFormField(
                        controller: _firmNameController,
                        decoration: InputDecoration(
                          labelText: 'Firmenname',
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // UID Number
                      TextFormField(
                        controller: _uidNumberController,
                        decoration: const InputDecoration(
                          labelText: 'UID-Nummer',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Available Time Dropdown
                      DropdownButtonFormField<String>(
                        value: _availableTimeController.text.isNotEmpty
                            ? _availableTimeController.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Verfügbare Zeit',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: '08.00 - 12.00 Uhr',
                              child: Text('08.00 - 12.00 Uhr')),
                          DropdownMenuItem(
                              value: '12.00 - 14.00 Uhr',
                              child: Text('12.00 - 14.00 Uhr')),
                          DropdownMenuItem(
                              value: '14.00 - 18.00 Uhr',
                              child: Text('14.00 - 18.00 Uhr')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _availableTimeController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Service Categories MultiSelect
                      _isLoadingCategories
                          ? const Center(child: CircularProgressIndicator())
                          : MultiSelectDialogField(
                              backgroundColor: Colors.white,
                              items: _allServiceCategories
                                  .map((category) => MultiSelectItem<String>(
                                      category['id']!, category['name']!))
                                  .toList(),
                              initialValue: _selectedServiceCategoryIds,
                              title: const Text("Kategorien"),
                              selectedColor: const Color.fromARGB(255, 185, 33, 33),
                              cancelText: const Text("", style: TextStyle(fontSize: 0)),
                              confirmText: const Text("OK", style: TextStyle(color: Color.fromARGB(255, 185, 33, 33), fontWeight: FontWeight.bold)),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color.fromARGB(255, 88, 88, 88)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              buttonText: const Text("Kategorien auswählen"),
                              onConfirm: (values) {
                                setState(() {
                                  _selectedServiceCategoryIds = values.cast<String>();
                                });
                              },
                              chipDisplay: MultiSelectChipDisplay(
                                chipColor: const Color.fromARGB(76, 167, 17, 17),
                                textStyle: const TextStyle(color: Color.fromARGB(255, 82, 82, 82)),
                                icon: null, // This removes the default check icon
                                onTap: (value) {
                                  setState(() {
                                    _selectedServiceCategoryIds.remove(value);
                                  });
                                },
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Please select at least one category' : null,
                            ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Save Button - positioned outside the scrollable area
          Padding(
            padding: const EdgeInsets.all(20), // Padding for the button
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Änderungen speichern'),
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