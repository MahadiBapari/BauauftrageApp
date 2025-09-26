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

  // Pagination states
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreOrders = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.addListener(_scrollListener);
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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 && !_isFetchingMore && _hasMoreOrders) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isFetchingMore || !_hasMoreOrders) return;
    setState(() {
      _isFetchingMore = true;
    });
    final nextPage = _currentPage + 1;
    final prevOrderCount = _orders.length;
    await _fetchOrders(userId: _userId!, page: nextPage, perPage: _perPage, append: true);
    if (_orders.length > prevOrderCount) {
      _currentPage = nextPage;
    }
    setState(() {
      _isFetchingMore = false;
    });
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
      await _fetchOrders(userId: _userId!, page: 1, perPage: 10, append: false);
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

  Future<void> _fetchOrders({required String userId, required int page, required int perPage, required bool append}) async {
    if (!await isUserAuthenticated()) return;
    if (!append) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = true;
          _filteredOrders.clear();
        });
      }
    }
    List<Map<String, dynamic>> currentFetchedOrders = [];
    try {
      final headers = <String, String>{};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }
      headers['X-API-Key'] = apiKey;
      // Use author, per_page, and page for dynamic pagination
      String url = '$ordersEndpoint?author=$userId&page=$page&per_page=$perPage';
      final response = await SafeHttp.safeGet(context, Uri.parse(url), headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var order in data) {
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
          currentFetchedOrders.add(order);
        }
        if (mounted) {
          setState(() {
            if (append) {
              final existingIds = _orders.map((o) => o['id']).toSet();
              final newOrders = currentFetchedOrders.where((o) => !existingIds.contains(o['id'])).toList();
              _orders.addAll(newOrders);
            } else {
              _orders = currentFetchedOrders;
              _currentPage = 1;
            }
            _hasMoreOrders = data.length == _perPage;
            _filterOrders();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMoreOrders = false;
            if (!append) {
              _orders.clear();
              _filteredOrders.clear();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasMoreOrders = false;
          if (!append) {
            _orders.clear();
            _filteredOrders.clear();
          }
        });
      }
    } finally {
      if (mounted && !append) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
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
      await _fetchOrders(userId: _userId!, page: 1, perPage: 10, append: false);
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
                  color: const Color.fromARGB(255, 160, 36, 36),
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredOrders.length + (_hasMoreOrders ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _filteredOrders.length) {
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
                                } else {
                                  // Show shimmer at the bottom when loading more
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(
                                          height: 48,
                                          width: 180,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
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