import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  // Singleton pattern
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Cache permissions in memory for faster access
  Map<String, List<String>>? _cachedPermissions;

  /// Save permissions from login response
  Future<void> savePermissions(Map<String, dynamic> permissionsData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save the entire permissions object as JSON string
      await prefs.setString('user_permissions', jsonEncode(permissionsData));
      
      // Clear cache to force reload
      _cachedPermissions = null;
      
      debugPrint('✅ Permissions saved successfully');
      debugPrint('📋 Module: ${permissionsData['module']}');
      debugPrint('📋 Permissions count: ${(permissionsData['permissions'] as List?)?.length ?? 0}');
    } catch (e) {
      debugPrint('❌ Error saving permissions: $e');
    }
  }

  /// Get all permissions for a specific page
  Future<List<String>> getPagePermissions(String pageName) async {
    try {
      // Load permissions if not cached
      if (_cachedPermissions == null) {
        await _loadPermissions();
      }

      // Return permissions for the page (case-insensitive)
      final permissions = _cachedPermissions?[pageName.toLowerCase()] ?? [];
      debugPrint('🔍 Permissions for "$pageName": $permissions');
      return permissions;
    } catch (e) {
      debugPrint('❌ Error getting page permissions: $e');
      return [];
    }
  }

  /// Check if user has a specific permission for a page
  Future<bool> hasPermission(String pageName, String permission) async {
    final permissions = await getPagePermissions(pageName);
    final hasIt = permissions.contains(permission.toLowerCase());
    debugPrint('🔐 Check permission "$permission" for "$pageName": $hasIt');
    return hasIt;
  }

  /// Check if a specific permission value exists anywhere across all pages
  /// e.g. hasAnyPermission('Punching') returns true if any page has "Punching" permission
  Future<bool> hasAnyPermission(String permission) async {
    if (_cachedPermissions == null) {
      await _loadPermissions();
    }
    final target = permission.toLowerCase();
    final found = _cachedPermissions?.values.any((perms) => perms.contains(target)) ?? false;
    debugPrint('🔐 Check any permission "$permission": $found');
    return found;
  }

  /// Check if user has read access to a page
  Future<bool> canRead(String pageName) async {
    return await hasPermission(pageName, 'Read');
  }

  /// Check if user has write access to a page
  Future<bool> canWrite(String pageName) async {
    return await hasPermission(pageName, 'Write');
  }

  /// Check if user has update access to a page
  Future<bool> canUpdate(String pageName) async {
    return await hasPermission(pageName, 'Update');
  }

  /// Load permissions from SharedPreferences and build cache
  Future<void> _loadPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionsJson = prefs.getString('user_permissions');

      if (permissionsJson == null || permissionsJson.isEmpty) {
        debugPrint('⚠️ No permissions found in storage');
        _cachedPermissions = {};
        return;
      }

      final permissionsData = jsonDecode(permissionsJson) as Map<String, dynamic>;
      final permissionsList = permissionsData['permissions'] as List<dynamic>?;

      if (permissionsList == null) {
        debugPrint('⚠️ No permissions list found');
        _cachedPermissions = {};
        return;
      }

      // Build a map of page_name -> [permissions]
      final Map<String, List<String>> permissionsMap = {};

      for (var item in permissionsList) {
        final pageName = item['page_name']?.toString().toLowerCase();
        final permission = item['permission']?.toString().toLowerCase();

        if (pageName != null && permission != null) {
          if (!permissionsMap.containsKey(pageName)) {
            permissionsMap[pageName] = [];
          }
          permissionsMap[pageName]!.add(permission);
        }
      }

      _cachedPermissions = permissionsMap;
      debugPrint('✅ Loaded permissions for ${permissionsMap.length} pages');
      debugPrint('📋 Pages: ${permissionsMap.keys.join(', ')}');
    } catch (e) {
      debugPrint('❌ Error loading permissions: $e');
      _cachedPermissions = {};
    }
  }

  /// Clear all permissions (useful for logout)
  Future<void> clearPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_permissions');
      _cachedPermissions = null;
      debugPrint('✅ Permissions cleared');
    } catch (e) {
      debugPrint('❌ Error clearing permissions: $e');
    }
  }

  /// Get all available pages (for debugging)
  Future<List<String>> getAllPages() async {
    if (_cachedPermissions == null) {
      await _loadPermissions();
    }
    return _cachedPermissions?.keys.toList() ?? [];
  }

  /// Print all permissions (for debugging)
  Future<void> printAllPermissions() async {
    if (_cachedPermissions == null) {
      await _loadPermissions();
    }

    debugPrint('📋 ===== ALL PERMISSIONS =====');
    _cachedPermissions?.forEach((page, permissions) {
      debugPrint('   $page: ${permissions.join(', ')}');
    });
    debugPrint('📋 ============================');
  }
}
