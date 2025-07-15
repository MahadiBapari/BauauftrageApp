import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';
import 'package:shimmer/shimmer.dart';

import '../widgets/edit_profile_form_contractor.dart'; // Make sure this path is correct
import '../support_and_help_page/support_and_help_page_screen.dart'; // Import the new screen
import 'package:bauauftrage/utils/cache_manager.dart';

class ProfilePageScreenContractor extends StatefulWidget {
  const ProfilePageScreenContractor({super.key});

  @override
  State<ProfilePageScreenContractor> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageScreenContractor> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  
  final ImagePicker _picker = ImagePicker(); 
  final String apiKey = '1234567890abcdef'; 
  String? _authToken; 
  String? _userId;
  String? _profileImageUrl;

  List<Map<String, dynamic>> _allServiceCategories = [];

  @override
  void initState() {
    super.initState();
    _loadUserDataFromCacheThenBackground();
    _fetchAllServiceCategories();
  }

  Future<void> _fetchAllServiceCategories() async {
    if (!await isUserAuthenticated()) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
      headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (mounted && response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _allServiceCategories = data.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'],
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Failed to load service categories: $e');
      }
    }
  }

  Future<void> _loadUserDataFromCacheThenBackground() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    // Try to load from cache first
    final cacheManager = CacheManager();
    final cachedUser = await cacheManager.loadFromCache('profile_user_$_userId');
    if (cachedUser != null) {
      setState(() {
        _userData = cachedUser as Map<String, dynamic>;
        _isLoading = false;
      });
      _loadProfilePicture();
    }
    // Fetch fresh data in background
    _loadUserData(fetchAndUpdateCache: true);
  }

  Future<void> _loadUserData({bool fetchAndUpdateCache = false}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    if (_userId == null) {
      _showError('User ID not found');
      setState(() => _isLoading = false);
      return;
    }
    if (!fetchAndUpdateCache) setState(() => _isLoading = true);
    final url =
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$_userId';
    try {
      final response = await SafeHttp.safeGet(context, Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _isLoading = false;
        });
        _loadProfilePicture();
        // Save to cache
        final cacheManager = CacheManager();
        await cacheManager.saveToCache('profile_user_$_userId', data);
      } else {
        _showError('Failed to load profile: {response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfilePicture() async {
    if (_userData == null || !mounted) return;
    if (!await isUserAuthenticated()) return;

    final dynamic rawMediaId = _userData!['meta_data']?['profile-picture']?[0];
    final String? mediaId = (rawMediaId is int) ? rawMediaId.toString() : rawMediaId as String?;

    if (mediaId != null && mediaId.isNotEmpty) {
      try {
        final mediaUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId';
        final response = await SafeHttp.safeGet(context, Uri.parse(mediaUrl), headers: {
          'Authorization': 'Bearer $_authToken',
          'X-API-Key': apiKey,
        });

        if (mounted && response.statusCode == 200) {
          final mediaData = json.decode(response.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null) {
            setState(() {
              _profileImageUrl = imageUrl;
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to load profile image: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _profileImageUrl = null;
        });
      }
    }
  }

 
  Future<void> _pickImage() async {
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

    if (source == null) return; 

    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      final imageFile = File(pickedFile.path);

      if (await imageFile.exists()) {
        await _uploadAndLinkProfileImage(imageFile);
      } else {
        if (!mounted) return;
        _showError("Selected image does not exist.");
      }
    }
  }

  
  Future<void> _uploadAndLinkProfileImage(File imageFile) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final mediaId = await _uploadImageToMediaLibrary(imageFile);

    if (mediaId != null) {
      await _linkProfileImageToUser(mediaId);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading state is reset if upload fails
        });
      }
    }
  }

 
  Future<int?> _uploadImageToMediaLibrary(File imageFile) async {
    try {
      final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media');
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Authorization': 'Bearer $_authToken',
          'X-API-Key': apiKey,
          'Content-Disposition': 'attachment; filename="${path.basename(imageFile.path)}"',
        })
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final mediaId = data['id'] as int? ?? 0;
        if (mediaId > 0) {
          debugPrint('Image uploaded successfully with ID: $mediaId');
          return mediaId;
        } else {
          debugPrint('Image upload returned no valid media ID: $responseBody');
          _showError('Image upload failed: No valid media ID returned.');
          return null;
        }
      } else {
        debugPrint('Image upload failed with status ${response.statusCode}: $responseBody');
        _showError('Image upload failed: $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during image upload: $e');
      _showError('Exception during image upload: $e');
      return null;
    }
  }

  
  Future<void> _linkProfileImageToUser(int mediaId) async {
    if (_userId == null || _authToken == null || _userData == null) {
      if (mounted) _showError('Missing user data or token. Cannot update profile.');
      return;
    }

    final meta = _userData!['meta_data'] ?? {};
    final serviceCategories = meta['_service_category_'];
    List<int> serviceCategoryIds = [];
    if (serviceCategories is List) {
      serviceCategoryIds = serviceCategories
          .map((cat) {
            if (cat is Map && cat.containsKey('id')) {
              return int.tryParse(cat['id'].toString());
            }
            return null;
          })
          .whereType<int>()
          .toList();
    }

    final body = {
      'user_id': _userId,
      'email': _userData!['user_email'] ?? '',
      'first_name': meta['first_name']?[0] ?? '',
      'last_name': meta['last_name']?[0] ?? '',
      'user_phone_': meta['user_phone_']?[0] ?? '',
      'firmenname_': meta['firmenname_']?[0] ?? '',
      'uid_nummer': meta['uid_nummer']?[0] ?? '',
      'available_time': meta['available_time']?[0] ?? '',
      '_service_category_': serviceCategoryIds,
      'profile-picture': mediaId.toString(),
    };

    const url =
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/';

    try {
      final response = await SafeHttp.safePost(context, Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
        'X-API-Key': apiKey,
      }, body: json.encode(body));

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Profile picture meta updated successfully!');
        await _loadUserData();
      } else {
        print('Failed to update user meta. Status: ${response.statusCode}, Body: ${response.body}');
        _showError('Failed to update profile picture: ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error linking image to profile: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fehler'),
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

  void _showResetPasswordDialog(BuildContext context) {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_reset, size: 48, color: const Color.fromARGB(255, 185, 7, 7)),
              const SizedBox(height: 16),
              const Text(
                'Passwort zurücksetzen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Geben Sie unten Ihr neues Passwort ein.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Neues Passwort',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Neues Passwort bestätigen',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Abbrechen',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 185, 7, 7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final newPass = newController.text.trim();
                        final confirm = confirmController.text.trim();
                        if (newPass != confirm) {
                          Navigator.of(ctx).pop();
                          _showError('Passwörter stimmen nicht überein.');
                          return;
                        }
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token');
                        final userId = prefs.getString('user_id');
                        if (token == null || userId == null) {
                          Navigator.of(ctx).pop();
                          _showError('Nicht authentifiziert.');
                          return;
                        }
                        final url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user/$userId/update-password';
                        try {
                          final response = await SafeHttp.safePost(context, Uri.parse(url), headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                            'X-API-Key': '1234567890abcdef',
                          }, body: json.encode({
                            'password': newPass,
                            'confirm_password': confirm,
                          }));
                          Navigator.of(ctx).pop();
                          if (response.statusCode == 200) {
                            _showError('Passwort erfolgreich geändert.');
                          } else {
                            _showError('Fehler beim Ändern des Passworts: \n${response.body}');
                          }
                        } catch (e) {
                          Navigator.of(ctx).pop();
                          _showError('Fehler: $e');
                        }
                      },
                      child: const Text('Zurücksetzen', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: _isLoading && _userData == null
          ? _buildProfileShimmer()
          : _userData == null
              ? const Center(child: Text('Kei Benutzerdaten verfügbar'))
              : SafeArea(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200, // Account for app bar and bottom navigation
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar( 
                                    radius: 55,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _profileImageUrl != null
                                        ? CachedNetworkImageProvider(_profileImageUrl!)
                                        : const AssetImage('assets/images/profile.png') as ImageProvider,
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _pickImage, 
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.fromARGB(255, 185, 7, 7)
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          size: 18, color: Color.fromARGB(255, 255, 255, 255)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          Text(
                            '${_userData!['meta_data']?['first_name']?[0] ?? ''} ${_userData!['meta_data']?['last_name']?[0] ?? ''}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 30),
                          _buildSectionTitle(
                            'Persönliche Informationen',
                            onEditTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => EditProfileFormContractor(
                                  userData: _userData!,
                                  onProfileUpdated: _loadUserData,
                                ),
                              );
                            },
                          ),
                          _buildInfoRow(
                            context,
                            'E-Mail',
                            _userData!['user_email'] ?? 'Kei E-Mail',
                            Icons.email,
                          ),
                          _buildInfoRow(
                            context,
                            'Telefon',
                            _userData!['meta_data']?['user_phone_']?[0] ??
                                'Kei Telefonnummer',
                            Icons.phone,
                          ),
                          _buildInfoRow(
                            context,
                            'Firmenname',
                            _userData!['meta_data']?['firmenname_']?[0] ??
                                'Kei Firmenname',
                            Icons.business,
                          ),
                          _buildInfoRow(
                            context,
                            'UID-Nummer',
                            _userData!['meta_data']?['uid_nummer']?[0] ??
                                'Kei UID-Nummer',
                            Icons.badge,
                          ),
                          _buildInfoRow(
                            context,
                            'Dienstleistigskategorie',
                            _getCategoryNames(),
                            Icons.category,
                          ),
                          _buildInfoRow(
                            context,
                            'Verfügbari Zyt',
                            _userData!['meta_data']?['available_time']?[0] ??
                                'Kei verfügbari Zyt',
                            Icons.access_time,
                          ),
                          const SizedBox(height: 30),
                          _buildSectionTitle('Hilfsmittel'),
                          _buildProfileOption(
                            context,
                            'Support & Hilfe',
                            Icons.question_mark,
                          ),
                          _buildProfileOption(
                            context,
                            'Passwort zurücksetzen',
                            Icons.lock_reset,
                          ),
                          _buildProfileOption(
                            context,
                            'Abmelden',
                            Icons.logout,
                          ),
                          
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 120,
                  height: 20,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 18,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 260,
                  height: 18,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 180,
                  height: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets (unchanged) ---
  Widget _buildSectionTitle(String title, {VoidCallback? onEditTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
        if (onEditTap != null)
          InkWell(
            onTap: onEditTap,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18, color: Color.fromARGB(255, 190, 51, 51)),
                  const SizedBox(width: 4),
                  Text(
                    'Bearbeiten',
                    style: TextStyle(color: Color.fromARGB(255, 190, 51, 51)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFF8F8F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color.fromARGB(255, 185, 7, 7)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          color: Color.fromARGB(255, 121, 105, 105))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        if (title == 'Abmelden') {
          _handleLogout(context);
        } else if (title == 'Support & Hilfe') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupportAndHelpPageScreen(),
            ),
          );
        } else if (title == 'Passwort zurücksetzen') {
          _showResetPasswordDialog(context);
        }
      },
      child: Card(
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: const Color(0xFFF8F8F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color.fromARGB(255, 185, 7, 7)),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Color.fromARGB(255, 243, 239, 239)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('username');
    await prefs.remove('user_email');
    await prefs.remove('displayName');
    // Add any other user/session keys you use, but DO NOT remove 'has_seen_onboarding'

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  String _getCategoryNames() {
    if (_userData == null || _allServiceCategories.isEmpty) {
      return 'Kategorie werde glade...';
    }

    final metaData = _userData!['meta_data'];
    if (metaData == null || metaData['_service_category_'] == null) {
      return 'Kei Kategorie usgwählt';
    }

    final rawCategories = metaData['_service_category_'];
    if (rawCategories is! List || rawCategories.isEmpty) {
      return 'Kei Kategorie usgwählt';
    }

    final selectedIds = rawCategories
        .map((cat) => cat is Map ? cat['id']?.toString() : null)
        .where((id) => id != null)
        .toSet();

    if (selectedIds.isEmpty) {
      return 'Kei Kategorie usgwählt';
    }

    final selectedNames = _allServiceCategories
        .where((category) => selectedIds.contains(category['id']))
        .map((category) => category['name'] as String)
        .toList();

    return selectedNames.isNotEmpty ? selectedNames.join(', ') : 'Kategorie werde glade...';
  }
}