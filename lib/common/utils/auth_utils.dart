import 'package:shared_preferences/shared_preferences.dart';

Future<bool> isUserAuthenticated() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  return token != null && token.isNotEmpty;
} 