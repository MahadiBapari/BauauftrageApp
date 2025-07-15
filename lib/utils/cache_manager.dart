import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const Duration defaultExpiration = Duration(hours: 1);
  static const String _lastRefreshKey = 'last_refresh_timestamp';
  
  // Singleton pattern
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // Cache expiration times for different data types
  static const Map<String, Duration> _expirationTimes = {
    'user_data': Duration(hours: 1),
    'promo_orders': Duration(minutes: 30),
    'categories': Duration(hours: 24),
    'new_arrivals': Duration(minutes: 15),
    'membership_status': Duration(hours: 1),
    'partners': Duration(hours: 12),
  };

  Future<bool> isCacheExpired(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefresh = prefs.getInt('${key}_timestamp');
    if (lastRefresh == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final expirationTime = _expirationTimes[key] ?? defaultExpiration;
    return now - lastRefresh > expirationTime.inMilliseconds;
  }

  Future<void> saveToCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (data is String) {
        await prefs.setString(key, data);
      } else if (data is bool) {
        await prefs.setBool(key, data);
      } else if (data is int) {
        await prefs.setInt(key, data);
      } else if (data is double) {
        await prefs.setDouble(key, data);
      } else if (data is List<String>) {
        await prefs.setStringList(key, data);
      } else if (data is List || data is Map) {
        final jsonString = json.encode(data);
        debugPrint('Saving to cache - Key: $key, Data: $jsonString'); // Debug log
        await prefs.setString(key, jsonString);
      } else {
        debugPrint('Warning: Attempting to save unsupported type for key $key: ${data.runtimeType}');
      }
      
      // Save timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('Saving timestamp for $key: $timestamp'); // Debug log
      await prefs.setInt('${key}_timestamp', timestamp);
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  Future<dynamic> loadFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = prefs.get(key);
      debugPrint('Loading from cache - Key: $key, Data: $data'); // Debug log
      
      if (data == null) return null;

      if (data is String) {
        try {
          final decoded = json.decode(data);
          debugPrint('Decoded cache data: $decoded'); // Debug log
          return decoded;
        } catch (e) {
          debugPrint('Error decoding cache data: $e'); // Debug log
          return data;
        }
      }
      return data;
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      return null;
    }
  }

  Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('${key}_timestamp');
    debugPrint('Cleared cache for key: $key'); // Debug log
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('Cleared all cache'); // Debug log
  }
} 