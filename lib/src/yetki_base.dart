import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'exceptions/yetki_exception.dart';
import 'models/permission.dart';
import 'models/role.dart';
import 'models/user.dart';

/// Yetki is a Role Based Access Control (RBAC) library for Dart.
/// It provides a simple and flexible way to manage roles and permissions
/// with optional caching and singleton instance capabilities.
class Yetki {
  /// Singleton instance of [Yetki]
  static Yetki? _instance;

  /// Configuration options
  final bool _useCache;

  /// Storage key for cache
  static const String _cacheKey = 'yetki_cache';

  /// Internal storage
  final Map<String, Role> _roles = {};
  final Map<String, Permission> _permissions = {};
  YetkiUser? _currentUser;

  /// Creates a new instance of [Yetki].
  ///
  /// [useSingleton] - Whether to use singleton pattern (default: false)
  /// [useCache] - Whether to use cache with shared_preferences (default: true)
  factory Yetki({bool useSingleton = false, bool useCache = true}) {
    if (useSingleton && _instance != null) {
      return _instance!;
    }

    final instance = Yetki._internal(useCache: useCache);

    if (useSingleton) {
      _instance = instance;
    }

    return instance;
  }

  /// Internal constructor
  Yetki._internal({bool useCache = true}) : _useCache = useCache {
    if (_useCache) {
      _loadFromCache();
    }
  }

  /// Clears the singleton instance.
  /// Useful for testing and resetting the state.
  static void clearInstance() {
    _instance = null;
  }

  /// Adds a new permission to the system.
  ///
  /// [permission] - The permission object to add
  ///
  /// Returns the added permission
  /// Throws [YetkiException] if permission with the same id already exists
  Permission addPermission(Permission permission) {
    if (_permissions.containsKey(permission.id)) {
      throw YetkiException('Permission with id ${permission.id} already exists');
    }

    _permissions[permission.id] = permission;
    _saveToCache();
    return permission;
  }

  /// Gets a permission by id.
  ///
  /// [id] - The id of the permission
  ///
  /// Returns the permission or null if not found
  Permission? getPermission(String id) {
    return _permissions[id];
  }

  /// Removes a permission from the system.
  ///
  /// [id] - The id of the permission to remove
  ///
  /// Returns true if the permission was removed, false otherwise
  bool removePermission(String id) {
    final removed = _permissions.remove(id) != null;

    if (removed) {
      // Remove this permission from all roles
      for (final role in _roles.values) {
        role.removePermission(id);
      }
      _saveToCache();
    }

    return removed;
  }

  /// Adds a new role to the system.
  ///
  /// [role] - The role object to add
  ///
  /// Returns the added role
  /// Throws [YetkiException] if role with the same id already exists
  Role addRole(Role role) {
    if (_roles.containsKey(role.id)) {
      throw YetkiException('Role with id ${role.id} already exists');
    }

    _roles[role.id] = role;
    _saveToCache();
    return role;
  }

  /// Gets a role by id.
  ///
  /// [id] - The id of the role
  ///
  /// Returns the role or null if not found
  Role? getRole(String id) {
    return _roles[id];
  }

  /// Updates an existing role.
  ///
  /// [role] - The updated role object
  ///
  /// Returns the updated role
  /// Throws [YetkiException] if role does not exist
  Role updateRole(Role role) {
    if (!_roles.containsKey(role.id)) {
      throw YetkiException('Role with id ${role.id} does not exist');
    }

    _roles[role.id] = role;
    _saveToCache();
    return role;
  }

  /// Removes a role from the system.
  ///
  /// [id] - The id of the role to remove
  ///
  /// Returns true if the role was removed, false otherwise
  bool removeRole(String id) {
    final removed = _roles.remove(id) != null;

    if (removed) {
      _saveToCache();
    }

    return removed;
  }

  /// Sets the current user.
  ///
  /// [user] - The user to set as current
  void setUser(YetkiUser user) {
    _currentUser = user;
    _saveToCache();
  }

  /// Gets the current user.
  ///
  /// Returns the current user or null if not set
  YetkiUser? getCurrentUser() {
    return _currentUser;
  }

  /// Clears the current user.
  void clearUser() {
    _currentUser = null;
    _saveToCache();
  }

  /// Checks if the current user has a specific permission.
  ///
  /// [permissionId] - The id of the permission to check
  ///
  /// Returns true if the user has the permission, false otherwise
  bool hasPermission(String permissionId) {
    if (_currentUser == null) {
      return false;
    }

    // Direct permission check
    if (_currentUser!.hasDirectPermission(permissionId)) {
      return true;
    }

    // Check through roles
    for (final roleId in _currentUser!.roles) {
      final role = _roles[roleId];
      if (role != null && role.hasPermission(permissionId)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the current user has all the specified permissions.
  ///
  /// [permissionIds] - The list of permission ids to check
  ///
  /// Returns true if the user has all permissions, false otherwise
  bool hasAllPermissions(List<String> permissionIds) {
    return permissionIds.every(hasPermission);
  }

  /// Checks if the current user has any of the specified permissions.
  ///
  /// [permissionIds] - The list of permission ids to check
  ///
  /// Returns true if the user has at least one of the permissions, false otherwise
  bool hasAnyPermission(List<String> permissionIds) {
    return permissionIds.any(hasPermission);
  }

  /// Checks if the current user has a specific role.
  ///
  /// [roleId] - The id of the role to check
  ///
  /// Returns true if the user has the role, false otherwise
  bool hasRole(String roleId) {
    return _currentUser != null && _currentUser!.hasRole(roleId);
  }

  /// Checks if the current user has all the specified roles.
  ///
  /// [roleIds] - The list of role ids to check
  ///
  /// Returns true if the user has all roles, false otherwise
  bool hasAllRoles(List<String> roleIds) {
    return _currentUser != null && roleIds.every(_currentUser!.hasRole);
  }

  /// Checks if the current user has any of the specified roles.
  ///
  /// [roleIds] - The list of role ids to check
  ///
  /// Returns true if the user has at least one of the roles, false otherwise
  bool hasAnyRole(List<String> roleIds) {
    return _currentUser != null && roleIds.any(_currentUser!.hasRole);
  }

  /// Gets all roles in the system.
  ///
  /// Returns a list of all roles
  List<Role> getAllRoles() {
    return _roles.values.toList();
  }

  /// Gets all permissions in the system.
  ///
  /// Returns a list of all permissions
  List<Permission> getAllPermissions() {
    return _permissions.values.toList();
  }

  /// Loads the state from cache.
  Future<void> _loadFromCache() async {
    if (!_useCache) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);

      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;

        // Load permissions
        if (data.containsKey('permissions')) {
          final permissionsData = data['permissions'] as Map<String, dynamic>;
          _permissions.clear();

          permissionsData.forEach((key, value) {
            _permissions[key] = Permission.fromJson(value);
          });
        }

        // Load roles
        if (data.containsKey('roles')) {
          final rolesData = data['roles'] as Map<String, dynamic>;
          _roles.clear();

          rolesData.forEach((key, value) {
            _roles[key] = Role.fromJson(value);
          });
        }

        // Load current user
        if (data.containsKey('currentUser') && data['currentUser'] != null) {
          _currentUser = YetkiUser.fromJson(data['currentUser']);
        }
      }
    } catch (e) {
      // Silently fail on cache load errors
      print('Yetki: Error loading from cache: $e');
    }
  }

  /// Saves the current state to cache.
  Future<void> _saveToCache() async {
    if (!_useCache) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Prepare data for serialization
      final permissionsMap = <String, dynamic>{};
      for (final entry in _permissions.entries) {
        permissionsMap[entry.key] = entry.value.toJson();
      }

      final rolesMap = <String, dynamic>{};
      for (final entry in _roles.entries) {
        rolesMap[entry.key] = entry.value.toJson();
      }

      final data = {
        'permissions': permissionsMap,
        'roles': rolesMap,
        'currentUser': _currentUser?.toJson(),
      };

      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      // Silently fail on cache save errors
      print('Yetki: Error saving to cache: $e');
    }
  }

  /// Clears all data from the cache.
  Future<void> clearCache() async {
    if (!_useCache) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      print('Yetki: Error clearing cache: $e');
    }
  }

  /// Exports all data to a JSON string.
  ///
  /// Returns a JSON string representation of all data
  String exportToJson() {
    final permissionsMap = <String, dynamic>{};
    for (final entry in _permissions.entries) {
      permissionsMap[entry.key] = entry.value.toJson();
    }

    final rolesMap = <String, dynamic>{};
    for (final entry in _roles.entries) {
      rolesMap[entry.key] = entry.value.toJson();
    }

    final data = {'permissions': permissionsMap, 'roles': rolesMap};

    return jsonEncode(data);
  }

  /// Imports data from a JSON string.
  ///
  /// [json] - The JSON string to import
  ///
  /// Returns true if import was successful, false otherwise
  bool importFromJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;

      // Import permissions
      if (data.containsKey('permissions')) {
        final permissionsData = data['permissions'] as Map<String, dynamic>;
        _permissions.clear();

        permissionsData.forEach((key, value) {
          _permissions[key] = Permission.fromJson(value);
        });
      }

      // Import roles
      if (data.containsKey('roles')) {
        final rolesData = data['roles'] as Map<String, dynamic>;
        _roles.clear();

        rolesData.forEach((key, value) {
          _roles[key] = Role.fromJson(value);
        });
      }

      _saveToCache();
      return true;
    } catch (e) {
      print('Yetki: Error importing from JSON: $e');
      return false;
    }
  }
}
