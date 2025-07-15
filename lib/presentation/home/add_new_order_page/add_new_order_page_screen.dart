import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart'; 

class AddNewOrderPageScreen extends StatefulWidget {
  final String? initialCategoryId;

  const AddNewOrderPageScreen({super.key, this.initialCategoryId});

  @override
  _AddNewOrderPageScreenState createState() => _AddNewOrderPageScreenState();
}

class _AddNewOrderPageScreenState extends State<AddNewOrderPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _streetController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _picker = ImagePicker();
  final String _apiKey = '1234567890abcdef';
  String? _authToken;
  final List<File> _selectedImages = [];
  List<String> _selectedCategories = [];
  bool _isSubmitting = false;

  
  late Future<List<Map<String, dynamic>>> _categoriesFuture; 

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _categoriesFuture = _fetchOrderCategories(); // Fetch categories in initState
    if (widget.initialCategoryId != null) {
      _selectedCategories.add(widget.initialCategoryId!);
    }
  }

  // Function to fetch order categories from the API
  Future<List<Map<String, dynamic>>> _fetchOrderCategories() async {
    final response = await http.get(
      Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((item) => {
        'id': item['id'],
        'name': item['name'],
      }).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
    print("Retrieved Token in AddNewOrderPage: $_authToken");
  }

Future<void> _pickImages() async {
  final source = await showModalBottomSheet<ImageSource?>(
    context: context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.photo),
          title: const Text("Galerie"),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera),
          title: const Text("Kamera"),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
      ],
    ),
  );

  if (source == ImageSource.gallery) {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    setState(() {
      _selectedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
    });
    } else if (source == ImageSource.camera) {
    if (source == null) return;

    final XFile? picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedImages.add(File(picked.path));
      });
    }
  }
}


Future<List<int>> uploadImages(List<File> imageFiles) async {
  List<int> uploadedIds = [];

  for (final imageFile in imageFiles) {
    try {
      final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media');
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $_authToken',
          'X-API-Key': _apiKey,
          'Content-Disposition': 'attachment; filename="${path.basename(imageFile.path)}"',
        })
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final mediaId = data['id'];
        uploadedIds.add(mediaId);
      } else {
        print('Image upload failed with status ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      print('Exception during image upload for ${imageFile.path}: $e');
    }
  }

  return uploadedIds;
}



  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(160, 244, 67, 54),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  if (_authToken == null) {
    _showError("Authentifizierung erforderlich. Bitte melden Sie sich an.");
    return;
  }

  setState(() => _isSubmitting = true);

// Declare imageId as a List<int>? or List<int>
// If you declare it as `List<int> imageId;` it cannot be null initially unless assigned later.
// A common pattern is to make it nullable if it might not always have a value.
// Perform the image upload and get the IDs
List<int>? uploadedImageIds;
try {
  if (_selectedImages.isNotEmpty) {
    uploadedImageIds = await uploadImages(_selectedImages);
  }
} catch (e) {
  print('Fehler beim Hochladen der Bilder. Bitte versuchen Sie es erneut.');
  // Handle the error appropriately, e.g., show a user-friendly message
  // _showError("Failed to upload images. Please try again.");
  return; // Stop execution if image upload fails
}

// Now, construct the postData map
final Map<String, dynamic> postData = {
  "title": _titleController.text,
  "content": _descriptionController.text,
  "status": "publish",
  "meta": {
    "address_1": _streetController.text,
    "address_2": _postalCodeController.text,
    "address_3": _cityController.text,
    // Corrected: Use uploadedImageIds and transform it for "order_gallery"
    if (uploadedImageIds != null && uploadedImageIds.isNotEmpty)
      "order_gallery": uploadedImageIds.map((id) => {"id": id}).toList(),
  },
  "order-categories": _selectedCategories.map((e) => int.parse(e)).toList(),
};



  final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
        'X-API-Key': _apiKey,
      },
      body: jsonEncode(postData),
    );

      if (response.statusCode == 201) {
        if (!mounted) return; // Check if the widget is still mounted before interacting with the UI

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Auftrag erfolgreich übermittelt und veröffentlicht!'),
            backgroundColor: const Color.fromARGB(129, 0, 0, 0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );

        // Reset the form fields managed by _formKey
        _formKey.currentState!.reset();

        setState(() {
          // Clear the selected categories list
          _selectedCategories.clear();

          // Corrected: Clear the _selectedImages list instead of assigning null
          _selectedImages.clear(); // This is the most common and robust solution
          // OR if _selectedImages was declared as List<File>?, then:
          // _selectedImages = null; // This would also be valid if the type is nullable
        });

    // Optionally, you might want to navigate back or to another screen
    // Navigator.of(context).pop(); // Example: go back to the previous screen
  } else {
      final data = jsonDecode(response.body);
      _showError(data['message'] ?? 'Übermittlung fehlgeschlagen. Status Code: ${response.statusCode}');
    }
  } catch (e) {
    _showError('Fehler: $e');
  } finally {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }
}


  @override
  void dispose() {
    _titleController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 255, 254, 254), // Light background

    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 155, 155, 155).withOpacity(0.30), // Stronger shadow
              blurRadius: 12, // More blur for a softer, larger shadow
              spreadRadius: 4, // Slightly larger spread
              offset: const Offset(0, 0), // Even shadow on all sides
            ),
          ],
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_titleController, 'Auftragstitel *', true, icon: Icons.title),
                const SizedBox(height: 20),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return Text('Fehler: ${snapshot.error}');
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Keine Kategorien gefunden');
                    } else {
                      final categories = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Kategorie auswählen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          MultiSelectDialogField(
                            backgroundColor: Colors.white,
                            items: categories.map((category) => MultiSelectItem(
                                category['id'].toString(), category['name'])).toList(),
                            title: const Text("Kategorie"),
                            selectedColor: const Color.fromARGB(255, 185, 33, 33),
                            cancelText: const Text("", style: TextStyle(fontSize: 0)), 
                            confirmText: const Text("OK", style: TextStyle(color: Color.fromARGB(255, 185, 33, 33), fontWeight: FontWeight.bold)),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            buttonText: const Text("Kategorie auswählen"),
                            onConfirm: (values) {
                              setState(() => _selectedCategories = values.cast<String>());
                            },
                            chipDisplay: MultiSelectChipDisplay.none(),
                            validator: (value) =>
                                value == null || value.isEmpty ? 'Bitte wähl mindestens eini Kategorie' : null,
                            initialValue: _selectedCategories,
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 10),
                if (_selectedCategories.isNotEmpty) _buildSelectedChips(),
                const SizedBox(height: 20),

                _buildImagePicker(),

                const SizedBox(height: 20),
                _buildTextField(_streetController, 'Strasse & Hausnummer', true, icon: Icons.location_on),
                const SizedBox(height: 20),
                _buildTextField(_postalCodeController, 'PLZ', true, icon: Icons.local_post_office),
                const SizedBox(height: 20),
                _buildTextField(_cityController, 'Ort', true, icon: Icons.location_city),
                const SizedBox(height: 20),
                _buildTextField(_descriptionController, 'Auftragsbeschreibung *', true, maxLines: 5, icon: Icons.description),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSubmitting ? null : _submitForm,
                    label: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Auftrag veröffentlichen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: const Color.fromARGB(255, 180, 16, 16), // Maroon color
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildTextField(TextEditingController controller, String label, bool required,
      {int maxLines = 1, IconData? icon}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: (value) =>
          required && (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
    );
  }

  Widget _buildSelectedChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCategories.map((categoryId) {
        // Find the category name based on the ID.
        final categoryName = _categoriesFuture.then((categoryList) =>
            categoryList.firstWhere((category) => category['id'].toString() == categoryId)['name'] as String); // Add 'as String' here

        return FutureBuilder<String>(
            future: categoryName,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Chip(label: Text('Am Lade ...'));
              } else if (snapshot.hasError) {
                return Chip(label: Text('Fähler'));
              } else {
                return Chip(
                  label: Text(snapshot.data ?? "N/A"),
                  onDeleted: () {
                    setState(() => _selectedCategories.remove(categoryId));
                  },
                );
              }
            });
      }).toList(),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('Bilder auswählen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 180, 16, 16), // Maroon color
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedImages.isEmpty
                    ? 'Keine Bilder ausgewählt?'
                    : '${_selectedImages.length} Bild(er) usgwählt',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                return Stack(
                  children: [
                    Image.file(_selectedImages[index], height: 100),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Color.fromARGB(255, 255, 255, 255)),
                        onPressed: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

}