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
import '../my_order_page/my_order_page_screen.dart';

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
    setState(() {
      _isLoadingOrders = true;
      _isLoadingCategories = true;
    });
    await Future.wait([
      _loadOrders(forceRefresh: true),
      _loadCategories(forceRefresh: true),
    ]);
    setState(() {
      _isLoadingOrders = false;
      _isLoadingCategories = false;
    });
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
        String firmName = "";
        if (data['meta_data'] != null &&
            data['meta_data']['firmenname'] != null &&
            data['meta_data']['firmenname'] is List &&
            data['meta_data']['firmenname'].isNotEmpty) {
          firmName = data['meta_data']['firmenname'][0] ?? "";
        }
        if (firmName.isEmpty) {
          firmName = data['display_name'] ?? "";
        }
        if (mounted) {
          setState(() {
            displayName = firmName;
            isLoadingUser = false;
          });
        }
        await _cacheManager.saveToCache('user_data', firmName);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
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
        List<Category> fetchedCategories = categoriesData.map((item) {
          return Category.fromJson(item as Map<String, dynamic>);
        }).toList();
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
          String? logoCdnUrl;
          String? logoOriginalUrl;
          int? logoId;
          if (item['logo_cdn'] != null && item['logo_cdn'] is Map) {
            final logoCdn = item['logo_cdn'] as Map;
            logoCdnUrl = logoCdn['cdn_url'] as String?;
            logoOriginalUrl = logoCdn['original_url'] as String?;
            logoId = logoCdn['id'] as int?;
          }
          fetchedPartners.add(Partner(
            title: title,
            address: address,
            logoId: logoId,
            logoCdnUrl: logoCdnUrl,
            logoOriginalUrl: logoOriginalUrl,
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
              _isLoadingOrders = true;
            });
          }
          return;
        }
      }

      // Always fetch fresh data if forceRefresh is true or cache is empty
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order'));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> ordersData = json.decode(response.body);
        List<Order> fetchedOrders = [];

        for (var item in ordersData) {
          final title = item['title']?['rendered'] as String? ?? '';
          final description = item['content']?['rendered'] as String? ?? '';
          final status = item['acf']?['status'] as String? ?? '';
          final date = item['date'] as String? ?? '';
          // Pass through order_gallery_cdn in fullOrder
          final fullOrder = Map<String, dynamic>.from(item);
          fetchedOrders.add(Order(
            title: title,
            description: description,
            status: status,
            date: date,
            imageUrl: null, // Not used, handled in _buildOrderCard
            fullOrder: fullOrder,
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
                  isLoadingUser && displayName == "User"
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
                  _isLoadingCategories && _categories.isEmpty
                      ? SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        )
                      : _categories.isEmpty
                          ? const Center(child: Text('Kei Kategorie verfügbar oder Ladefehler.'))
                          : SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildCategoryCard(category),
                                  );
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
                  _isLoadingPartners && _partners.isEmpty
                      ? SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 4,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        )
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meine Aufträge',
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
                              builder: (_) => MyOrdersPageScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Alle Aufträge',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 179, 21, 21),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _isLoadingOrders && _orders.isEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 3,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        )
                      : _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Kei Aufträgi verfügbar'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Auftrag erfassen'),
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
                              itemCount: _orders.length > 5 ? 5 : _orders.length,
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

    final cdnUrl = category.catImageCdn?['cdn_url'] as String?;
    final originalUrl = category.catImageCdn?['original_url'] as String?;
    return InkWell(
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
                color: const Color.fromARGB(255, 110, 110, 110).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cdnUrl != null && cdnUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    cdnUrl,
                    height: 60,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      if (originalUrl != null && originalUrl.isNotEmpty) {
                        return Image.network(
                          originalUrl,
                          height: 60,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 60,
                            width: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.category, color: Colors.grey),
                          ),
                        );
                      }
                      return Container(
                        height: 60,
                        width: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.category, color: Colors.grey),
                      );
                    },
                  ),
                )
              else if (originalUrl != null && originalUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    originalUrl,
                    height: 60,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 60,
                      width: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.category, color: Colors.grey),
                    ),
                  ),
                )
              else if (category.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    category.imageUrl!,
                    height: 60,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 60,
                      width: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.category, color: Colors.grey),
                    ),
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
              Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
                color: const Color.fromARGB(255, 99, 99, 99).withOpacity(0.15),
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
                child: partner.logoCdnUrl != null && partner.logoCdnUrl!.isNotEmpty
                      ? Image.network(
                          partner.logoCdnUrl!,
                          height: 80,
                          width: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            if (partner.logoOriginalUrl != null && partner.logoOriginalUrl!.isNotEmpty) {
                              return Image.network(
                                partner.logoOriginalUrl!,
                                height: 80,
                                width: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 110,
                                    width: 150,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.business, size: 60, color: Colors.grey),
                                  );
                                },
                              );
                            }
                            return Container(
                              height: 110,
                              width: 150,
                              color: Colors.grey[200],
                              child: const Icon(Icons.business, size: 60, color: Colors.grey),
                            );
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
        FocusScope.of(context).unfocus();
        if (order.fullOrder != null) {
          final bool? result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SingleMyOrderPageScreen(order: order.fullOrder!),
            ),
          );
          if (result == true) {
            debugPrint('HomePageScreenClient: SingleMyOrderPageScreen returned true. Triggering _onRefresh().');
            _onRefresh();
          }
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
              if (order.fullOrder != null &&
                  order.fullOrder!['order_gallery_cdn'] != null &&
                  order.fullOrder!['order_gallery_cdn'] is List &&
                  (order.fullOrder!['order_gallery_cdn'] as List).isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    order.fullOrder!['order_gallery_cdn'][0]['cdn_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      final fallbackUrl = order.fullOrder!['order_gallery_cdn'][0]['original_url'] ?? '';
                      if (fallbackUrl.isNotEmpty) {
                        return Image.network(
                          fallbackUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.grey[300]);
                          },
                        );
                      }
                      return Container(color: Colors.grey[300]);
                    },
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
  final Map<String, dynamic>? catImageCdn;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
    this.catImageCdn,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'cat_image_cdn': catImageCdn,
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
      id: safeId ?? 0,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      catImageCdn: json['cat_image_cdn'] as Map<String, dynamic>?,
    );
  }
}

class Partner {
  final String title;
  final String address;
  final int? logoId;
  final String? logoCdnUrl;
  final String? logoOriginalUrl;

  Partner({
    required this.title,
    required this.address,
    this.logoId,
    this.logoCdnUrl,
    this.logoOriginalUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'logoId': logoId,
      'logoCdnUrl': logoCdnUrl,
      'logoOriginalUrl': logoOriginalUrl,
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      title: json['title'] as String,
      address: json['address'] as String,
      logoId: json['logoId'] as int?,
      logoCdnUrl: json['logoCdnUrl'] as String? ?? (json['logo_cdn']?['cdn_url'] as String?),
      logoOriginalUrl: json['logoOriginalUrl'] as String? ?? (json['logo_cdn']?['original_url'] as String?),
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
