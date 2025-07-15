import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Future.wait
import 'package:shared_preferences/shared_preferences.dart';
import 'package:extended_image/extended_image.dart';
import 'package:bauauftrage/core/network/safe_http.dart';
import '../my_order_page/single_myorders_page_screen.dart'; // Ensure this is imported
import '../../../widgets/custom_loading_indicator.dart';
import '../../../utils/cache_manager.dart'; // Assuming you have this Utility
import 'package:bauauftrage/common/utils/auth_utils.dart';

class MyOrdersPageScreen extends StatefulWidget {
  const MyOrdersPageScreen({super.key});

  @override
  _MyOrdersPageScreenState createState() => _MyOrdersPageScreenState();
}

class _MyOrdersPageScreenState extends State<MyOrdersPageScreen> {
  // Loading states
  bool _isLoadingOrders = true;
  bool _isFetchingMore = false; // To track if more orders are being fetched

  // Data lists
  List<Map<String, dynamic>> _orders = []; // Stores raw fetched orders with image URLs
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after search filter

  // Filter/Search states
  String _searchText = ''; // Re-added: Needed for search

  // Pagination states
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreOrders = true; // To check if there are more pages to load

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // API constants
  final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order';
  final String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String apiKey = '1234567890abcdef';

  String? _userId; // To store the logged-in user's ID
  String? _authToken; // For authenticated API calls if needed

  // Add CacheManager instance
  final CacheManager _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _loadOrdersFromCacheThenBackground();
    _scrollController.addListener(_scrollListener); // Add listener for pagination
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrdersFromCacheThenBackground() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _authToken = prefs.getString('auth_token');
    if (_userId == null) {
      setState(() {
        _isLoadingOrders = false;
        _hasMoreOrders = false;
      });
      _showErrorDialog("User Not Logged In", "Please log in to view your orders.");
      return;
    }
    // Try to load from cache first
    final cachedOrdersKey = 'my_orders_$_userId';
    final cachedData = await _cacheManager.loadFromCache(cachedOrdersKey);
    if (cachedData != null) {
      setState(() {
        _orders = List<Map<String, dynamic>>.from(cachedData as List);
        _filterOrders();
        _isLoadingOrders = false;
      });
    }
    // Fetch fresh data in background
    _loadAllData();
  }

  // Listener for scroll events to trigger pagination
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isFetchingMore && _hasMoreOrders) {
      _loadMoreOrders();
    }
  }

  // Combines all initial data fetching operations using Future.wait
  Future<void> _loadAllData() async {
    if (_userId == null) {
      debugPrint("MyOrdersPageScreen: _loadAllData called with null userId. Aborting fetch.");
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingOrders = true; // Ensure loading is true at the start
      });
    }

    try {
      final cachedOrdersKey = 'my_orders_$_userId'; 
      final cachedData = await _cacheManager.loadFromCache(cachedOrdersKey);
      debugPrint('MyOrdersPageScreen: Loaded cached data for $cachedOrdersKey: ${cachedData != null}');

      if (mounted) {
        setState(() {
          if (cachedData != null) {
            _orders = List<Map<String, dynamic>>.from(cachedData as List);
            _filterOrders();
            // Do NOT set _isLoadingOrders to false here. Let the final block handle it.
          }
        });
      }

      final needsRefresh = await _cacheManager.isCacheExpired(cachedOrdersKey);
      debugPrint('MyOrdersPageScreen: Cache for $cachedOrdersKey needs refresh: $needsRefresh');

      if (needsRefresh || _orders.isEmpty) {
        debugPrint('MyOrdersPageScreen: Fetching fresh orders from API...');
        await _fetchOrders(userId: _userId!, page: 1, perPage: _perPage, append: false);
      } else {
        debugPrint('MyOrdersPageScreen: Using cached data for orders. No API fetch needed on initial load.');
      }
    } catch (e) {
      debugPrint('MyOrdersPageScreen: Error in _loadAllData for user $_userId: $e');
      _showErrorDialog("Loading Error", "Could not load data. Please check your internet connection.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false; // Ensure loading state is false after all attempts
        });
      }
    }
  }

  // New method to load more orders for pagination
  Future<void> _loadMoreOrders() async {
    if (_isFetchingMore || !_hasMoreOrders || _userId == null) {
      debugPrint("MyOrdersPageScreen: Skipping loadMoreOrders. isFetchingMore: $_isFetchingMore, hasMoreOrders: $_hasMoreOrders, userId: $_userId");
      return;
    }

    if (mounted) {
      setState(() {
        _isFetchingMore = true;
      });
    }
    _currentPage++;
    debugPrint('MyOrdersPageScreen: Loading more orders. Page: $_currentPage');
    await _fetchOrders(userId: _userId!, page: _currentPage, perPage: _perPage, append: true);

    if (mounted) {
      setState(() {
        _isFetchingMore = false;
      });
    }
  }

  Future<void> _fetchOrders({required String userId, required int page, required int perPage, required bool append}) async {
    if (!await isUserAuthenticated()) return;

    List<Map<String, dynamic>> currentFetchedOrders = [];
    debugPrint('MyOrdersPageScreen: _fetchOrders started for page $page, append: $append');
    try {
      final headers = <String, String>{};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }
      headers['X-API-Key'] = apiKey;

      debugPrint('Fetching orders for userId: $userId');
      final url = Uri.parse('$ordersEndpoint?author=$_userId');
      debugPrint('MyOrdersPageScreen: Fetching orders from URL: $url');
      debugPrint('MyOrdersPageScreen: Fetching orders with headers: $headers');

      final response = await SafeHttp.safeGet(context, url, headers: headers);

      if (!mounted) {
        debugPrint('MyOrdersPageScreen: _fetchOrders: Widget unmounted during API call.');
        return;
      }

      debugPrint('MyOrdersPageScreen: Orders API response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('MyOrdersPageScreen: Orders API response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
      } else {
        debugPrint('MyOrdersPageScreen: Orders API response body (full, for unexpected status): ${response.body}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('MyOrdersPageScreen: Raw data length: [32m${data.length}[0m');
        for (var order in data) {
          debugPrint('Fetched order with id: \u001b[36m[0m, author: \u001b[33m[0m');
          // --- BEGIN CDN IMAGE LOGIC ---
          String cdnUrl = '';
          String originalUrl = '';
          if (order['order_gallery_cdn'] != null &&
              order['order_gallery_cdn'] is List &&
              (order['order_gallery_cdn'] as List).isNotEmpty) {
            final cdnGallery = order['order_gallery_cdn'] as List;
            final firstCdnImage = cdnGallery[0];
            if (firstCdnImage is Map) {
              cdnUrl = firstCdnImage['cdn_url'] ?? '';
              originalUrl = firstCdnImage['original_url'] ?? '';
            }
          }
          order['displayImageUrl'] = cdnUrl;
          order['fallbackImageUrl'] = originalUrl;
          // --- END CDN IMAGE LOGIC ---
          currentFetchedOrders.add(order);
        }

        if (mounted) {
          setState(() {
            if (append) {
              _orders.addAll(currentFetchedOrders);
            } else {
              _orders = currentFetchedOrders;
              _currentPage = page;
            }
            _hasMoreOrders = data.length == _perPage;
            _filterOrders();
            debugPrint('MyOrdersPageScreen: Orders updated. Total _orders: ${_orders.length}, _filteredOrders: ${_filteredOrders.length}');
          });
          if (!append) {
             await _cacheManager.saveToCache('my_orders_$_userId', _orders);
             debugPrint('MyOrdersPageScreen: Orders cached for user $_userId.');
          }
        }
      } else {
        debugPrint('MyOrdersPageScreen: Failed to load orders for user $userId: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _hasMoreOrders = false;
            if (!append) {
              _orders.clear();
              _filteredOrders.clear();
            }
          });
        }
        _showErrorDialog("API Error", "Could not fetch your orders. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('MyOrdersPageScreen: Caught error in _fetchOrders: $e');
      if (mounted) {
        setState(() {
          _hasMoreOrders = false;
          if (!append) {
            _orders.clear();
            _filteredOrders.clear();
          }
        });
      }
      _showErrorDialog("Network Error", "Failed to connect to the server. Please check your internet. Error: $e");
    }
    debugPrint('MyOrdersPageScreen: _fetchOrders finished for page $page.');
  }

  void _filterOrders() {
    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final search = normalize(_searchText);

    if (mounted) {
      setState(() {
        _filteredOrders = _orders.where((order) {
          final title = normalize(order['title']?['rendered'].toString() ?? '');
          return title.contains(search);
        }).toList();
        debugPrint('MyOrdersPageScreen: Filtered orders count: ${_filteredOrders.length}');
      });
    }
  }

  Future<void> _onRefresh() async {
    debugPrint('MyOrdersPageScreen: Performing refresh...');
    if (_userId == null) {
      debugPrint("MyOrdersPageScreen: User ID is null. Cannot refresh user's orders.");
      _showErrorDialog("Refresh Failed", "Please log in to refresh your orders.");
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
      return;
    }

    setState(() {
      _orders.clear();
      _filteredOrders.clear();
      _currentPage = 1;
      _hasMoreOrders = true;
      _isLoadingOrders = true;
      debugPrint('MyOrdersPageScreen: State cleared for refresh. _isLoadingOrders set to true.');
    });

    try {
      await _fetchOrders(userId: _userId!, page: 1, perPage: _perPage, append: false);
    } catch (e) {
      debugPrint('MyOrdersPageScreen: Error during _onRefresh fetch: $e');
      _showErrorDialog("Refresh Error", "Failed to refresh orders. Please try again. Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          debugPrint('MyOrdersPageScreen: _onRefresh finished. _isLoadingOrders set to false.');
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Meine Aufträge",
          style: TextStyle(
            fontSize: 20,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Nach Titel suchen...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _searchText = '';
                                    });
                                  }
                                  _filterOrders();
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
                      ),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            _searchText = value;
                          });
                        }
                        _filterOrders();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _isLoadingOrders && _filteredOrders.isEmpty
                      ? ListView.separated(
                          itemCount: 5,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[300],
                            ),
                          ),
                        )
                      : _filteredOrders.isEmpty
                          ? Center(
                              child: _userId == null 
                                  ? const Text("Bitte melden Sie sich an, um Ihre Aufträge zu sehen.")
                                  : const Text("Keine Aufträge gefunden, die Ihren Kriterien entsprechen."),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredOrders.length + (_hasMoreOrders ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredOrders.length) {
                                  return _isFetchingMore
                                      ? const CustomLoadingIndicator(
                                          size: 30.0,
                                          message: 'Mehr wird geladen...',
                                        )
                                      : const SizedBox.shrink();
                                }

                                final order = _filteredOrders[index];
                                final imageUrl = order['displayImageUrl'] ?? '';
                                final fallbackImageUrl = order['fallbackImageUrl'] ?? '';
                                final title = order['title']['rendered'] ?? 'Untitled';
                                //final categoryName = order['acf']?['category'] ?? 'N/A';

                                return GestureDetector(
                                  onTap: () async {
                                    FocusScope.of(context).unfocus();
                                    final bool? result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SingleMyOrderPageScreen(order: order),
                                      ),
                                    );

                                    if (result == true) {
                                      debugPrint('MyOrdersPageScreen: SingleMyOrderPageScreen returned true. Triggering _onRefresh().');
                                      _onRefresh();
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                          if (imageUrl.isNotEmpty)
                                            Positioned.fill(
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  // Fallback to original URL if CDN fails
                                                  if (fallbackImageUrl.isNotEmpty) {
                                                    return Image.network(
                                                      fallbackImageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300]),
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
                                                        title,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        order['date'] ?? '',
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
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}