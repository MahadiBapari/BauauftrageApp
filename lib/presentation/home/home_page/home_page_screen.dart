import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Future.wait
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/cache_manager.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../../widgets/membership_required_dialog.dart';
import '../all_orders_page/single_order_page_screen.dart'; // Ensure this is correctly imported
import '../my_membership_page/membership_form_page_screen.dart'; // Import for the form page
import '../partners_page/partners_page_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/network/safe_http.dart';
import 'package:bauauftrage/common/utils/auth_utils.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  String displayName = "User";
  bool isLoadingUser = true; // Still needed for user name specifically
  bool isLoadingPromos = true;

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _newArrivalsOrders = [];
  List<Map<String, dynamic>> _filteredNewArrivalsOrders = [];
  bool isLoadingCategories = true;
  bool isLoadingNewArrivals = true;

  List<Map<String, dynamic>> promoOrders = [];

  String? _authToken;

  static const String apiKey = '1234567890abcdef'; 

  bool _isLoadingMembership = true;
  bool _isActiveMembership = false;
  String _membershipStatusMessage = '';
  final String _membershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user-membership';

  List<Partner> _partners = [];
  List<Partner> _randomPartnersForDisplay = [];
  bool _isLoadingPartners = true;
  final String _partnersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners?per_page=100';

  // Add cache expiration constants
  static const Duration _cacheExpiration = Duration(hours: 1);
  static const String _lastRefreshKey = 'last_refresh_timestamp';
  
  // Add refresh timer
  Timer? _refreshTimer;

  final CacheManager _cacheManager = CacheManager();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllSectionsFromCacheThenBackground();
  }

  Future<void> _loadAllSectionsFromCacheThenBackground() async {
    await Future.wait([
      _loadUserDataFromCache(),
      _loadPromoOrdersFromCache(),
      _loadCategoriesFromCache(),
      _loadNewArrivalsFromCache(),
      _loadMembershipStatusFromCache(),
      _loadPartnersFromCache(),
    ]);
    // Fetch fresh data in background
    _loadInitialData();
  }

  Future<void> _loadUserDataFromCache() async {
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

  Future<void> _loadPromoOrdersFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('promo_orders');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          promoOrders = List<Map<String, dynamic>>.from(cachedData as List);
          isLoadingPromos = false;
        });
      }
    }
  }

  Future<void> _loadCategoriesFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('categories');
    if (cachedData != null) {
      if (mounted) {
        var processedCategories = (cachedData as List).map((cat) {
          dynamic id = cat['id'];
          if (id is String) {
            id = int.tryParse(id);
          }
          return {'id': id, 'name': cat['name'] as String};
        }).toList();

        // Ensure 'All Categories' is present and at the top.
        processedCategories.removeWhere((cat) => cat['id'] == null);
        processedCategories.insert(0, {'id': null, 'name': 'All Categories'});
        
        setState(() {
          _categories = processedCategories;
          isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadNewArrivalsFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('new_arrivals');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _newArrivalsOrders = List<Map<String, dynamic>>.from(cachedData as List);
          _filterNewArrivals();
          isLoadingNewArrivals = false;
        });
      }
    }
  }

  Future<void> _loadMembershipStatusFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('membership_status');
    if (cachedData != null) {
      if (mounted) {
        final membershipData = cachedData as Map<String, dynamic>;
        setState(() {
          _isActiveMembership = membershipData['active'] as bool;
          _membershipStatusMessage = membershipData['message'] as String;
          _isLoadingMembership = false;
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
          final shuffledPartners = List<Partner>.from(partners)..shuffle();
          _randomPartnersForDisplay = shuffledPartners.take(8).toList();
          _isLoadingPartners = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load cached data first
      final cachedPartners = await _cacheManager.loadFromCache('partners');
      debugPrint('Cached partners: $cachedPartners'); // Debug log
      if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
        final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
        debugPrint('Loaded ${partners.length} partners from cache'); // Debug log
        if (mounted) {
          setState(() {
            _partners = partners;
            final shuffledPartners = List<Partner>.from(partners)..shuffle();
            _randomPartnersForDisplay = shuffledPartners.take(8).toList();
            _isLoadingPartners = false;
          });
        }
      }
      // Load all data in parallel
      await Future.wait([
        _fetchUser(),
        _fetchPromoOrders(),
        _fetchCategories(),
        _fetchNewArrivalsOrders(),
        _fetchMembershipStatus(),
        _loadPartners(),
      ]);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUser() async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await SafeHttp.safeGet(
        context,
        Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (mounted) {
          setState(() {
            displayName = userData['firmenname_'] ?? "";
            isLoadingUser = false;
          });
        }
        // Cache the user data
        await _cacheManager.saveToCache('user_data', displayName);
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingUser = false);
      }
    }
  }

  Future<void> _fetchPromoOrders() async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      debugPrint('Fetching promo orders...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final response = await SafeHttp.safeGet(
        context,
        Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?status=publish&promo=true'),
        headers: {
          'Accept': 'application/json',
          'X-API-Key': apiKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Promo orders response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 401) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Parsed promo orders data length: ${data.length}');
        
        final List<Map<String, dynamic>> formattedOrders = [];
        for (var order in data) {
          String imageUrl = '';
          // Get the first image from the order gallery
          if (order['meta']?['order_gallery'] != null) {
            final gallery = order['meta']?['order_gallery'];
            if (gallery is List && gallery.isNotEmpty) {
              final firstImage = gallery[0];
              if (firstImage is Map && firstImage['id'] != null) {
                final imageId = firstImage['id'];
                try {
                  final mediaResponse = await SafeHttp.safeGet(
                    context,
                    Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$imageId'),
                    headers: {'X-API-Key': apiKey},
                  );
                  
                  if (mediaResponse.statusCode == 200) {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'] ?? '';
                  }
                } catch (e) {
                  debugPrint('Error fetching media for ID $imageId: $e');
                }
              }
            }
          }

          formattedOrders.add({
            "displayTitle": order['title']['rendered'] ?? '',
            "displayCategory": order['order_category'] ?? '',
            "displayImageUrl": imageUrl,
            "fullOrder": order,
          });
        }

        debugPrint('Formatted promo orders length: ${formattedOrders.length}');

        if (mounted) {
          setState(() {
            promoOrders = formattedOrders;
            isLoadingPromos = false;
          });
        }
        await _cacheManager.saveToCache('promo_orders', formattedOrders);
      }
    } catch (e) {
      debugPrint('Error fetching promo orders: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingPromos = false);
      }
    }
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      final response = await SafeHttp.safeGet(
        context,
        Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        List<Map<String, dynamic>> rawCategories = [];
        for (var cat in data) {
          final id = cat['id'];
          if (id != null) {
            final intId = id is int ? id : (id is String ? int.tryParse(id) : null);
            if (intId != null && cat['name'] is String) {
              rawCategories.add({'id': intId, 'name': cat['name']});
            }
          }
        }

        // Save the raw, unmodified list to cache
        await _cacheManager.saveToCache('categories', rawCategories);

        if (mounted) {
          
          var uiCategories = List<Map<String, dynamic>>.from(rawCategories);
          uiCategories.insert(0, {'id': null, 'name': 'All Categories'});
          
          setState(() {
            _categories = uiCategories;
            isLoadingCategories = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingCategories = false);
      }
    }
  }

  Future<void> _fetchNewArrivalsOrders({int? categoryId}) async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      setState(() => isLoadingNewArrivals = true);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      String url = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?status=publish&orderby=date&order=desc';
      // The categoryId parameter is removed from the URL to fetch all orders
      debugPrint('Fetching new arrivals from URL: $url');

      final response = await SafeHttp.safeGet(
        context, 
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'X-API-Key': apiKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      debugPrint('New arrivals response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 401) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Parsed new arrivals data length: ${data.length}');
        
        final List<Map<String, dynamic>> formattedOrders = [];
        for (var order in data) {
          String imageUrl = '';
          // Get the first image from the order gallery
          if (order['meta']?['order_gallery'] != null) {
            final gallery = order['meta']?['order_gallery'];
            if (gallery is List && gallery.isNotEmpty) {
              final firstImage = gallery[0];
              if (firstImage is Map && firstImage['id'] != null) {
                final imageId = firstImage['id'];
                try {
                  final mediaResponse = await SafeHttp.safeGet(
                    context,
                    Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$imageId'),
                    headers: {'X-API-Key': apiKey},
                  );
                  
                  if (mediaResponse.statusCode == 200) {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'] ?? '';
                  }
                } catch (e) {
                  debugPrint('Error fetching media for ID $imageId: $e');
                }
              }
            }
          }

          final formatted = {
            "displayTitle": order['title']['rendered'] ?? '',
            "displayCategory": order['order_category'] ?? '',
            "displayImageUrl": imageUrl,
            "fullOrder": order,
          };
          debugPrint('Formatted order: $formatted');
          formattedOrders.add(formatted);
        }

        debugPrint('Formatted new arrivals length: ${formattedOrders.length}');

        if (mounted) {
          setState(() {
            _newArrivalsOrders = formattedOrders;
            _filterNewArrivals(); // Filter after fetching
            isLoadingNewArrivals = false;
          });
        }
        await _cacheManager.saveToCache('new_arrivals', formattedOrders);
      }
    } catch (e) {
      debugPrint('Error fetching new arrivals: $e');
      debugPrint('Stack trace: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoadingNewArrivals = false);
      }
    }
  }

  Future<void> _fetchMembershipStatus() async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await SafeHttp.safeGet(
        context,
        Uri.parse(_membershipEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isActiveMembership = data['active'] ?? false;
            _membershipStatusMessage = data['message'] ?? '';
            _isLoadingMembership = false;
          });
        }
        // Cache the membership status
        await _cacheManager.saveToCache('membership_status', {
          'active': _isActiveMembership,
          'message': _membershipStatusMessage,
        });
      }
    } catch (e) {
      debugPrint('Error fetching membership status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembership = false);
      }
    }
  }

  Future<void> _loadPartners() async {
    if (!mounted) return;
    if (!await isUserAuthenticated()) return;
    try {
      final response = await SafeHttp.safeGet(
        context, 
        Uri.parse(_partnersEndpoint),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Partner> partners = [];
        
        for (var partner in data) {
          String? logoUrl;
          int? logoId = partner['meta']?['logo']?['id'];
          
          if (logoId != null) {
            try {
              final mediaResponse = await SafeHttp.safeGet(
                context,
                Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$logoId'),
                headers: {'X-API-Key': apiKey},
              );
              
              if (mediaResponse.statusCode == 200) {
                final mediaData = json.decode(mediaResponse.body);
                logoUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'];
              }
            } catch (e) {
              debugPrint('Error fetching media for partner logo ID $logoId: $e');
            }
          }

          partners.add(Partner(
            title: partner['title']['rendered'] ?? '',
            address: partner['partner_address'] ?? '',
            logoId: logoId,
            logoUrl: logoUrl,
          ));
        }

        if (mounted) {
          setState(() {
            _partners = partners;
            final shuffledPartners = List<Partner>.from(partners)..shuffle();
            _randomPartnersForDisplay = shuffledPartners.take(8).toList();
            _isLoadingPartners = false;
          });
        }
        await _cacheManager.saveToCache('partners', partners.map((p) => p.toJson()).toList());
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPartners = false);
      }
    }
  }

  void _filterNewArrivals() {
    if (mounted) {
      setState(() {
        if (_selectedCategoryId == null) {
          _filteredNewArrivalsOrders = List.from(_newArrivalsOrders);
        } else {
          _filteredNewArrivalsOrders = _newArrivalsOrders.where((order) {
            final fullOrder = order['fullOrder'];
            if (fullOrder != null && fullOrder['order-categories'] is List) {
              final categoryIds = List<int>.from(fullOrder['order-categories']
                  .map((catId) => catId is int ? catId : int.tryParse(catId.toString()) ?? -1));
              return categoryIds.contains(_selectedCategoryId);
            }
            return false;
          }).toList();
        }
      });
    }
  }

  // In build(), for each section, only show shimmer/loading if loading==true and data is empty
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
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

                  // Membership Card with Shimmer
                  _isLoadingMembership && !_isActiveMembership && _membershipStatusMessage.isEmpty
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      : !_isActiveMembership
                          ? _buildGetMembershipCard(context)
                          : const SizedBox.shrink(),

                  const SizedBox(height: 24),

                  // Promotions Section with Shimmer
                  isLoadingPromos && promoOrders.isEmpty
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: SizedBox(
                            height: 160,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (_, __) => Container(
                                width: 280,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        )
                      : promoOrders.isEmpty
                          ? const Center(child: Text("No promotions available."))
                          : SizedBox(
                              height: 160,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: promoOrders.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final promo = promoOrders[index];
                                  return _buildOrderCard(
                                      promo["displayTitle"]!, promo["displayCategory"]!, promo["displayImageUrl"]);
                                },
                              ),
                            ),
                  const SizedBox(height: 24),

                  _buildCategorySection(),
                  const SizedBox(height: 20),

                  // New Arrivals Section (Newest Orders)
                  (isLoadingNewArrivals && _newArrivalsOrders.isEmpty)
                      ? SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 4,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (_, __) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ) // Horizontal shimmer for newest orders
                      : _filteredNewArrivalsOrders.isEmpty
                          ? const Text("Keine neuen Aufträge in dieser Kategorie.")
                          : SizedBox(
                              height: 220,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filteredNewArrivalsOrders.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final orderData = _filteredNewArrivalsOrders[index];
                                  return _buildNewArrivalCard(orderData);
                                },
                              ),
                            ),
                  const SizedBox(height: 24),

                  _buildCouponCard(
                    imageUrl: 'assets/images/kpsa_logo.png',
                    discountText: '20% Rabatt',
                    descriptionText: '20% Rabatt auf Arbeitskleidung für Bauaufträge24-Handwerker! Bestellen Sie Ihre Arbeitskleidung direkt auf www.kpsa.ch. Melden Sie sich in Ihrem Website-Konto an oder registrieren Sie sich, um Ihren exklusiven Rabattcode zu erhalten.\n\nNach dem Login finden Sie den Code in Ihrem Profil.',
                    onShowDiscountCode: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rabattcode wird hier angezeigt!')),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Partners Section with Shimmer
                  _isLoadingPartners && _partners.isEmpty
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 4,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (_, __) => Container(
                                width: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        )
                      : _buildPartnersSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(String title, String category, String? imageUrl) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color.fromARGB(255, 153, 153, 153)),
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
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Neueste Aufträge", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingCategories
            ? Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => Container(
                      width: 100,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final categoryId = category['id'] as int?;
                        final isSelected = _selectedCategoryId == categoryId;
                        return ActionChip(
                          label: Text(category['name']!),
                          backgroundColor: isSelected ? const Color.fromARGB(255, 179, 21, 21) : Colors.grey[200],
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onPressed: () {
                            setState(() {
                              // When a chip is pressed, its ID is now the selected one.
                              // For the "All" chip, the categoryId is null.
                              _selectedCategoryId = categoryId;
                            });
                            _filterNewArrivals();
                          },
                        );
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildGetMembershipCard(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = screenWidth < 350 ? 12.0 : 24.0;
    final double iconSize = screenWidth < 350 ? 32 : 42;
    final double titleFontSize = screenWidth < 350 ? 14 : 20;
    final double descFontSize = screenWidth < 350 ? 12 : 14;
    final double buttonFontSize = screenWidth < 350 ? 12 : 14;
    final double cardMargin = screenWidth < 350 ? 12.0 : 24.0;

    return Container(
      margin: EdgeInsets.only(bottom: cardMargin),
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 85, 21, 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 105, 12, 12),
            Color.fromARGB(255, 197, 24, 24),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color: Colors.amberAccent,
                size: iconSize,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Schalt Premium-Funktione frei!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
                'Du bisch aktuell kei Mitglied. Jetzt Mitglied werde für meh Vorteili!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: descFontSize,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MembershipFormPageScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color.fromARGB(255, 85, 21, 1),
                padding: EdgeInsets.symmetric(vertical: screenWidth < 350 ? 8 : 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: Text(
                'Jetzt Mitglied werde',
                style: TextStyle(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard({
    required String imageUrl,
    required String discountText,
    required String descriptionText,
    required VoidCallback onShowDiscountCode,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              height: 80, // Add fixed height
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.startsWith('http')
                      ? ExtendedImage.network(
                          imageUrl,
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
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              );
                            }
                            return null;
                          },
                        )
                      : ExtendedImage.asset(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    discountText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descriptionText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_isActiveMembership) {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 185, 33, 33),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: const Icon(Icons.discount, size: 48, color: Colors.white),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'KPSA bietet hochwertige Berufs- und Schutzkleidung für Handwerker und Bauprofis.\n\nGeben Sie bei Ihrer Bestellung auf',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      const url = 'https://www.kpsa.ch';
                                      // ignore: deprecated_member_use
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    },
                                    child: const Text(
                                      'www.kpsa.ch',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 185, 33, 33),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '„bauaufträge24" ein, um 20% Rabatt zu erhalten. (Keine Passkarte erforderlich.)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 185, 33, 33),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                    ),
                                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => MembershipRequiredDialog(
                            context: context,
                            message: 'Für die Anzeige des Rabattcodes ist eine Mitgliedschaft erforderlich.',
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 185, 33, 33),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                        'Rabattcode azeige',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Unsere Partner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PartnerScreen()),
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
        const SizedBox(height: 12),
        _isLoadingPartners
            ? const CustomLoadingIndicator(
                size: 30.0,
                message: 'Loading partners...',
                isHorizontal: true,
                itemCount: 4,
                itemHeight: 240,
                itemWidth: 150,
              )
            : _partners.isEmpty
                ? const Text("Zurzeit sind keine Partner verfügbar.")
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
      ],
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    // Responsive width based on screen size
    final double screenWidth = MediaQuery.of(context).size.width;
    // Card width: max 180, min 120, 40% of screen for small screens
    final double cardWidth = screenWidth < 400
        ? screenWidth * 0.4
        : screenWidth < 600
            ? 140
            : 160;

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped on ${partner.title}')),
        );
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 85, 85, 85).withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double imageHeight = constraints.maxWidth * 0.55;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (partner.logoUrl != null && partner.logoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 13.0, left: 10, right: 10),
                      child: SizedBox(
                        height: imageHeight,
                        child: Image.network(
                          partner.logoUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(top: imageHeight * 0.2),
                      child: Column(
                        children: [
                          Icon(Icons.business, size: imageHeight * 0.7, color: Colors.grey),
                          Text(
                            'No Logo',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      partner.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth < 400 ? 13 : 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNewArrivalCard(Map<String, dynamic> orderData) {
    final String title = orderData["displayTitle"]!;
    final String category = orderData["displayCategory"]!;
    final String? imageUrl = orderData["displayImageUrl"];
    final Map<String, dynamic> fullOrder = orderData["fullOrder"]!;

    return InkWell(
      onTap: () {
        if (_isActiveMembership) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SingleOrderPageScreen(
                order: fullOrder,
              ),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => MembershipRequiredDialog(
              context: context,
              message: 'Mitgliedschaft erforderlich, um Auftragsdetails zu sehen. Erwerben Sie eine Mitgliedschaft, um alle Auftragsinformationen zu erhalten.',
            ),
          );
        }
      },
      child: Container(
        width: 160,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
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
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (category.isNotEmpty && category != 'No Category')
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
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