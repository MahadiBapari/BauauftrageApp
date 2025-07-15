import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SafeHttp {
  static Future<http.Response> safeGet(BuildContext context, Uri url, {Map<String, String>? headers}) async {
    debugPrint('[SafeHttp.safeGet] URL: \\${url.toString()} Headers: \\${headers?.toString()}');
    try {
      final response = await http.get(url, headers: headers);
      debugPrint('[SafeHttp.safeGet] Response: \\${response.statusCode}');
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[SafeHttp.safeGet] Unauthorized for URL: \\${url.toString()}');
        _handleUnauthorized(context, url: url.toString(), method: 'GET');
        throw Exception('Unauthorized');
      }
      return response;
    } catch (e) {
      debugPrint('SafeHttp GET error: \\$e');
      rethrow;
    }
  }

  static Future<http.Response> safePost(BuildContext context, Uri url, {Map<String, String>? headers, Object? body}) async {
    debugPrint('[SafeHttp.safePost] URL: \\${url.toString()} Headers: \\${headers?.toString()} Body: \\${body?.toString()}');
    try {
      final response = await http.post(url, headers: headers, body: body);
      debugPrint('[SafeHttp.safePost] Response: \\${response.statusCode}');
      final isLoginRequest = url.path.endsWith('/login/');
      final isResetPasswordRequest = url.path.endsWith('/reset-password');
      if ((response.statusCode == 401 || response.statusCode == 403) && !isLoginRequest && !isResetPasswordRequest) {
        debugPrint('[SafeHttp.safePost] Unauthorized for URL: \\${url.toString()}');
        _handleUnauthorized(context, url: url.toString(), method: 'POST');
        throw Exception('Unauthorized');
      }
      return response;
    } catch (e) {
      debugPrint('SafeHttp POST error: \\$e');
      rethrow;
    }
  }

  static Future<http.Response> safePut(BuildContext context, Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    debugPrint('[SafeHttp.safePut] URL: \\${url.toString()} Headers: \\${headers?.toString()} Body: \\${body?.toString()}');
    final response = await http.put(url, headers: headers, body: body, encoding: encoding);
    debugPrint('[SafeHttp.safePut] Response: \\${response.statusCode}');
    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('[SafeHttp.safePut] Unauthorized for URL: \\${url.toString()}');
      await logoutAndRedirect(context, url: url.toString(), method: 'PUT');
      throw Exception('Session expired');
    }
    return response;
  }

  static Future<http.Response> safeDelete(BuildContext context, Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    debugPrint('[SafeHttp.safeDelete] URL: \\${url.toString()} Headers: \\${headers?.toString()}');
    final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
    debugPrint('[SafeHttp.safeDelete] Response: \\${response.statusCode}');
    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('[SafeHttp.safeDelete] Unauthorized for URL: \\${url.toString()}');
      await logoutAndRedirect(context, url: url.toString(), method: 'DELETE');
      throw Exception('Session expired');
    }
    return response;
  }

  static void _handleUnauthorized(BuildContext context, {String? url, String? method}) async {
    // Clear auth token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    // Get current route name
    String? currentRoute;
    Navigator.popUntil(context, (route) {
      currentRoute = route.settings.name;
      return true;
    });
    debugPrint('[SafeHttp._handleUnauthorized] Redirect triggered! Method: \\${method ?? ''} URL: \\${url ?? ''} CurrentRoute: \\${currentRoute ?? 'null'} Context mounted: \\${context.mounted}');
    // Only redirect if not on public routes
    if (context.mounted && currentRoute != '/login' && currentRoute != '/reset-password') {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  static Future<void> logoutAndRedirect(BuildContext context, {String? url, String? method}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // or selectively remove only auth/session keys
    debugPrint('[SafeHttp.logoutAndRedirect] Redirect triggered! Method: \\${method ?? ''} URL: \\${url ?? ''} Context mounted: \\${context.mounted}');
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
    }
  }
} 