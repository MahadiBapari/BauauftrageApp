import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bauauftrage/utils/cache_manager.dart';
import 'package:bauauftrage/core/network/safe_http.dart';



class SingleOrderPageScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SingleOrderPageScreen({super.key, required this.order});

  @override
  State<SingleOrderPageScreen> createState() => _SingleOrderPageScreenState();
}

class _SingleOrderPageScreenState extends State<SingleOrderPageScreen> {
  Map<String, dynamic>? _user;
  List<String> _imageUrls = [];
  Map<int, String> _categoryMap = {};
  List<String> _orderCategories = [];
  bool _isLoading = true;
  bool _isCacheLoaded = false;

  final CacheManager _cacheManager = CacheManager();
  final String mediaUrlBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String usersApiBaseUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/';
  final String categoriesUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String apiKey = '1234567890abcdef';

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenFetch();
  }

  Future<void> _loadFromCacheThenFetch() async {
    final cacheKey = 'single_order_${widget.order['id']}';
    final cachedData = await _cacheManager.loadFromCache(cacheKey);
    if (cachedData != null && cachedData is Map<String, dynamic>) {
      setState(() {
        _user = cachedData['user'];
        _imageUrls = List<String>.from(cachedData['imageUrls'] ?? []);
        _categoryMap = Map<int, String>.from(cachedData['categoryMap'] ?? {});
        _orderCategories = List<String>.from(cachedData['orderCategories'] ?? []);
        _isLoading = false;
        _isCacheLoaded = true;
      });
      // Fetch fresh data in background, but do not set _isLoading to true
      fetchDetails(fromCache: true);
    } else {
      // No cache, show shimmer
      setState(() {
        _isLoading = true;
        _isCacheLoaded = false;
      });
      fetchDetails(fromCache: false);
    }
  }

  Future<void> fetchDetails({bool fromCache = false}) async {
    // Only set loading if not from cache
    if (!fromCache) {
      setState(() {
        _isLoading = true;
      });
    }

    final authorId = widget.order['author'];
    final List<dynamic> galleryDynamic = widget.order['meta']?['order_gallery'] ?? [];
    final List<dynamic> rawCategoryIds = widget.order['order-categories'] ?? [];

    List<int> galleryImageIds = galleryDynamic
    .whereType<Map>()
    .map((item) => item['id'])
    .whereType<int>()
    .toList();

    try {
      List<Future<dynamic>> futures = [
        SafeHttp.safeGet(context, Uri.parse('$usersApiBaseUrl$authorId'), headers: {'X-API-KEY': apiKey}),
        SafeHttp.safeGet(context, Uri.parse(categoriesUrl)),
      ];

      for (int mediaId in galleryImageIds) {
        futures.add(SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId'), headers: {'X-API-KEY': apiKey}));
      }

      List<dynamic> responses = await Future.wait(futures);

      final http.Response userResponse = responses[0];
      Map<String, dynamic>? user;
      if (userResponse.statusCode == 200) {
        user = jsonDecode(userResponse.body);
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
      }

      List<String> imageUrls = [];
      for (int i = 2; i < responses.length; i++) {
        final mediaResponse = responses[i];
        if (mediaResponse.statusCode == 200) {
          final mediaData = jsonDecode(mediaResponse.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null) imageUrls.add(imageUrl);
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
          _categoryMap = categoryMap;
          _orderCategories = orderCategories;
          _isLoading = false;
          _isCacheLoaded = true;
        });
      }
      // Save to cache
      final cacheKey = 'single_order_${widget.order['id']}';
      await _cacheManager.saveToCache(cacheKey, {
        'user': user,
        'imageUrls': imageUrls,
        'categoryMap': categoryMap,
        'orderCategories': orderCategories,
      });
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final meta = order['meta'] ?? {};
    final title = order['title']?['rendered'] ?? 'No title';
    final content = _stripHtml(order['content']?['rendered'] ?? '');

    final userName = _user?['display_name'] ?? 'N/A';
    final userEmail = _user?['user_email'] ?? 'N/A';
    String userPhone = 'N/A';

    if (_user != null) {
      var metaData = _user!['meta_data'];
      if (metaData != null) {
        var phoneList = metaData['user_phone_'];
        if (phoneList is List && phoneList.isNotEmpty) {
          userPhone = phoneList.first.toString();
        }
      }
    }

Future<void> launchPhone(String phoneNumber) async {
  if (phoneNumber.isEmpty || phoneNumber == 'N/A') {
    print("Invalid phone number: $phoneNumber");
    return;
  }

  final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(phoneUri);
  } else {
    print("Could not launch phone call");
  }
}

Future<void> launchEmail(String email) async {
  if (email.isEmpty || email == 'N/A') {
    print("Invalid email: $email");
    return;
  }

  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {'subject': 'Regarding your order'},
  );

  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  } else {
    print("Could not launch email");
  }
}

return Scaffold(
      backgroundColor: Colors.white, 
      body: (_isLoading && !_isCacheLoaded)
          ? _buildShimmer()
          : Stack(
              children: [
                // --- White Background (base layer) ---
                Container(
                  color: Colors.white,
                ),

                // --- Top Image Gallery ---
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
                          child: const Center(child: Text('Keine Bilder verfügbar')),
                        ),
                ),

                // --- Info Card ---
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
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (_orderCategories.isNotEmpty)
                              Text(
                                _orderCategories.join(', '),
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                              const SizedBox(width: 18),
                              Text('$userName',
                                  style: const TextStyle(
                                      color: Color.fromARGB(255, 59, 59, 59),
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold)),
                              
                            ],
                            ),

                          
                          //icons  
                                        Padding(
                                        padding: const EdgeInsets.only(top: 24.0), // Increase this value for more margin
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround, // more space between buttons
                                          children: [
                                          // Email Button 
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(18),
                                            backgroundColor: const Color.fromARGB(0, 202, 180, 180),
                                            elevation: 0,
                                            // shadowColor: Colors.black38,
                                            ),
                                            onPressed: () => launchEmail(userEmail),
                                            child: const Icon(Icons.email, color: Color.fromARGB(255, 185, 7, 7), size: 32),
                                          ),

                                              // Address Popup Button
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(20),
                                            backgroundColor: const Color.fromARGB(0, 255, 255, 255),
                                            elevation: 0,
                                            //shadowColor: Colors.black38,
                                            ),
                                            onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                backgroundColor: Colors.white,
                                                insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(24.0),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.location_on, color: Color.fromARGB(255, 185, 7, 7), size: 28),
                                                          const SizedBox(width: 10),
                                                          const Text(
                                                            'Adresse',
                                                            style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFF222222),
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.grey),
                                                            onPressed: () => Navigator.of(context).pop(),
                                                            splashRadius: 20,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 18),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.home, color: Color(0xFF757575), size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              meta['address_1'] ?? 'N/A',
                                                              style: const TextStyle(fontSize: 16, color: Color(0xFF444444)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.local_post_office, color: Color(0xFF757575), size: 20),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            meta['address_2'] ?? 'N/A',
                                                            style: const TextStyle(fontSize: 16, color: Color(0xFF444444)),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.location_city, color: Color(0xFF757575), size: 20),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            meta['address_3'] ?? 'N/A',
                                                            style: const TextStyle(fontSize: 16, color: Color(0xFF444444)),
                                                          ),
                                                        ],
                                                      ),
                                                     
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                            },
                                            child: const Icon(Icons.location_on, color: Color.fromARGB(255, 185, 7, 7), size: 32),
                                          ),

                                          // Phone Button (now on the right)
                                           ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(18),
                                            backgroundColor: const Color.fromARGB(0, 77, 19, 5),
                                            elevation: 0,
                                            //shadowColor: Colors.black38,
                                            ),
                                            onPressed: () => launchPhone(userPhone),
                                            child: const Icon(Icons.phone, color: Color.fromARGB(255, 185, 7, 7), size: 32),
                                           )
                                          ],
                                        ),
                                        ),

                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 26),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),  


                            const SizedBox(height: 12),
                            Text(content, style: const TextStyle(fontSize: 16)),

                         
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

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
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
