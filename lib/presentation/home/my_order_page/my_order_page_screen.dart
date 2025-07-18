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
import 'package:shimmer/shimmer.dart';
import '../main_screen.dart'; // Assuming you have this screen

class MyOrdersPageScreen extends StatefulWidget {
  const MyOrdersPageScreen({super.key});

  @override
  _MyOrdersPageScreenState createState() => _MyOrdersPageScreenState();
}

class _MyOrdersPageScreenState extends State<MyOrdersPageScreen> {
  // Loading states
  bool _isLoadingOrders = true;

  // Data lists
  List<Map<String, dynamic>> _orders = []; // Stores raw fetched orders with image URLs
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after search filter

  // Filter/Search states
  String _searchText = ''; // Re-added: Needed for search

  // No pagination, so no scroll controller needed

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
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always refresh orders when the page is shown
    _loadAllData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _authToken = prefs.getString('auth_token');
    if (_userId == null) {
      setState(() {
        _isLoadingOrders = false;
      });
      _showErrorDialog("User Not Logged In", "Please log in to view your orders.");
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingOrders = true;
      });
    }
    try {
      await _fetchOrders(userId: _userId!);
    } catch (e) {
      debugPrint('MyOrdersPageScreen: Error in _loadAllData for user $_userId: $e');
      _showErrorDialog("Loading Error", "Could not load data. Please check your internet connection.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _fetchOrders({required String userId}) async {
    if (!await isUserAuthenticated()) return;

    List<Map<String, dynamic>> currentFetchedOrders = [];
    debugPrint('MyOrdersPageScreen: _fetchOrders started for userId: $userId');
    try {
      final headers = <String, String>{};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }
      headers['X-API-Key'] = apiKey;

      debugPrint('Fetching orders for userId: $userId');
      final url = Uri.parse('$ordersEndpoint?author=$_userId'); // No pagination params
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
            _orders = currentFetchedOrders;
            _filterOrders();
            debugPrint('MyOrdersPageScreen: Orders updated. Total _orders: ${_orders.length}, _filteredOrders: ${_filteredOrders.length}');
          });
          await _cacheManager.saveToCache('my_orders_$_userId', _orders);
          debugPrint('MyOrdersPageScreen: Orders cached for user $_userId.');
        }
      } else {
        debugPrint('MyOrdersPageScreen: Failed to load orders for user $userId: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _orders.clear();
            _filteredOrders.clear();
          });
        }
        _showErrorDialog("API Error", "Could not fetch your orders. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('MyOrdersPageScreen: Caught error in _fetchOrders: $e');
      if (mounted) {
        setState(() {
          _orders.clear();
          _filteredOrders.clear();
        });
      }
      _showErrorDialog("Network Error", "Failed to connect to the server. Please check your internet. Error: $e");
    }
    debugPrint('MyOrdersPageScreen: _fetchOrders finished for userId: $userId.');
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
      _isLoadingOrders = true;
      debugPrint('MyOrdersPageScreen: State cleared for refresh. _isLoadingOrders set to true.');
    });

    try {
      await _fetchOrders(userId: _userId!);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MainScreen(role: 'um_client'),
              ),
              (Route<dynamic> route) => false,
            );
          },
        ),
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
                          itemBuilder: (context, index) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[300],
                              ),
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                final imageUrl = order['displayImageUrl'] ?? '';
                                final fallbackImageUrl = order['fallbackImageUrl'] ?? '';
                                final title = order['title']['rendered'] ?? 'Untitled';

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