# Yetki

A flexible Role Based Access Control (RBAC) library for Dart and Flutter applications.

## Features

- 🔑 Simple and intuitive role-based access control
- 🔄 Support for hierarchical permissions
- 💾 Optional caching with shared_preferences
- 🧩 Flexible singleton pattern support
- 📦 Easy serialization and deserialization
- 🛠️ Customizable for various use cases

## Installation

Add the package to your pubspec.yaml:

```yaml
dependencies:
  yetki: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Basic Usage

```dart
import 'package:yetki/yetki.dart';

void main() {
  // Create a new Yetki instance
  final yetki = Yetki();
  
  // Create permissions
  final viewUsers = Permission(id: 'view_users', name: 'View Users');
  final createUsers = Permission(id: 'create_users', name: 'Create Users');
  final editUsers = Permission(id: 'edit_users', name: 'Edit Users');
  final deleteUsers = Permission(id: 'delete_users', name: 'Delete Users');
  
  // Add permissions to the system
  yetki.addPermission(viewUsers);
  yetki.addPermission(createUsers);
  yetki.addPermission(editUsers);
  yetki.addPermission(deleteUsers);
  
  // Create roles
  final viewerRole = Role(
    id: 'viewer', 
    name: 'Viewer',
    description: 'Can only view resources',
  );
  viewerRole.addPermission(viewUsers.id);
  
  final editorRole = Role(
    id: 'editor', 
    name: 'Editor',
    description: 'Can view and edit resources',
  );
  editorRole.addPermission(viewUsers.id);
  editorRole.addPermission(createUsers.id);
  editorRole.addPermission(editUsers.id);
  
  final adminRole = Role(
    id: 'admin', 
    name: 'Administrator',
    description: 'Has full access to all resources',
  );
  adminRole.addPermission(viewUsers.id);
  adminRole.addPermission(createUsers.id);
  adminRole.addPermission(editUsers.id);
  adminRole.addPermission(deleteUsers.id);
  
  // Add roles to the system
  yetki.addRole(viewerRole);
  yetki.addRole(editorRole);
  yetki.addRole(adminRole);
  
  // Create and set a user
  final user = YetkiUser(
    id: 'user123',
    name: 'John Doe',
  );
  user.assignRole(editorRole.id);
  
  yetki.setUser(user);
  
  // Check permissions
  print(yetki.hasPermission(viewUsers.id));    // true
  print(yetki.hasPermission(createUsers.id));  // true
  print(yetki.hasPermission(editUsers.id));    // true
  print(yetki.hasPermission(deleteUsers.id));  // false
  
  // Check roles
  print(yetki.hasRole(viewerRole.id));         // false
  print(yetki.hasRole(editorRole.id));         // true
  print(yetki.hasRole(adminRole.id));          // false
}
```

## Advanced Features

### Using Singleton Pattern

```dart
// Create with singleton enabled
final yetki1 = Yetki(useSingleton: true);

// This will return the same instance
final yetki2 = Yetki(useSingleton: true);

print(identical(yetki1, yetki2));  // true
```

### Working with Caching

```dart
// Create with caching enabled (default)
final yetki = Yetki(useCache: true);

// Permissions and roles will be automatically cached
// and restored when the app restarts

// To clear the cache
await yetki.clearCache();
```

### Direct Permissions for Users

```dart
final user = YetkiUser(
  id: 'user123',
  name: 'John Doe',
);

// Assign roles
user.assignRole('editor');

// Grant direct permissions
user.grantDirectPermission('special_permission');

yetki.setUser(user);

// Check direct permission
print(user.hasDirectPermission('special_permission'));  // true
```

### Exporting and Importing Data

```dart
// Export all permissions and roles to JSON
final jsonData = yetki.exportToJson();

// Import from JSON (useful for initialization)
yetki.importFromJson(jsonData);
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