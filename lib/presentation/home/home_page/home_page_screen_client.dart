import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bauauftrage/utils/cache_manager.dart';
import '../my_order_page/single_myorders_page_screen.dart';
import 'package:bauauftrage/widgets/custom_loading_indicator.dart';
import 'package:extended_image/extended_image.dart';
import 'package:bauauftrage/core/network/safe_http.dart';
import '../add_new_order_page/add_new_order_page_screen.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';
import '../partners_page/partners_page_screen.dart';

class HomePageScreenClient extends StatefulWidget {
  final void Function(String categoryId)? onCategorySelected;
  final VoidCallback? onAddOrderRequested;
  const HomePageScreenClient({Key? key, this.onCategorySelected, this.onAddOrderRequested}) : super(key: key);

  @override
  State<HomePageScreenClient> createState() => _HomePageScreenClientState();
}

class _HomePageScreenClientState extends State<HomePageScreenClient> with AutomaticKeepAliveClientMixin<HomePageScreenClient> {
  @override
  bool get wantKeepAlive => true;
  
  final CacheManager _cacheManager = CacheManager();
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  bool _isLoadingPartners = true;
  bool _isLoadingOrders = true;
  
  List<Category> _categories = [];
  List<Partner> _partners = [];
  List<Order> _orders = [];

  // Add user data state variables
  String displayName = "User";
  bool isLoadingUser = true;
  int? currentUserId; // Store the current user ID

  static const String apiKey = '1234567890abcdef';

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenBackground();
  }

  Future<void> _loadFromCacheThenBackground() async {
    // Use cache for instant display
    await Future.wait([
      _loadUserFromCache(),
      _loadCategoriesFromCache(),
      _loadPartnersFromCache(),
      _loadOrdersFromCache(),
    ]);
    // Then fetch fresh data in background (update UI if new data)
    _refreshAllDataInBackground();
  }

  Future<void> _loadUserFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('user_data');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          displayName = cachedData as String;
          isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _loadCategoriesFromCache() async {
    final cachedCategories = await _cacheManager.loadFromCache('categories');
    if (cachedCategories != null && cachedCategories is List && cachedCategories.isNotEmpty) {
      final filtered = cachedCategories.where((c) {
        final id = c['id'];
        final valid = id != null && (id is int || int.tryParse('$id') != null);
        if (!valid) debugPrint('Skipping cached category with invalid id: $id');
        return valid;
      }).toList();
      final categories = filtered.map((c) => Category.fromJson(c)).toList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadPartnersFromCache() async {
    final cachedPartners = await _cacheManager.loadFromCache('partners');
    if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
      final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
      if (mounted) {
        setState(() {
          _partners = partners;
          _isLoadingPartners = false;
        });
      }
    }
  }

  Future<void> _loadOrdersFromCache() async {
    final cachedOrders = await _cacheManager.loadFromCache('orders');
    final prefs = await SharedPreferences.getInstance();
    if (currentUserId == null) {
      final userIdString = prefs.getString('user_id');
      if (userIdString != null) {
        currentUserId = int.tryParse(userIdString);
        debugPrint('Loaded currentUserId from prefs: \\${currentUserId}');
      } else {
        debugPrint('No user_id found in prefs when loading orders from cache.');
      }
    }
    debugPrint('currentUserId in _loadOrdersFromCache: \\${currentUserId}');
    debugPrint('Cached orders loaded: \\${cachedOrders?.length ?? 0}');
    if (cachedOrders != null && cachedOrders is List && cachedOrders.isNotEmpty) {
      debugPrint('Cached orders content: \\${cachedOrders}');
      final orders = cachedOrders.map((o) => Order.fromJson(o)).where((order) {
        if (order.fullOrder != null && currentUserId != null) {
          final author = order.fullOrder!['author'];
          debugPrint('Order author: \\${author}, currentUserId: \\${currentUserId}');
          return author == currentUserId;
        }
        return false;
      }).toList();
      debugPrint('Filtered orders count: \\${orders.length}');
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    } else {
      debugPrint('No cached orders found or cache is empty.');
    }
  }

  Future<void> _refreshAllDataInBackground() async {
    await _fetchUser(forceRefresh: false); // Use cache if available
    await Future.wait([
      _loadCategories(isRefresh: true, forceRefresh: false),
      _loadPartners(forceRefresh: false),
      _loadOrders(forceRefresh: false),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No auto-refresh on navigation; rely on manual refresh only
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
      isLoadingUser = true;
      _isLoadingCategories = true;
      _isLoadingPartners = true;
      _isLoadingOrders = true;
    });
    await _fetchUser(forceRefresh: true); // Always fetch fresh data
    await Future.wait([
      _loadCategories(isRefresh: true, forceRefresh: true),
      _loadPartners(forceRefresh: true),
      _loadOrders(forceRefresh: true),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onRefresh() async {
    await _refreshAllData();
  }

  Future<void> _fetchUser({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    setState(() => isLoadingUser = true);

    try {
      if (!forceRefresh) {
        final cachedData = await _cacheManager.loadFromCache('user_data');
        if (cachedData != null) {
          if (mounted) {
            setState(() {
              displayName = cachedData as String;
              isLoadingUser = false;
            });
          }
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final userIdString = prefs.getString('user_id');
      if (userIdString == null) {
        if (mounted) setState(() => isLoadingUser = false);
        return;
      }
      final int? userId = int.tryParse(userIdString);
      if (userId == null) {
        if (mounted) setState(() => isLoadingUser = false);
        return;
      }
      currentUserId = userId; // Store the user ID
      final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId');
      final response = await SafeHttp.safeGet(context, url, headers: {'X-API-Key': apiKey});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final metaData = data['meta_data'];
        final List<dynamic>? firstNameList = metaData?['first_name'];
        final List<dynamic>? lastNameList = metaData?['last_name'];
        final firstName = (firstNameList != null && firstNameList.isNotEmpty) ? firstNameList[0] : '';
        final lastName = (lastNameList != null && lastNameList.isNotEmpty) ? lastNameList[0] : '';
        final newDisplayName = '${firstName.trim()} ${lastName.trim()}'.trim().isEmpty
            ? 'User'
            : '${firstName.trim()} ${lastName.trim()}';
        if (mounted) {
          setState(() {
            displayName = newDisplayName;
          });
        }
        await _cacheManager.saveToCache('user_data', newDisplayName);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      if (mounted) setState(() => isLoadingUser = false);
    }
  }

  Future<void> _loadCategories({bool isRefresh = false, bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    if (!forceRefresh) {
      final cachedCategories = await _cacheManager.loadFromCache('categories');
      if (cachedCategories != null && cachedCategories is List && cachedCategories.isNotEmpty) {
        final filtered = cachedCategories.where((c) {
          final id = c['id'];
          final valid = id != null && (id is int || int.tryParse('$id') != null);
          return valid;
        }).toList();
        final categories = filtered.map((c) => Category.fromJson(c)).toList();
        if (mounted) {
          setState(() {
            _categories = categories;
            _isLoadingCategories = false;
          });
        }
        return;
      }
    }
    try {
      final response = await SafeHttp.safeGet(
          context,
          Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
          headers: {'X-API-Key': apiKey});
      if (!mounted) return;
      if (response.statusCode == 200) {
        List<dynamic> categoriesData = json.decode(response.body);
        List<_CategoryTemp> tempCategories = [];
        Set<int> mediaIds = {};
        for (var item in categoriesData) {
          if (item['id'] == null ||
              (item['id'] is! int && int.tryParse(item['id'].toString()) == null)) {
            continue;
          }
          final id = item['id'] is int ? item['id'] : int.parse(item['id'].toString());
          final name = item['name'] as String;
          int? imageMediaId;
          final catImage = item['meta']?['cat_image'];
          if (catImage != null && catImage is Map && catImage['id'] != null) {
            if (catImage['id'] is int) {
              imageMediaId = catImage['id'];
            } else if (catImage['id'] is String && int.tryParse(catImage['id']) != null) {
              imageMediaId = int.parse(catImage['id']);
            }
            if (imageMediaId != null) mediaIds.add(imageMediaId);
          }
          tempCategories.add(_CategoryTemp(id: id, name: name, imageMediaId: imageMediaId));
        }
        Map<int, String> mediaUrlMap = {};
        await Future.wait(mediaIds.map((mediaId) async {
          try {
            final mediaResponse = await SafeHttp.safeGet(
                context,
                Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId'),
                headers: {'X-API-Key': apiKey});
            if (mediaResponse.statusCode == 200) {
              final mediaData = json.decode(mediaResponse.body);
              if (mediaData['source_url'] != null) {
                mediaUrlMap[mediaId] = mediaData['source_url'];
              }
            }
          } catch (e) {}
        }));
        List<Category> fetchedCategories = tempCategories
            .map((c) => Category(
                  id: c.id,
                  name: c.name,
                  imageUrl: c.imageMediaId != null ? mediaUrlMap[c.imageMediaId!] : null,
                ))
            .toList();
        if (mounted) {
          setState(() {
            _categories = fetchedCategories;
          });
        }
        await _cacheManager.saveToCache('categories', _categories.map((c) => c.toJson()).toList());
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadPartners({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    setState(() => _isLoadingPartners = true);
    if (!forceRefresh) {
      final cachedPartners = await _cacheManager.loadFromCache('partners');
      if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
        final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
        if (mounted) {
          setState(() {
            _partners = partners;
            _isLoadingPartners = false;
          });
        }
        return;
      }
    }
    try {
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        List<dynamic> partnersData = json.decode(response.body);
        List<Partner> fetchedPartners = [];
        for (var item in partnersData) {
          final title = item['title']?['rendered'] as String? ?? '';
          final address = item['meta']?['adresse'] as String? ?? '';
          String? logoUrl;
          if (item['meta'] != null && 
              item['meta']['logo'] != null && 
              item['meta']['logo'] is Map &&
              item['meta']['logo']['url'] != null) {
            logoUrl = item['meta']['logo']['url'] as String;
          }
          fetchedPartners.add(Partner(
            title: title,
            address: address,
            logoId: item['meta']?['logo']?['id'],
            logoUrl: logoUrl,
          ));
        }
        if (mounted) {
          setState(() {
            _partners = fetchedPartners;
            _isLoadingPartners = false;
          });
        }
        await _cacheManager.saveToCache('partners', fetchedPartners.map((p) => p.toJson()).toList());
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPartners = false);
      }
    }
  }

  Future<void> _loadOrders({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    setState(() => _isLoadingOrders = true);

    try {
      if (!forceRefresh) {
        // Try to load from cache first
        final cachedOrders = await _cacheManager.loadFromCache('orders');
        if (cachedOrders != null && cachedOrders is List && cachedOrders.isNotEmpty) {
          final orders = cachedOrders.map((o) => Order.fromJson(o)).where((order) {
            // Filter by current user
            if (order.fullOrder != null && currentUserId != null) {
              return order.fullOrder!['author'] == currentUserId;
            }
            return false;
          }).toList();
          if (mounted) {
            setState(() {
              _orders = orders;
              _isLoadingOrders = false;
            });
          }
          return;
        }
      }

      // Always fetch fresh data if forceRefresh is true or cache is empty
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?_embed'));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> ordersData = json.decode(response.body);
        List<Order> fetchedOrders = [];

        for (var item in ordersData) {
          final title = item['title']?['rendered'] as String? ?? '';
          final description = item['content']?['rendered'] as String? ?? '';
          final status = item['acf']?['status'] as String? ?? '';
          final date = item['date'] as String? ?? '';
          String? imageUrl;

          // Get the first image from the order gallery
          if (item['meta']?['order_gallery'] != null) {
            final gallery = item['meta']?['order_gallery'];
            if (gallery is List && gallery.isNotEmpty) {
              final firstImage = gallery[0];
              if (firstImage is Map && firstImage['id'] != null) {
                final imageId = firstImage['id'];
                try {
                  final mediaResponse = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$imageId'), headers: {'X-API-KEY': apiKey});
                  if (mediaResponse.statusCode == 200) {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'];
                  }
                } catch (e) {}
              }
            }
          }

          fetchedOrders.add(Order(
            title: title,
            description: description,
            status: status,
            date: date,
            imageUrl: imageUrl,
            fullOrder: item, // Store the complete order data for navigation
          ));
        }

        // Filter by current user
        List<Order> userOrders = fetchedOrders.where((order) {
          if (order.fullOrder != null && currentUserId != null) {
            return order.fullOrder!['author'] == currentUserId;
          }
          return false;
        }).toList();

        if (mounted) {
          setState(() {
            _orders = userOrders;
            _isLoadingOrders = false;
          });
        }

        // Always update cache after fresh fetch
        await _cacheManager.saveToCache('orders', fetchedOrders.map((o) => o.toJson()).toList());
      } else {
        if (mounted) {
          setState(() => _isLoadingOrders = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state alive
    debugPrint('Building HomePageScreenClient');
    debugPrint('Categories count: ${_categories.length}');
    debugPrint('Partners count: ${_partners.length}');
    debugPrint('Orders count: ${_orders.length}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ListView(
                children: [
                  // Welcome Section with Shimmer
                  isLoadingUser
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 200,
                                height: 26,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Willkommen',
                              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                  const SizedBox(height: 24),

                  // Categories Section
                  const Text(
                    'Kategorien',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingCategories
                      ? _buildCategoryShimmer()
                      : _categories.isEmpty
                          ? const Center(child: Text('Kei Kategorie verfügbar oder Ladefehler.'))
                          : SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return _buildCategoryCard(category);
                                },
                              ),
                            ),
                  const SizedBox(height: 24),

                  // Partners Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Unsere Partner',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PartnerScreen()),
                          );
                        },
                        child: const Text(
                          'Alle anzeigen',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 179, 21, 21),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _isLoadingPartners
                      ? _buildPartnerShimmer()
                      : _partners.isEmpty
                          ? const Center(child: Text('Kei Partner verfügbar'))
                          : SizedBox(
                              height: 180,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _partners.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final partner = _partners[index];
                                  return _buildPartnerCard(partner);
                                },
                              ),
                            ),
                  const SizedBox(height: 24),

                  // My Orders Section
                  const Text(
                    'Meine Aufträge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingOrders
                      ? _buildOrderShimmer()
                      : _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Kei Aufträgi verfügbar'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Auftrag erfasse'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color.fromARGB(255, 179, 21, 21),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (widget.onAddOrderRequested != null) {
                                        widget.onAddOrderRequested!();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _orders.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: () {
          widget.onCategorySelected?.call(category.id.toString());
        },
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 100,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 253, 250),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 59, 59, 59).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (category.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: ExtendedImage.network(
                      category.imageUrl!,
                      height: 60,
                      width: 100,
                      fit: BoxFit.cover,
                      cache: true,
                      enableLoadState: true,
                      loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.completed) {
                          return ExtendedRawImage(
                            image: state.extendedImageInfo?.image,
                            fit: BoxFit.cover,
                          );
                        } else if (state.extendedImageLoadState == LoadState.failed) {
                          return Container(
                            height: 60,
                            width: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.category, color: Colors.grey),
                          );
                        }
                        return null;
                      },
                    ),
                  )
                else
                  Container(
                    height: 60,
                    width: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.category, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    debugPrint('Building partner card for: ${partner.title}');
    debugPrint('Partner logo URL: ${partner.logoUrl}');
    debugPrint('Logo URL is empty: ${partner.logoUrl?.isEmpty ?? true}');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to partner details
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 59, 59, 59).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: partner.logoUrl != null && partner.logoUrl!.isNotEmpty
                      ? ExtendedImage.network(
                        partner.logoUrl!,
                        height: 80,
                        width: 100,
                        fit: BoxFit.contain,
                        cache: true,
                        enableLoadState: true,
                        loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.completed) {
                          return ExtendedRawImage(
                          image: state.extendedImageInfo?.image,
                          fit: BoxFit.contain,
                          );
                        } else if (state.extendedImageLoadState == LoadState.failed) {
                          return Container(
                          height: 110,
                          width: 150,
                          color: Colors.grey[200],
                          child: const Icon(Icons.business, size: 60, color: Colors.grey),
                          );
                        }
                        return null;
                        },
                      )
                    : Container(
                        height: 110,
                        width: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.business, size: 60, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  partner.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return InkWell(
      onTap: () async {
        debugPrint('Order card tapped. fullOrder: \\${order.fullOrder}');
        if (order.fullOrder != null) {
          debugPrint('Navigating to SingleMyOrderPageScreen with order: \\${order.fullOrder}');
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SingleMyOrderPageScreen(order: order.fullOrder!),
            ),
          );
          if (result == true) {
            // Order was deleted, refresh orders
            await _refreshAllData(); // or await _loadOrders();
          }
        } else {
          debugPrint('Order fullOrder is null, not navigating.');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (order.imageUrl != null && order.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    order.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300]),
                  ),
                ),
              // Full overlay across the whole card
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(172, 0, 0, 0).withOpacity(0.4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.date,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartnerShimmer() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderShimmer() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class Category {
  final int id;
  final String name;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int? safeId;
    if (rawId is int) {
      safeId = rawId;
    } else if (rawId is String) {
      safeId = int.tryParse(rawId);
    }
    return Category(
      id: safeId ?? 0, // Use 0 if id is null or not convertible
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class Partner {
  final String title;
  final String address;
  final int? logoId;
  final String? logoUrl;

  Partner({
    required this.title,
    required this.address,
    this.logoId,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'logoId': logoId,
      'logoUrl': logoUrl,
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      title: json['title'] as String,
      address: json['address'] as String,
      logoId: json['logoId'] as int?,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class Order {
  final String title;
  final String description;
  final String status;
  final String date;
  final String? imageUrl;
  final Map<String, dynamic>? fullOrder;

  Order({
    required this.title,
    required this.description,
    required this.status,
    required this.date,
    this.imageUrl,
    this.fullOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'date': date,
      'imageUrl': imageUrl,
      'fullOrder': fullOrder,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      date: json['date'] as String,
      imageUrl: json['imageUrl'] as String?,
      fullOrder: json['fullOrder'] as Map<String, dynamic>?,
    );
  }
}

// Helper class for temp category data
class _CategoryTemp {
  final int id;
  final String name;
  final int? imageMediaId;
  _CategoryTemp({required this.id, required this.name, this.imageMediaId});
}
