<a href="https://www.buymeacoffee.com/envererdem" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

# Yetki

Role-based access control (RBAC) for Dart and Flutter.

| Package | Description |
| --- | --- |
| [`yetki`](packages/yetki) [![pub](https://img.shields.io/pub/v/yetki.svg)](https://pub.dev/packages/yetki) | Pure Dart core: permissions, roles with inheritance, wildcard grants, persistence and change notifications. |
| [`yetki_flutter`](packages/yetki_flutter) [![pub](https://img.shields.io/pub/v/yetki_flutter.svg)](https://pub.dev/packages/yetki_flutter) | Flutter bindings: `YetkiScope`, guard widgets, a router `Listenable` and shared_preferences storage. |

Upgrading from 0.1.x? See the
[migration guide](packages/yetki/README.md#migration-from-01x).

## Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces).

```bash
flutter pub get                    # resolves both packages
(cd packages/yetki && dart test)
(cd packages/yetki_flutter && flutter test)
```

## API Reference

### Yetki

Main class for managing the RBAC system.

#### Constructor

```dart
Yetki({
  bool useSingleton = false,
  bool useCache = true,
})
```

#### Methods

- `Permission addPermission(Permission permission)`
- `Permission? getPermission(String id)`
- `bool removePermission(String id)`
- `Role addRole(Role role)`
- `Role? getRole(String id)`
- `Role updateRole(Role role)`
- `bool removeRole(String id)`
- `void setUser(YetkiUser user)`
- `YetkiUser? getCurrentUser()`
- `void clearUser()`
- `bool hasPermission(String permissionId)`
- `bool hasAllPermissions(List<String> permissionIds)`
- `bool hasAnyPermission(List<String> permissionIds)`
- `bool hasRole(String roleId)`
- `bool hasAllRoles(List<String> roleIds)`
- `bool hasAnyRole(List<String> roleIds)`
- `List<Role> getAllRoles()`
- `List<Permission> getAllPermissions()`
- `Future<void> clearCache()`
- `String exportToJson()`
- `bool importFromJson(String json)`

### Permission

Represents a permission in the RBAC system.

```dart
Permission({
  required String id,
  required String name,
  String? description,
})
```

### Role

Represents a role with associated permissions.

```dart
Role({
  required String id,
  required String name,
  String? description,
  Set<String>? permissionIds,
})
```

Methods:
- `bool addPermission(String permissionId)`
- `bool removePermission(String permissionId)`
- `bool hasPermission(String permissionId)`
- `void clearPermissions()`

### YetkiUser

Represents a user in the RBAC system.

```dart
YetkiUser({
  required String id,
  required String name,
  Set<String>? roleIds,
  Set<String>? directPermissionIds,
})
```

Methods:
- `bool assignRole(String roleId)`
- `bool revokeRole(String roleId)`
- `bool hasRole(String roleId)`
- `bool grantDirectPermission(String permissionId)`
- `bool revokeDirectPermission(String permissionId)`
- `bool hasDirectPermission(String permissionId)`
- `void clearRoles()`
- `void clearDirectPermissions()`

## Example: Flutter Integration

```dart
import 'package:flutter/material.dart';
import 'package:yetki/yetki.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Yetki yetki = Yetki(useSingleton: true);
  
  MyApp() {
    // Initialize permissions and roles
    _initializeRBAC();
  }
  
  void _initializeRBAC() {
    // Add permissions
    yetki.addPermission(Permission(id: 'view_dashboard', name: 'View Dashboard'));
    yetki.addPermission(Permission(id: 'manage_users', name: 'Manage Users'));
    
    // Add roles
    final userRole = Role(id: 'user', name: 'User');
    userRole.addPermission('view_dashboard');
    
    final adminRole = Role(id: 'admin', name: 'Admin');
    adminRole.addPermission('view_dashboard');
    adminRole.addPermission('manage_users');
    
    yetki.addRole(userRole);
    yetki.addRole(adminRole);
    
    // For this example, let's set a user with admin role
    final currentUser = YetkiUser(id: '1', name: 'Admin User');
    currentUser.assignRole('admin');
    yetki.setUser(currentUser);
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Yetki RBAC Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Only show if user has permission
              if (yetki.hasPermission('view_dashboard'))
                ElevatedButton(
                  child: Text('View Dashboard'),
                  onPressed: () {
                    print('Navigating to dashboard');
                  },
                ),
              
              SizedBox(height: 16),
              
              // Only show if user has permission
              if (yetki.hasPermission('manage_users'))
                ElevatedButton(
                  child: Text('Manage Users'),
                  onPressed: () {
                    print('Navigating to user management');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## License

MIT
