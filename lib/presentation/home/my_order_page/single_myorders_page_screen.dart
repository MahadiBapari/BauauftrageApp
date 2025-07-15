import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_order_page_screen.dart';
import 'package:bauauftrage/utils/cache_manager.dart';
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';

class SingleMyOrderPageScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SingleMyOrderPageScreen({super.key, required this.order});

  @override
  State<SingleMyOrderPageScreen> createState() => _SingleMyOrderPageScreenState();
}

class _SingleMyOrderPageScreenState extends State<SingleMyOrderPageScreen> {
  Map<String, dynamic>? _user;
  List<String> _imageUrls = [];
  List<String> _orderCategories = [];
  bool _isLoading = true;
  bool _isCacheLoaded = false;

  Map<String, dynamic> _currentOrderData = {}; // Store a mutable copy of the order data
  final CacheManager _cacheManager = CacheManager();

  final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order/';
  final String mediaUrlBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String usersApiBaseUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/';
  final String categoriesUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String apiKey = '1234567890abcdef';

  String? _authToken;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _currentOrderData = Map<String, dynamic>.from(widget.order); // Initialize with widget data
    _loadAuthTokenAndUserId().then((_) {
      _loadFromCacheThenFetch();
    });
  }

  Future<void> _loadAuthTokenAndUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
  }

  Future<void> _loadFromCacheThenFetch() async {
    final cacheKey = 'single_myorder_${_currentOrderData['id']}';
    final cachedData = await _cacheManager.loadFromCache(cacheKey);
    if (cachedData != null && cachedData is Map<String, dynamic>) {
      setState(() {
        _user = cachedData['user'];
        _imageUrls = List<String>.from(cachedData['imageUrls'] ?? []);
        _orderCategories = List<String>.from(cachedData['orderCategories'] ?? []);
        _isLoading = false;
        _isCacheLoaded = true;
      });
    }
    fetchDetails(); // Always fetch fresh in background
  }

  Future<void> fetchDetails({bool fromCache = false}) async {
    if (!await isUserAuthenticated()) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final orderId = _currentOrderData['id'];

    try {
      debugPrint('SingleMyOrderPageScreen: Fetching latest order data for ID: $orderId');
      final orderResponse = await http.get(
        Uri.parse('$ordersEndpoint$orderId'),
        headers: {'X-API-KEY': apiKey},
      );

      if (!mounted) return;

      if (orderResponse.statusCode == 200) {
        _currentOrderData = jsonDecode(orderResponse.body); // Update _currentOrderData
        debugPrint('SingleMyOrderPageScreen: Successfully fetched latest order data.');
      } else {
        debugPrint('SingleMyOrderPageScreen: Failed to fetch latest order data: ${orderResponse.statusCode} ${orderResponse.body}');
        // If the order no longer exists (e.g., was deleted by another user), pop back
        if (orderResponse.statusCode == 404) {
          _showInfoDialog('Auftrag nicht gefunden', 'Dieser Auftrag wurde möglicherweise gelöscht. Rückkehr zur Auftragsliste.');
          Navigator.of(context).pop(true); // Pop back and refresh list
          return;
        }
        _showErrorDialog('Fehler', 'Fehler beim Laden der aktuellen Auftragsdetails. Status: ${orderResponse.statusCode}');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Now use the updated _currentOrderData for subsequent fetches
      final authorId = _currentOrderData['author'];
      final dynamic galleryDynamic = _currentOrderData['meta']?['order_gallery'];
      final List<dynamic> rawCategoryIds = _currentOrderData['order-categories'] ?? [];

      List<int> galleryImageIds = [];
      if (galleryDynamic is List) {
        galleryImageIds = galleryDynamic
            .whereType<Map>()
            .map((item) => item['id'])
            .whereType<int>()
            .toList();
      } else if (galleryDynamic is String) {
        try {
          final decodedContent = jsonDecode(galleryDynamic);
          if (decodedContent is List) {
            galleryImageIds = decodedContent
                .whereType<Map>()
                .map((item) => item['id'])
                .whereType<int>()
                .toList();
          } else {
            debugPrint('SingleMyOrderPageScreen: galleryDynamic is a String, but not a JSON list: $galleryDynamic');
          }
        } catch (e) {
          debugPrint('SingleMyOrderPageScreen: Could not parse gallery string as JSON: $e, original string: $galleryDynamic');
        }
      } else {
        debugPrint('SingleMyOrderPageScreen: order_gallery is neither List nor String type: ${galleryDynamic.runtimeType}');
      }


      List<Future<dynamic>> futures = [
        SafeHttp.safeGet(context, Uri.parse('$usersApiBaseUrl$authorId'), headers: {'X-API-KEY': apiKey}),
        SafeHttp.safeGet(context, Uri.parse(categoriesUrl)),
      ];

      for (int mediaId in galleryImageIds) {
        futures.add(SafeHttp.safeGet(context, Uri.parse('$mediaUrlBase$mediaId'), headers: {'X-API-KEY': apiKey}));
      }

      List<dynamic> responses = await Future.wait(futures);

      final http.Response userResponse = responses[0];
      Map<String, dynamic>? user;
      if (userResponse.statusCode == 200) {
        user = jsonDecode(userResponse.body);
      } else {
        debugPrint('SingleMyOrderPageScreen: Failed to fetch user: ${userResponse.statusCode} ${userResponse.body}');
      }

      final http.Response categoriesResponse = responses[1];
      Map<int, String> categoryMap = {};
      if (categoriesResponse.statusCode == 200) {
        List<dynamic> categories = jsonDecode(categoriesResponse.body);
        for (var cat in categories) {
          if (cat['id'] is int && cat['name'] is String) {
            categoryMap[cat['id']] = cat['name'];
          }
        }
      } else {
        debugPrint('SingleMyOrderPageScreen: Failed to fetch categories: ${categoriesResponse.statusCode} ${categoriesResponse.body}');
      }

      List<String> imageUrls = [];
      for (int i = 2; i < responses.length; i++) {
        final mediaResponse = responses[i];
        if (mediaResponse.statusCode == 200) {
          final mediaData = jsonDecode(mediaResponse.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null) imageUrls.add(imageUrl);
        } else {
          debugPrint('SingleMyOrderPageScreen: Failed to fetch media for ID ${galleryImageIds[i - 2]}: ${mediaResponse.statusCode}');
        }
      }

      List<String> orderCategories = [];
      for (var id in rawCategoryIds) {
        if (id is int) {
          orderCategories.add(categoryMap[id] ?? 'Unknown Category');
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _imageUrls = imageUrls;
          _orderCategories = orderCategories;
          _isLoading = false;
          _isCacheLoaded = true;
        });
        debugPrint('SingleMyOrderPageScreen: Details fetched and state updated.');
      }
      // Save to cache
      final cacheKey = 'single_myorder_${_currentOrderData['id']}';
      await _cacheManager.saveToCache(cacheKey, {
        'user': user,
        'imageUrls': imageUrls,
        'orderCategories': orderCategories,
      });
    } catch (e) {
      debugPrint('SingleMyOrderPageScreen: Error fetching details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog('Fehler', 'Fehler beim Laden der Auftragsdetails. Bitte überprüfen Sie Ihre Internetverbindung.');
    }
  }

  void _editOrder(BuildContext context) async {
    if (_authToken == null) {
      _showErrorDialog('Authentifizierung erforderlich', 'Bitte melden Sie sich an, um Aufträge zu bearbeiten.');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditOrderPageScreen(order: _currentOrderData),
      ),
    );

    if (result == true) {
      debugPrint('SingleMyOrderPageScreen: EditOrderPageScreen returned true. Re-fetching details and popping to MyOrdersPageScreen.');
      await fetchDetails();
      Navigator.of(context).pop(true);
    } else {
      debugPrint('SingleMyOrderPageScreen: EditOrderPageScreen returned null or false.');
    }
  }

  Future<void> _deleteOrder(BuildContext context, int orderId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 48),
              const SizedBox(height: 16),
              const Text(
                'Lösche bestätige',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bisch sicher, dass de die Bshtellig wotsch lösche? Das cha nöd rückgängig gmacht werde.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Abbräche'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Lösche'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmDelete == true) {
      if (_authToken == null || _userId == null) {
        _showErrorDialog('Authentifizierungsfehler', 'Sie sind nicht berechtigt, Aufträge zu löschen.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final response = await SafeHttp.safeDelete(context, Uri.parse('$ordersEndpoint$orderId'), headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
          'X-API-KEY': apiKey,
        });

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          debugPrint('SingleMyOrderPageScreen: Order $orderId deleted successfully!');
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Erfolg'),
              content: const Text('D Bshtellig isch erfolgriich glöscht worde.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Guet'),
                ),
              ],
            ),
          );
          debugPrint('SingleMyOrderPageScreen: Popping with true after successful deletion.');
          Navigator.of(context).pop(true);
        } else {
          debugPrint('SingleMyOrderPageScreen: Failed to delete order $orderId: ${response.statusCode} ${response.body}');
          _showErrorDialog('Fehler', 'Löschen fehlgeschlagen. Status: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('SingleMyOrderPageScreen: Error deleting order $orderId: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _showErrorDialog('Fehler', 'Fehler beim Löschen ist ein Fehler aufgetreten: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 48),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 48),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _currentOrderData['meta'] ?? {};
    final title = _currentOrderData['title']?['rendered'] ?? 'No title';
    final content = _stripHtml(_currentOrderData['content']?['rendered'] ?? '');

    // Construct the full address string
    final String address1 = meta['address_1'] ?? '';
    final String address2 = meta['address_2'] ?? ''; // Postal Code
    final String address3 = meta['address_3'] ?? ''; // City

    List<String> addressParts = [];
    if (address1.isNotEmpty) addressParts.add(address1);
    if (address2.isNotEmpty) addressParts.add(address2);
    if (address3.isNotEmpty) addressParts.add(address3);

    final String fullAddress = addressParts.join(', ');

    final userName = _user?['display_name'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      body: (_isLoading && !_isCacheLoaded)
          ? _buildShimmer()
          : Stack(
              children: [
                Container(
                  color: Colors.white,
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  width: double.infinity,
                  child: _imageUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: _imageUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenGallery(
                                      images: _imageUrls,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: _imageUrls[index],
                                child: CachedNetworkImage(
                                  imageUrl: _imageUrls[index],
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      const Center(child: CircularProgressIndicator()),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Center(child: Text('No images available')),
                        ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.43,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_orderCategories.isNotEmpty)
                                Text(
                                  _orderCategories.join(', '),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              const Spacer(),
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 59, 59, 59),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // const Divider(),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color.fromARGB(255, 185, 7, 7), size: 32),
                                  onPressed: () => _editOrder(context),
                                  tooltip: 'Edit Order',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color.fromARGB(255, 185, 7, 7), size: 32),
                                  onPressed: () => _deleteOrder(context, _currentOrderData['id']),
                                  tooltip: 'Delete Order',
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4), // Small spacing
                          if (fullAddress.isNotEmpty) // Display address if available
                            Text(
                              fullAddress,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(content, style: const TextStyle(fontSize: 16, color: Color.fromARGB(221, 34, 34, 34))),
                          const SizedBox(height: 20),

                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.5,
          width: double.infinity,
          color: Colors.grey[300],
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 120, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Container(height: 24, width: 200, color: Colors.grey[300]),
                  const SizedBox(height: 24),
                  Container(height: 16, width: double.infinity, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(height: 16, width: double.infinity, color: Colors.grey[300]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

class FullScreenGallery extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({super.key, required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: PageController(initialPage: initialIndex),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}