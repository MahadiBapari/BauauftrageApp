import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../my_order_page/my_order_page_screen.dart'; // Ensure this path is correct

class AppDrawer extends StatelessWidget {
  final String role;
  final Function(int) onItemTap;
  final VoidCallback? onNavigateToSupport;
  final VoidCallback? onNavigateToMyMembership;

  const AppDrawer({
    super.key,
    required this.role,
    required this.onItemTap,
    this.onNavigateToSupport,
    this.onNavigateToMyMembership,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('username');
    await prefs.remove('user_email');
    await prefs.remove('displayName');
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Role-based dynamic menu items
  List<Widget> _buildRoleMenuItems(BuildContext context) {
    if (role == 'um_client') {
      return [
        _buildTile(Icons.home, 'Feed', 0, context),
        _buildTile(Icons.person, 'Profil', 1, context),
        _buildTile(Icons.add_shopping_cart, 'Neuen Auftrag hinzufügen', 2, context),
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text('Meine Aufträge'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyOrdersPageScreen()),
            );
          },
        ),
      ];
    } else if (role == 'um_contractor') {
      return [
        _buildTile(Icons.home, 'Feed', 0, context),
        _buildTile(Icons.person, 'Profil', 1, context),
        _buildTile(Icons.card_membership, 'Meine Mitgliedschaft', 2, context),
        _buildTile(Icons.shopping_bag, 'Alle Aufträge', 3, context),
      ];
    } else {
      return []; // default/fallback
    }
  }

  // Shared static menu items
  List<Widget> _buildStaticMenuItems(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.group),
        title: const Text('Partner'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/partners');
        },
      ),
      ListTile(
        leading: const Icon(Icons.help),
        title: const Text('Support & Hilfe'),
        onTap: () {
          Navigator.pop(context);
          onNavigateToSupport?.call();
        },
      ),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Abmelden'),
        onTap: () => _handleLogout(context),
      ),
    ];
  }

  // Reusable ListTile builder
  ListTile _buildTile(IconData icon, String label, int index, BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onItemTap(index); // Notify parent to switch screen
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Drawer(
    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    child: Builder(
      builder: (context) {
        // Ensure keyboard is dismissed when drawer opens
        Future.microtask(() => FocusScope.of(context).unfocus());

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Custom header with only top padding = 80
            Container(
              color: const Color.fromARGB(255, 255, 255, 255),
              padding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 12),
              alignment: Alignment.centerLeft,
              child: const Text(
                'BAUAUFTRÄGE24',
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ..._buildRoleMenuItems(context),
            ..._buildStaticMenuItems(context),
          ],
        );
      },
    ),
  );
}


}
