import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For displaying existing network images
import 'package:bauauftrage/core/network/safe_http.dart';

class EditOrderPageScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const EditOrderPageScreen({super.key, required this.order});

  @override
  _EditOrderPageScreenState createState() => _EditOrderPageScreenState();
}

class _EditOrderPageScreenState extends State<EditOrderPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _streetController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _picker = ImagePicker();
  final String _apiKey = '1234567890abcdef';
  String? _authToken;
  bool _isSubmitting = false;

  // New: Lists for managing existing and new images
  List<Map<String, dynamic>> _currentGalleryImages = []; // {id: int, url: String}
  List<File> _newlySelectedImages = []; // Files chosen from picker

  List<String> _selectedCategoryIds = []; // Stores category IDs as strings

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  Map<int, String> _categoryMap = {}; // FIX: Initialize it to an empty map

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _categoriesFuture = _fetchOrderCategories();
    _prefillFormWithOrderData();
  }

  // Pre-fill the form fields with existing order data
  void _prefillFormWithOrderData() async {
    final order = widget.order;
    final meta = order['meta'] ?? {};

    _titleController.text = order['title']?['rendered'] ?? '';
    _descriptionController.text = _stripHtml(order['content']?['rendered'] ?? '');
    _streetController.text = meta['address_1'] ?? '';
    _postalCodeController.text = meta['address_2'] ?? '';
    _cityController.text = meta['address_3'] ?? '';

    // Handle existing categories
    final List<dynamic> rawCategoryIds = order['order-categories'] ?? [];
    _selectedCategoryIds = rawCategoryIds.map((id) => id.toString()).toList();

    // Handle existing images
    final List<dynamic> galleryDynamic = meta['order_gallery'] ?? [];
    List<int> galleryImageIds = galleryDynamic
        .whereType<Map>()
        .map((item) => item['id'])
        .whereType<int>()
        .toList();

    // Fetch URLs for existing images
    List<Map<String, dynamic>> fetchedGalleryImages = [];
    for (int mediaId in galleryImageIds) {
      try {
        final response = await http.get(
          Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId'),
          headers: {'X-API-KEY': _apiKey},
        );
        if (response.statusCode == 200) {
          final mediaData = jsonDecode(response.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null) {
            fetchedGalleryImages.add({'id': mediaId, 'url': imageUrl});
          }
        } else {
          debugPrint('Failed to fetch media for ID $mediaId: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching media for ID $mediaId: $e');
      }
    }

    if (mounted) {
      setState(() {
        _currentGalleryImages = fetchedGalleryImages;
      });
    }
  }

  // Function to fetch order categories from the API
  Future<List<Map<String, dynamic>>> _fetchOrderCategories() async {
    final response = await http.get(
      Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      _categoryMap = {}; // Initialize map within here as well if not already done
      for (var item in data) {
        _categoryMap[item['id']] = item['name'];
      }
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
    debugPrint("Retrieved Token in EditOrderPage: $_authToken");
  }

  Future<void> _pickImages() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("Gallery"),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text("Camera"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == ImageSource.gallery) {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      setState(() {
        _newlySelectedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
      });
    } else if (source == ImageSource.camera) {
      if (source == null) return;
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _newlySelectedImages.add(File(picked.path));
        });
      }
    }
  }

  Future<List<int>> _uploadImages(List<File> imageFiles) async {
    List<int> uploadedIds = [];
    if (_authToken == null) {
      _showError("Authentication required for image upload.");
      return uploadedIds;
    }

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
          debugPrint('Image upload failed with status ${response.statusCode}: $responseBody');
          _showError('Failed to upload image: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Exception during image upload for ${imageFile.path}: $e');
        _showError('Error uploading image: $e');
      }
    }
    return uploadedIds;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_authToken == null) {
      _showError("Authentication required. Please log in.");
      return;
    }

    setState(() => _isSubmitting = true);

    List<int> combinedImageIds = _currentGalleryImages.map((img) => img['id'] as int).toList();

    try {
      if (_newlySelectedImages.isNotEmpty) {
        List<int> newlyUploadedImageIds = await _uploadImages(_newlySelectedImages);
        combinedImageIds.addAll(newlyUploadedImageIds);
      }
    } catch (e) {
      debugPrint('Error uploading new images: $e');
      _showError("Failed to upload new images. Please try again.");
      setState(() => _isSubmitting = false);
      return;
    }

    final Map<String, dynamic> putData = {
      "title": _titleController.text,
      "content": _descriptionController.text,
      "status": "publish", // Or could be 'draft' based on logic
      "meta": {
        "address_1": _streetController.text,
        "address_2": _postalCodeController.text,
        "address_3": _cityController.text,
        "order_gallery": combinedImageIds.map((id) => {"id": id}).toList(),
      },
      "order-categories": _selectedCategoryIds.map((e) => int.parse(e)).toList(),
    };

    final orderId = widget.order['id'];
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order/$orderId');

    try {
      final response = await SafeHttp.safePut(context, url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
        'X-API-Key': _apiKey,
      }, body: jsonEncode(putData));

      if (!mounted) return;

      if (response.statusCode == 200) { // HTTP 200 for successful PUT/update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully!')),
        );
        Navigator.of(context).pop(true); // Pop with 'true' to indicate success
      } else {
        final data = jsonDecode(response.body);
        _showError(data['message'] ?? 'Update failed. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
      appBar: AppBar(
        title: const Text('Auftrag bearbeiten', style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 0, 0, 0)),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 254, 254),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 155, 155, 155).withOpacity(0.30),
                blurRadius: 12,
                spreadRadius: 4,
                offset: const Offset(0, 0),
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
                        return Text('Error: ${snapshot.error}');
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('Keine Kategorien gefunden');
                      } else {
                        final categories = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Kategorien auswählen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            MultiSelectDialogField(
                              items: categories.map((category) => MultiSelectItem(
                                  category['id'].toString(), category['name']!)).toList(),
                              title: const Text("Kategorien"),
                              selectedColor: Theme.of(context).primaryColor,
                              cancelText: const Text("Abbrechen"),
                              confirmText: const Text("OK", style: TextStyle(color: Color.fromARGB(255, 185, 33, 33), fontWeight: FontWeight.bold)),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              buttonText: const Text("Kategorien auswählen"),
                              initialValue: _selectedCategoryIds, // Pre-fill selected categories
                              onConfirm: (values) {
                                setState(() => _selectedCategoryIds = values.cast<String>());
                              },
                              chipDisplay: MultiSelectChipDisplay.none(),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Bitte wählen Sie mindestens eine Kategorie' : null,
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),
                  if (_selectedCategoryIds.isNotEmpty) _buildSelectedChips(),
                  const SizedBox(height: 20),

                  _buildImagePicker(), // Updated image picker to show existing and new images

                  const SizedBox(height: 20),
                  _buildTextField(_streetController, 'Street & House Number', true, icon: Icons.location_on),
                  const SizedBox(height: 20),
                  _buildTextField(_postalCodeController, 'Postal Code', true, icon: Icons.local_post_office),
                  const SizedBox(height: 20),
                  _buildTextField(_cityController, 'City', true, icon: Icons.location_city),
                  const SizedBox(height: 20),
                  _buildTextField(_descriptionController, 'Order Description *', true, maxLines: 5, icon: Icons.description),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, color: Colors.white), // Changed icon to save
                      onPressed: _isSubmitting ? null : _submitForm,
                      label: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Auftrag aktualisieren', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: const Color.fromARGB(255, 180, 16, 16),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) =>
          required && (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
    );
  }

  Widget _buildSelectedChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCategoryIds.map((categoryId) {
        // Now _categoryMap is initialized, so this access is safe
        final categoryName = _categoryMap[int.parse(categoryId)] ?? 'Unknown';
        return Chip(
          label: Text(categoryName),
          onDeleted: () {
            setState(() => _selectedCategoryIds.remove(categoryId));
          },
        );
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
              child: const Text('Bilder hinzufügen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 180, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_currentGalleryImages.length + _newlySelectedImages.length} Bild(er) insgesamt',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_currentGalleryImages.isNotEmpty || _newlySelectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _currentGalleryImages.length + _newlySelectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                if (index < _currentGalleryImages.length) {
                  // Existing image
                  final image = _currentGalleryImages[index];
                  return Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: image['url'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Color.fromARGB(255, 255, 255, 255)),
                          onPressed: () {
                            setState(() {
                              _currentGalleryImages.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // Newly selected image
                  final newImageIndex = index - _currentGalleryImages.length;
                  final imageFile = _newlySelectedImages[newImageIndex];
                  return Stack(
                    children: [
                      Image.file(imageFile, height: 100, width: 100, fit: BoxFit.cover),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Color.fromARGB(255, 255, 255, 255)),
                          onPressed: () {
                            setState(() {
                              _newlySelectedImages.removeAt(newImageIndex);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}