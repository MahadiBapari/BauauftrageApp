import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page/home_page_screen.dart';
import 'home_page/home_page_screen_client.dart';
import '../home/profile_page/profile_page_screen_contractor.dart';
import '../home/profile_page/profile_page_screen_client.dart';
import '../home/all_orders_page/all_orders_page_screen.dart';
import '../home/add_new_order_page/add_new_order_page_screen.dart';
import '../home/my_membership_page/my_membership_page_screen.dart';
import '../home/support_and_help_page/support_and_help_page_screen.dart';
import '../home/widgets/app_drawer.dart';

class MainScreen extends StatefulWidget {
  final String role;

  const MainScreen({super.key, required this.role});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _initialCategoryIdForAddOrder;
  late final List<IconData> _icons;
  late final List<String> _labels;

  bool isLoading = true;
  String displayName = 'User';

  @override
  void initState() {
    super.initState();
    _initializeNavItems();
    _fetchUser();
  }

  void _navigateToAddNewOrder(String categoryId) {
    setState(() {
      _initialCategoryIdForAddOrder = categoryId;
      _selectedIndex = 2; // Switch to the AddNewOrderPage
    });
  }

  void _initializeNavItems() {
    if (widget.role == 'um_client') {
      _icons = [Icons.home, Icons.person];
      _labels = ['Startseite', 'Profil'];
    } else if (widget.role == 'um_contractor') {
      _icons = [Icons.home, Icons.person, Icons.card_membership, Icons.shopping_bag];
      _labels = ['Startseite', 'Profil', 'Mitgliedschaft', 'Alle Aufträge'];
    } else {
      _icons = [Icons.home, Icons.person];
      _labels = ['Startseite', 'Profil'];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      // If user manually taps the 'Add' button, ensure it's a fresh form
      if (widget.role == 'um_client' && index == 2) {
        _initialCategoryIdForAddOrder = null;
      }
      _selectedIndex = index;
    });
  }

  Future<void> _fetchUser() async {
    final prefs = await SharedPreferences.getInstance();

    // Get user_id as String and try to convert
    final userIdString = prefs.getString('user_id');
    if (userIdString == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final int? userId = int.tryParse(userIdString);
    if (userId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final String apiKey = '1234567890abcdef';
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId');
    final response = await http.get(url, headers: {
      'X-API-Key': apiKey,
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final metaData = data['meta_data'];
      final List<dynamic>? firstNameList = metaData?['first_name'];
      final List<dynamic>? lastNameList = metaData?['last_name'];

      final firstName = (firstNameList != null && firstNameList.isNotEmpty) ? firstNameList[0] : '';
      final lastName = (lastNameList != null && lastNameList.isNotEmpty) ? lastNameList[0] : '';

      setState(() {
        displayName = '${firstName.trim()} ${lastName.trim()}'.trim().isEmpty
            ? 'User'
            : '${firstName.trim()} ${lastName.trim()}';
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isClient = widget.role == 'um_client';

    // Build screens declaratively
    final List<Widget> screens;
    if (widget.role == 'um_client') {
      screens = [
        HomePageScreenClient(
          key: const ValueKey('home_page'),
          onCategorySelected: _navigateToAddNewOrder,
          onAddOrderRequested: () {
            setState(() {
              _selectedIndex = 2; // Switch to the AddNewOrderPage
              _initialCategoryIdForAddOrder = null; // Fresh form
            });
          },
        ),
        const ProfilePageScreenClient(key: ValueKey('profile_page')),
        AddNewOrderPageScreen(
          key: ValueKey('add_new_order_page_$_initialCategoryIdForAddOrder'),
          initialCategoryId: _initialCategoryIdForAddOrder,
        ),
      ];
    } else if (widget.role == 'um_contractor') {
      screens = [
        const HomePageScreen(key: ValueKey('home_page')),
        const ProfilePageScreenContractor(key: ValueKey('profile_page')),
        const MyMembershipPageScreen(key: ValueKey('my_membership_page')),
        AllOrdersPageScreen(key: ValueKey('all_orders_page')),
      ];
    } else {
      screens = [
        const HomePageScreen(key: ValueKey('home_page')),
        const ProfilePageScreenClient(key: ValueKey('profile_page')),
      ];
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'BAUAUFTRÄGE24',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 24, 2, 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: AppDrawer(
        role: widget.role,
        onItemTap: _onItemTapped,
        onNavigateToSupport: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportAndHelpPageScreen()),
          );
        },
        onNavigateToMyMembership: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyMembershipPageScreen()),
          );
        },
      ),
      body: SizedBox.expand(
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1),
          BottomAppBar(
        color: const Color.fromARGB(255, 255, 255, 255),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length + (isClient ? 1 : 0), (index) {
            // Insert the custom button in the middle for clients
            if (isClient && index == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 179, 21, 21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => _onItemTapped(2),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          );
            } else {
          // Adjust index for icons after the inserted button
          int iconIndex = isClient && index > 1 ? index - 1 : index;
          return IconButton(
            icon: Icon(
              _icons[iconIndex],
              color: _selectedIndex == iconIndex
              ? const Color.fromARGB(255, 182, 34, 20)
              : const Color.fromARGB(255, 133, 133, 133),
              size: 32,
            ),
            onPressed: () => _onItemTapped(iconIndex),
            tooltip: _labels[iconIndex],
          );
            }
          }),
        ),
          ),
        ],
      ),
    );
  }
}
