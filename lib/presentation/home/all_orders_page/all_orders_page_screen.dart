import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Future.wait
import 'package:shared_preferences/shared_preferences.dart';
import 'package:extended_image/extended_image.dart';
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';

// Ensure this is imported if used for images
import 'single_order_page_screen.dart'; // Ensure this is imported
import '../../../widgets/membership_required_dialog.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../../utils/cache_manager.dart';

class AllOrdersPageScreen extends StatefulWidget {
  const AllOrdersPageScreen({super.key});

  @override
  _AllOrdersPageScreenState createState() => _AllOrdersPageScreenState();
}

class _AllOrdersPageScreenState extends State<AllOrdersPageScreen> {
  // Loading states
  bool _isLoadingOrders = true;
  bool _isLoadingCategories = true;
  bool _isFetchingMore = false; // New: To track if more orders are being fetched

  // Data lists
  List<Map<String, dynamic>> _orders = []; // Stores raw fetched orders with image URLs
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after search/category filter
  List<Map<String, dynamic>> _categories = []; // Stores fetched categories with ID and Name

  // Filter/Search states
  int? _selectedCategoryId; // null for "All Categories"
  String _searchText = '';

  // Pagination states
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreOrders = true; // New: To check if there are more pages to load

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // API constants
  final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?per_page=100';
  final String categoriesEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100';
  final String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String apiKey = '1234567890abcdef'; // Assuming API key needed for user data

  // Add membership state
  bool _isActiveMembership = false;
  bool _isLoadingMembership = true;
  final String _membershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user-membership';

  // Add CacheManager instance
  final CacheManager _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _loadAllDataFromCacheThenBackground();
    _scrollController.addListener(_scrollListener); // Add listener for pagination
    _fetchMembershipStatus(); // Add membership check
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Listener for scroll events to trigger pagination
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isFetchingMore && _hasMoreOrders) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadAllDataFromCacheThenBackground() async {
    setState(() {
      _isLoadingOrders = true;
      _isLoadingCategories = true;
    });
    // Load from cache first
    final cachedOrders = await _cacheManager.loadFromCache('all_orders');
    final cachedCategories = await _cacheManager.loadFromCache('categories');
    if (cachedOrders != null) {
      _orders = List<Map<String, dynamic>>.from(cachedOrders as List);
      _filterOrders();
      setState(() => _isLoadingOrders = false);
    }
    if (cachedCategories != null) {
      // 1. Convert to the right type
      var processedCategories = (cachedCategories as List).map((cat) {
        dynamic id = cat['id'];
        if (id is String) {
          id = int.tryParse(id);
        }
        return {'id': id, 'name': cat['name'] as String};
      }).toList();

      // 2. Ensure 'All Categories' is present and at the top
      processedCategories.removeWhere((cat) => cat['id'] == null);
      processedCategories.insert(0, {'id': null, 'name': 'Alle Kategorien'});

      _categories = processedCategories;
      setState(() => _isLoadingCategories = false);
    }
    // Fetch fresh data in background
    _loadAllData();
  }

  // Combines all initial data fetching operations using Future.wait
  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _isLoadingOrders = true;
        _isLoadingCategories = true;
      });
    }

    try {
      // Load from cache first
      final cachedData = await Future.wait([
        _cacheManager.loadFromCache('all_orders'),
        _cacheManager.loadFromCache('categories'),
      ]);

      if (mounted) {
        setState(() {
          if (cachedData[0] != null) {
            _orders = List<Map<String, dynamic>>.from(cachedData[0] as List);
            _filterOrders(); // <--- Call filterOrders immediately after loading from cache
          }
          if (cachedData[1] != null) {
            // 1. Convert to the right type
            var processedCategories = (cachedData[1] as List).map((cat) {
              dynamic id = cat['id'];
              if (id is String) {
                id = int.tryParse(id);
              }
              return {'id': id, 'name': cat['name'] as String};
            }).toList();

            // 2. Ensure 'All Categories' is present and at the top
            processedCategories.removeWhere((cat) => cat['id'] == null);
            processedCategories.insert(0, {'id': null, 'name': 'All Categories'});
            
            _categories = processedCategories;
            _isLoadingCategories = false;
          }
        });
      }

      // Check if cache is expired
      final needsRefresh = await Future.wait([
        _cacheManager.isCacheExpired('all_orders'),
        _cacheManager.isCacheExpired('categories'),
      ]);

      // Refresh only if cache is expired or if data was not loaded from cache
      bool shouldFetchOrders = needsRefresh[0] || _orders.isEmpty;
      bool shouldFetchCategories = needsRefresh[1] || _categories.isEmpty;

      List<Future<void>> fetchFutures = [];
      if (shouldFetchOrders) {
        fetchFutures.add(_fetchOrders(page: 1, perPage: _perPage, append: false));
      }
      if (shouldFetchCategories) {
        fetchFutures.add(_fetchCategories());
      }
      
      await Future.wait(fetchFutures); // Await only the necessary fetches

    } catch (e) {
      debugPrint('Error loading all data: $e');
      // Potentially show a global error dialog if initial load fails completely
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false; // Ensure loading is false after all attempts
          _isLoadingCategories = false; // Ensure loading is false after all attempts
        });
      }
    }
  }

  // New method to load more orders for pagination
  Future<void> _loadMoreOrders() async {
    if (_isFetchingMore || !_hasMoreOrders) { // No need for _userId here as it's not a user-specific order list
      debugPrint("Skipping loadMoreOrders. isFetchingMore: $_isFetchingMore, hasMoreOrders: $_hasMoreOrders");
      return;
    }

    if (mounted) {
      setState(() {
        _isFetchingMore = true;
      });
    }
    _currentPage++;
    await _fetchOrders(page: _currentPage, perPage: _perPage, append: true);

    if (mounted) {
      setState(() {
        _isFetchingMore = false;
      });
    }
  }

  Future<void> _fetchOrders({required int page, required int perPage, required bool append}) async {
    if (!await isUserAuthenticated()) return;

    if (!append) {
      // For a new fetch (not pagination), we should show a full loading indicator.
      if (mounted) {
        setState(() {
          _isLoadingOrders = true;
          _filteredOrders.clear(); // Clear existing to show loader
        });
      }
    }

    List<Map<String, dynamic>> currentFetchedOrders = [];
    debugPrint('AllOrdersPageScreen: Fetching orders for page $page, append: $append');
    try {
      final headers = <String, String>{};
      
      // Add category filter to API call if a category is selected
      String url = '$ordersEndpoint?page=$page&per_page=$perPage';
      if (_selectedCategoryId != null) {
        url += '&order-categories=$_selectedCategoryId';
      }

      final response = await SafeHttp.safeGet(context, Uri.parse(url), headers: headers);

      if (!mounted) {
        debugPrint('AllOrdersPageScreen: Widget unmounted during orders API call.');
        return;
      }

      debugPrint('AllOrdersPageScreen: Orders API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('AllOrdersPageScreen: Raw data length: ${data.length}');

        for (var order in data) {
          String imageUrl = '';
          dynamic galleryDynamic = order['meta']?['order_gallery']; // Can be List or String

          List<dynamic> galleryList = [];
          if (galleryDynamic is List) {
            galleryList = galleryDynamic;
          } else if (galleryDynamic is String) {
            try {
              final decodedContent = jsonDecode(galleryDynamic);
              if (decodedContent is List) {
                galleryList = decodedContent;
              }
            } catch (e) {
              debugPrint('AllOrdersPageScreen: Could not parse gallery string: $e');
            }
          }

          if (galleryList.isNotEmpty) {
            dynamic firstItem = galleryList[0];
            int? firstImageId;

            if (firstItem is Map && firstItem.containsKey('id') && firstItem['id'] is int) {
              firstImageId = firstItem['id'];
            } else if (firstItem is int) {
              firstImageId = firstItem;
            } else if (firstItem is String) {
              firstImageId = int.tryParse(firstItem);
            }

            if (firstImageId != null) {
              final mediaUrl = '$mediaEndpointBase$firstImageId';
              final mediaResponse = await SafeHttp.safeGet(context, Uri.parse(mediaUrl));

              if (!mounted) {
                debugPrint('AllOrdersPageScreen: Widget unmounted during media API call.');
                return;
              }

              if (mediaResponse.statusCode == 200) {
                try {
                  final mediaData = jsonDecode(mediaResponse.body);
                  imageUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'] ?? '';
                } catch (e) {
                  debugPrint('AllOrdersPageScreen: Error decoding media data for ID $firstImageId: $e');
                }
              } else {
                debugPrint('AllOrdersPageScreen: Failed to fetch media for ID $firstImageId: ${mediaResponse.statusCode}');
              }
            }
          }
          order['imageUrl'] = imageUrl;
          currentFetchedOrders.add(order);
        }

        if (mounted) {
          setState(() {
            if (append) {
              _orders.addAll(currentFetchedOrders); // Append for pagination
            } else {
              _orders = currentFetchedOrders; // Overwrite for initial load/refresh
              _currentPage = 1; // Reset current page for fresh fetch
              _cacheManager.saveToCache('all_orders', currentFetchedOrders); // Save to cache
              debugPrint('AllOrdersPageScreen: Orders cached.');
            }
            _hasMoreOrders = data.length == _perPage; // Check if more pages exist
            _filterOrders(); // <--- Call filterOrders after _orders is updated
          });
        }
      } else {
        debugPrint('AllOrdersPageScreen: Failed to load orders: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _hasMoreOrders = false;
            // Clear orders if API call failed completely, preventing old data from showing
            if (!append) {
              _orders.clear();
              _filteredOrders.clear();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('AllOrdersPageScreen: Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _hasMoreOrders = false;
          // Clear orders on network error
          if (!append) {
            _orders.clear();
            _filteredOrders.clear();
          }
        });
      }
    } finally {
      // ALWAYS ensure loading state is set to false, even on error or success.
      if (mounted && !append) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    if (!await isUserAuthenticated()) return;

    List<Map<String, dynamic>> fetchedCategories = [
      {'id': null, 'name': 'All Categories'} // Add an "All Categories" option
    ];
    debugPrint('AllOrdersPageScreen: Fetching categories...');
    try {
      final response = await SafeHttp.safeGet(context, Uri.parse(categoriesEndpoint));

      if (!mounted) {
        debugPrint('AllOrdersPageScreen: Widget unmounted during categories API call.');
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var cat in data) {
          final id = cat['id'];
          if (id != null) {
            // Ensure ID is converted to int if it's a string
            final intId = id is int ? id : (id is String ? int.tryParse(id) : null);
            if (intId != null && cat['name'] is String) {
              fetchedCategories.add({'id': intId, 'name': cat['name']});
            }
          }
        }
        if (mounted) {
          setState(() {
            _categories = fetchedCategories;
          });
          _cacheManager.saveToCache('categories', fetchedCategories); // Save to cache
          debugPrint('AllOrdersPageScreen: Categories cached.');
        }
      } else {
        debugPrint('AllOrdersPageScreen: Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AllOrdersPageScreen: Error fetching categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          debugPrint('AllOrdersPageScreen: Categories loading finished.');
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
          final matchesSearch = title.contains(search);

          if (_selectedCategoryId == null) {
            return matchesSearch; // If "All Categories" is selected, only apply search filter
          }

          // Ensure 'order-categories' is a List and convert string IDs to int if needed
          List<int> orderCategoryIds = [];
          if (order['order-categories'] is List) {
            orderCategoryIds = order['order-categories'].map<int>((category) {
              if (category is int) return category;
              if (category is String) return int.tryParse(category) ?? -1;
              return -1;
            }).toList();
          }
          
          // Check if any of the order's category IDs match the selected category
          final matchesCategory = orderCategoryIds.contains(_selectedCategoryId);

          return matchesSearch && matchesCategory;
        }).toList();
        debugPrint('AllOrdersPageScreen: Filtered orders count: ${_filteredOrders.length}');
      });
    }
  }

  // Add membership status fetch
  Future<void> _fetchMembershipStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingMembership = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _isLoadingMembership = false;
          });
        }
        return;
      }

      final response = await http.get(
        Uri.parse(_membershipEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final bool active = data['success'] == true && data['active'] == true;

        if (mounted) {
          setState(() {
            _isActiveMembership = active;
            _isLoadingMembership = false;
          });
        }
      } else {
        debugPrint('Failed to load membership status: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _isLoadingMembership = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching membership status: $e');
      if (mounted) {
        setState(() {
          _isActiveMembership = false;
          _isLoadingMembership = false;
        });
      }
    }
  }

  // Add refresh method
  Future<void> _onRefresh() async {
    debugPrint('AllOrdersPageScreen: Performing refresh...');
    setState(() {
      _orders.clear();
      _filteredOrders.clear();
      _currentPage = 1;
      _hasMoreOrders = true;
      _isLoadingOrders = true;
      _isLoadingCategories = true;
      _isLoadingMembership = true;
      _selectedCategoryId = null; // Reset category filter on pull-to-refresh
    });

    try {
      await Future.wait([
        _fetchOrders(page: 1, perPage: _perPage, append: false),
        _fetchCategories(),
        _fetchMembershipStatus(),
      ]);
      debugPrint('AllOrdersPageScreen: All refresh futures completed.');
    } catch (e) {
      debugPrint('AllOrdersPageScreen: Error during _onRefresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          _isLoadingCategories = false;
          _isLoadingMembership = false;
          debugPrint('AllOrdersPageScreen: _onRefresh finished, loading states set to false.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector( // Main GestureDetector for the body
        behavior: HitTestBehavior.opaque, // Ensures taps are registered outside widgets
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
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

              // Category Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _isLoadingCategories && _categories.isEmpty
                        ? SizedBox(
                            height: 40,
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 5,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) => Container(
                                  width: 100,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _categories.isEmpty
                            ? const Text("Keine Kategorien verfügbar.")
                            : SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const AlwaysScrollableScrollPhysics(), // Ensure it's always scrollable
                                  itemCount: _categories.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final category = _categories[index];
                                    final id = category['id'];
                                    final name = category['name'];
                                    final isSelected = _selectedCategoryId == id;

                                    return ActionChip(
                                      label: Text(name!),
                                      backgroundColor: isSelected
                                          ? const Color.fromARGB(255, 168, 15, 15)
                                          : Colors.grey[200],
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        if (mounted) {
                                          setState(() {
                                            _selectedCategoryId = isSelected ? null : id;
                                            _currentPage = 1;
                                            _hasMoreOrders = true;
                                            _orders.clear();
                                          });
                                          // Just trigger the fetch, it will handle its own loading state.
                                          _fetchOrders(page: _currentPage, perPage: _perPage, append: false);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Orders List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _isLoadingOrders && _filteredOrders.isEmpty
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: ListView.separated(
                            itemCount: 5,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : _filteredOrders.isEmpty
                          ? Center(child: Text(
                              _isActiveMembership ?
                              "Keine Aufträge gefunden, die Ihren Kriterien entsprechen." :
                              "Keine Aufträge gefunden, die Ihren Kriterien entsprechen."
                            ))
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(), // Always allow pull to refresh
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
                                final imageUrl = order['imageUrl'] ?? '';
                                final title = order['title']['rendered'] ?? 'Untitled';
                                //final categoryName = order['acf']?['category'] ?? 'N/A'; // Assuming 'acf' for single category name

                                return GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    if (_isActiveMembership) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SingleOrderPageScreen(order: order),
                                        ),
                                      );
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (context) => MembershipRequiredDialog(
                                          context: context,
                                          message: 'A membership is required to view order details. Get a membership to access all order information.',
                                        ),
                                      );
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