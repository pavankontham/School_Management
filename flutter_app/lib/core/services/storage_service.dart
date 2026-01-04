import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

/// Service for managing local storage using Hive and Flutter Secure Storage
class StorageService {
  StorageService._();
  
  static late Box _generalBox;
  static late Box _cacheBox;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  /// Initialize storage boxes
  static Future<void> init() async {
    _generalBox = await Hive.openBox('general');
    _cacheBox = await Hive.openBox('cache');
  }
  
  // ============ Secure Storage (for tokens) ============
  
  /// Save access token securely
  static Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: AppConfig.accessTokenKey, value: token);
  }
  
  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: AppConfig.accessTokenKey);
  }
  
  /// Save refresh token securely
  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConfig.refreshTokenKey, value: token);
  }
  
  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConfig.refreshTokenKey);
  }
  
  /// Clear all tokens
  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConfig.accessTokenKey);
    await _secureStorage.delete(key: AppConfig.refreshTokenKey);
  }
  
  // ============ General Storage ============
  
  /// Save user data
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _generalBox.put(AppConfig.userDataKey, jsonEncode(userData));
  }
  
  /// Get user data
  static Map<String, dynamic>? getUserData() {
    final data = _generalBox.get(AppConfig.userDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
  
  /// Save student data
  static Future<void> saveStudentData(Map<String, dynamic> studentData) async {
    await _generalBox.put(AppConfig.studentDataKey, jsonEncode(studentData));
  }
  
  /// Get student data
  static Map<String, dynamic>? getStudentData() {
    final data = _generalBox.get(AppConfig.studentDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }
  
  /// Save user type
  static Future<void> saveUserType(UserType userType) async {
    await _generalBox.put(AppConfig.userTypeKey, userType.value);
  }
  
  /// Get user type
  static UserType? getUserType() {
    final data = _generalBox.get(AppConfig.userTypeKey);
    if (data != null) {
      return UserTypeExtension.fromString(data);
    }
    return null;
  }
  
  /// Clear user data
  static Future<void> clearUserData() async {
    await _generalBox.delete(AppConfig.userDataKey);
    await _generalBox.delete(AppConfig.studentDataKey);
    await _generalBox.delete(AppConfig.userTypeKey);
  }
  
  /// Clear all data (logout)
  static Future<void> clearAll() async {
    await clearTokens();
    await clearUserData();
    await _cacheBox.clear();
  }
  
  // ============ Cache Storage ============
  
  /// Save data to cache with expiry
  static Future<void> cacheData(String key, dynamic data, {Duration? expiry}) async {
    final expiryTime = DateTime.now().add(expiry ?? AppConfig.cacheExpiry);
    await _cacheBox.put(key, {
      'data': jsonEncode(data),
      'expiry': expiryTime.toIso8601String(),
    });
  }
  
  /// Get cached data (returns null if expired)
  static dynamic getCachedData(String key) {
    final cached = _cacheBox.get(key);
    if (cached != null) {
      final expiry = DateTime.parse(cached['expiry']);
      if (DateTime.now().isBefore(expiry)) {
        return jsonDecode(cached['data']);
      } else {
        // Remove expired cache
        _cacheBox.delete(key);
      }
    }
    return null;
  }
  
  /// Clear specific cache
  static Future<void> clearCache(String key) async {
    await _cacheBox.delete(key);
  }
  
  /// Clear all cache
  static Future<void> clearAllCache() async {
    await _cacheBox.clear();
  }
  
  // ============ Offline Data Storage ============
  
  /// Save offline data for sync later
  static Future<void> saveOfflineData(String type, Map<String, dynamic> data) async {
    final offlineData = _generalBox.get('offline_$type') as List? ?? [];
    offlineData.add({
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _generalBox.put('offline_$type', offlineData);
  }
  
  /// Get offline data
  static List<Map<String, dynamic>> getOfflineData(String type) {
    final data = _generalBox.get('offline_$type') as List?;
    if (data != null) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
  
  /// Clear offline data after sync
  static Future<void> clearOfflineData(String type) async {
    await _generalBox.delete('offline_$type');
  }
}

