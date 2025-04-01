// File: test/yetki_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yetki/yetki.dart';

void main() {
  group('Yetki - Permissions', () {
    late Yetki yetki;

    setUp(() {
      yetki = Yetki(useCache: false);
    });

    test('Add and retrieve permission', () {
      final permission = Permission(
        id: 'test_permission',
        name: 'Test Permission',
        description: 'A test permission',
      );

      yetki.addPermission(permission);
      final retrieved = yetki.getPermission('test_permission');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test_permission'));
      expect(retrieved.name, equals('Test Permission'));
      expect(retrieved.description, equals('A test permission'));
    });

    test('Remove permission', () {
      final permission = Permission(id: 'test_permission', name: 'Test Permission');

      yetki.addPermission(permission);
      expect(yetki.getPermission('test_permission'), isNotNull);

      final result = yetki.removePermission('test_permission');
      expect(result, isTrue);
      expect(yetki.getPermission('test_permission'), isNull);
    });

    test('Cannot add duplicate permission', () {
      final permission = Permission(id: 'test_permission', name: 'Test Permission');

      yetki.addPermission(permission);

      expect(() => yetki.addPermission(permission), throwsA(isA<YetkiException>()));
    });

    test('Get all permissions', () {
      final permission1 = Permission(id: 'p1', name: 'Permission 1');
      final permission2 = Permission(id: 'p2', name: 'Permission 2');

      yetki.addPermission(permission1);
      yetki.addPermission(permission2);

      final all = yetki.getAllPermissions();
      expect(all.length, equals(2));
      expect(all.any((p) => p.id == 'p1'), isTrue);
      expect(all.any((p) => p.id == 'p2'), isTrue);
    });
  });

  group('Yetki - Roles', () {
    late Yetki yetki;

    setUp(() {
      yetki = Yetki(useCache: false);
    });

    test('Add and retrieve role', () {
      final role = Role(id: 'test_role', name: 'Test Role', description: 'A test role');

      yetki.addRole(role);
      final retrieved = yetki.getRole('test_role');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test_role'));
      expect(retrieved.name, equals('Test Role'));
      expect(retrieved.description, equals('A test role'));
    });

    test('Add permissions to role', () {
      final permission1 = Permission(id: 'permission1', name: 'Permission 1');

      final permission2 = Permission(id: 'permission2', name: 'Permission 2');

      yetki.addPermission(permission1);
      yetki.addPermission(permission2);

      final role = Role(id: 'test_role', name: 'Test Role');

      role.addPermission(permission1.id);
      role.addPermission(permission2.id);

      yetki.addRole(role);

      final retrieved = yetki.getRole('test_role');
      expect(retrieved!.hasPermission(permission1.id), isTrue);
      expect(retrieved.hasPermission(permission2.id), isTrue);
      expect(retrieved.hasPermission('nonexistent'), isFalse);
    });

    test('Update role', () {
      final role = Role(id: 'test_role', name: 'Original Name');

      yetki.addRole(role);

      final updatedRole = Role(
        id: 'test_role',
        name: 'Updated Name',
        description: 'Updated description',
      );

      yetki.updateRole(updatedRole);

      final retrieved = yetki.getRole('test_role');
      expect(retrieved!.name, equals('Updated Name'));
      expect(retrieved.description, equals('Updated description'));
    });

    test('Cannot update non-existent role', () {
      final role = Role(id: 'nonexistent_role', name: 'Test Role');

      expect(() => yetki.updateRole(role), throwsA(isA<YetkiException>()));
    });

    test('Remove role', () {
      final role = Role(id: 'test_role', name: 'Test Role');

      yetki.addRole(role);
      expect(yetki.getRole('test_role'), isNotNull);

      final result = yetki.removeRole('test_role');
      expect(result, isTrue);
      expect(yetki.getRole('test_role'), isNull);
    });

    test('Remove nonexistent role returns false', () {
      final result = yetki.removeRole('nonexistent');
      expect(result, isFalse);
    });

    test('Get all roles', () {
      final role1 = Role(id: 'r1', name: 'Role 1');
      final role2 = Role(id: 'r2', name: 'Role 2');

      yetki.addRole(role1);
      yetki.addRole(role2);

      final all = yetki.getAllRoles();
      expect(all.length, equals(2));
      expect(all.any((r) => r.id == 'r1'), isTrue);
      expect(all.any((r) => r.id == 'r2'), isTrue);
    });
  });

  group('Yetki - Users and Permissions', () {
    late Yetki yetki;
    late Permission viewPermission;
    late Permission createPermission;
    late Permission editPermission;
    late Permission deletePermission;
    late Role viewerRole;
    late Role editorRole;
    late Role adminRole;

    setUp(() {
      yetki = Yetki(useCache: false);

      // Create permissions
      viewPermission = Permission(id: 'view', name: 'View');
      createPermission = Permission(id: 'create', name: 'Create');
      editPermission = Permission(id: 'edit', name: 'Edit');
      deletePermission = Permission(id: 'delete', name: 'Delete');

      yetki.addPermission(viewPermission);
      yetki.addPermission(createPermission);
      yetki.addPermission(editPermission);
      yetki.addPermission(deletePermission);

      // Create roles
      viewerRole = Role(id: 'viewer', name: 'Viewer');
      viewerRole.addPermission(viewPermission.id);

      editorRole = Role(id: 'editor', name: 'Editor');
      editorRole.addPermission(viewPermission.id);
      editorRole.addPermission(createPermission.id);
      editorRole.addPermission(editPermission.id);

      adminRole = Role(id: 'admin', name: 'Administrator');
      adminRole.addPermission(viewPermission.id);
      adminRole.addPermission(createPermission.id);
      adminRole.addPermission(editPermission.id);
      adminRole.addPermission(deletePermission.id);

      yetki.addRole(viewerRole);
      yetki.addRole(editorRole);
      yetki.addRole(adminRole);
    });

    test('User with role permissions', () {
      final user = YetkiUser(id: 'user1', name: 'Test User');

      user.assignRole(editorRole.id);
      yetki.setUser(user);

      expect(yetki.hasPermission(viewPermission.id), isTrue);
      expect(yetki.hasPermission(createPermission.id), isTrue);
      expect(yetki.hasPermission(editPermission.id), isTrue);
      expect(yetki.hasPermission(deletePermission.id), isFalse);
    });

    test('User with direct permissions', () {
      final user = YetkiUser(id: 'user2', name: 'Direct Permission User');

      user.grantDirectPermission(deletePermission.id);
      yetki.setUser(user);

      expect(yetki.hasPermission(viewPermission.id), isFalse);
      expect(yetki.hasPermission(deletePermission.id), isTrue);
    });

    test('User with combined permissions', () {
      final user = YetkiUser(id: 'user3', name: 'Combined User');

      user.assignRole(viewerRole.id);
      user.grantDirectPermission(editPermission.id);
      yetki.setUser(user);

      expect(yetki.hasPermission(viewPermission.id), isTrue);
      expect(yetki.hasPermission(createPermission.id), isFalse);
      expect(yetki.hasPermission(editPermission.id), isTrue);
      expect(yetki.hasPermission(deletePermission.id), isFalse);
    });

    test('Check has all/any permissions', () {
      final user = YetkiUser(id: 'user4', name: 'Test User');

      user.assignRole(editorRole.id);
      yetki.setUser(user);

      expect(yetki.hasAllPermissions([viewPermission.id, createPermission.id]), isTrue);

      expect(yetki.hasAllPermissions([viewPermission.id, deletePermission.id]), isFalse);

      expect(yetki.hasAnyPermission([deletePermission.id, viewPermission.id]), isTrue);

      expect(yetki.hasAnyPermission(['nonexistent1', 'nonexistent2']), isFalse);
    });

    test('Check has all/any roles', () {
      final user = YetkiUser(id: 'user5', name: 'Test User');

      user.assignRole(editorRole.id);
      user.assignRole(viewerRole.id);
      yetki.setUser(user);

      expect(yetki.hasAllRoles([viewerRole.id, editorRole.id]), isTrue);

      expect(yetki.hasAllRoles([viewerRole.id, adminRole.id]), isFalse);

      expect(yetki.hasAnyRole([adminRole.id, viewerRole.id]), isTrue);

      expect(yetki.hasAnyRole(['nonexistent1', 'nonexistent2']), isFalse);
    });

    test('No current user returns false for permission checks', () {
      yetki.clearUser();

      expect(yetki.hasPermission(viewPermission.id), isFalse);
      expect(yetki.hasAllPermissions([viewPermission.id]), isFalse);
      expect(yetki.hasAnyPermission([viewPermission.id]), isFalse);
    });

    test('No current user returns false for role checks', () {
      yetki.clearUser();

      expect(yetki.hasRole(viewerRole.id), isFalse);
      expect(yetki.hasAllRoles([viewerRole.id]), isFalse);
      expect(yetki.hasAnyRole([viewerRole.id]), isFalse);
    });

    test('Set and get current user', () {
      final user = YetkiUser(id: 'user6', name: 'Current User Test');

      yetki.setUser(user);
      final current = yetki.getCurrentUser();

      expect(current, isNotNull);
      expect(current!.id, equals('user6'));
      expect(current.name, equals('Current User Test'));
    });

    test('Clear user works', () {
      final user = YetkiUser(id: 'user7', name: 'To Be Cleared');

      yetki.setUser(user);
      expect(yetki.getCurrentUser(), isNotNull);

      yetki.clearUser();
      expect(yetki.getCurrentUser(), isNull);
    });
  });

  group('Yetki - User class', () {
    test('User role management', () {
      final user = YetkiUser(id: 'test_user', name: 'Test User');

      expect(user.roles, isEmpty);

      // Add a role
      final added = user.assignRole('role1');
      expect(added, isTrue);
      expect(user.roles.length, equals(1));
      expect(user.hasRole('role1'), isTrue);

      // Adding same role again returns false
      final addedAgain = user.assignRole('role1');
      expect(addedAgain, isFalse);
      expect(user.roles.length, equals(1));

      // Remove role
      final removed = user.revokeRole('role1');
      expect(removed, isTrue);
      expect(user.roles, isEmpty);

      // Remove nonexistent role
      final removedNonexistent = user.revokeRole('role1');
      expect(removedNonexistent, isFalse);

      // Add multiple roles and clear
      user.assignRole('role1');
      user.assignRole('role2');
      expect(user.roles.length, equals(2));

      user.clearRoles();
      expect(user.roles, isEmpty);
    });

    test('User direct permission management', () {
      final user = YetkiUser(id: 'test_user', name: 'Test User');

      expect(user.directPermissions, isEmpty);

      // Add a permission
      final added = user.grantDirectPermission('perm1');
      expect(added, isTrue);
      expect(user.directPermissions.length, equals(1));
      expect(user.hasDirectPermission('perm1'), isTrue);

      // Adding same permission again returns false
      final addedAgain = user.grantDirectPermission('perm1');
      expect(addedAgain, isFalse);
      expect(user.directPermissions.length, equals(1));

      // Remove permission
      final removed = user.revokeDirectPermission('perm1');
      expect(removed, isTrue);
      expect(user.directPermissions, isEmpty);

      // Remove nonexistent permission
      final removedNonexistent = user.revokeDirectPermission('perm1');
      expect(removedNonexistent, isFalse);

      // Add multiple permissions and clear
      user.grantDirectPermission('perm1');
      user.grantDirectPermission('perm2');
      expect(user.directPermissions.length, equals(2));

      user.clearDirectPermissions();
      expect(user.directPermissions, isEmpty);
    });
  });

  group('Yetki - Singleton', () {
    setUp(() {
      Yetki.clearInstance();
    });

    test('Singleton mode returns same instance', () {
      final yetki1 = Yetki(useSingleton: true);
      final yetki2 = Yetki(useSingleton: true);

      expect(identical(yetki1, yetki2), isTrue);
    });

    test('Non-singleton mode returns different instances', () {
      final yetki1 = Yetki(useSingleton: false);
      final yetki2 = Yetki(useSingleton: false);

      expect(identical(yetki1, yetki2), isFalse);
    });

    test('Clear instance works', () {
      final yetki1 = Yetki(useSingleton: true);
      Yetki.clearInstance();
      final yetki2 = Yetki(useSingleton: true);

      expect(identical(yetki1, yetki2), isFalse);
    });
  });

  group('Yetki - Serialization', () {
    test('Export and import works', () {
      final yetki = Yetki(useCache: false);

      // Add some test data
      final permission = Permission(id: 'test_perm', name: 'Test Permission');

      final role = Role(id: 'test_role', name: 'Test Role');

      role.addPermission(permission.id);

      yetki.addPermission(permission);
      yetki.addRole(role);

      // Export to JSON
      final jsonData = yetki.exportToJson();

      // Create a new instance and import
      final newYetki = Yetki(useCache: false);
      newYetki.importFromJson(jsonData);

      // Verify data was imported correctly
      expect(newYetki.getPermission('test_perm'), isNotNull);
      expect(newYetki.getRole('test_role'), isNotNull);
      expect(newYetki.getRole('test_role')!.hasPermission('test_perm'), isTrue);
    });

    test('Import invalid JSON returns false', () {
      final yetki = Yetki(useCache: false);
      final result = yetki.importFromJson('{"invalid": "json"');
      expect(result, isFalse);
    });
  });

  group('Yetki - Permission removal from roles', () {
    test('Removing a permission also removes it from roles', () {
      final yetki = Yetki(useCache: false);

      // Create permission and role
      final permission = Permission(id: 'test_perm', name: 'Test Permission');
      final role = Role(id: 'test_role', name: 'Test Role');

      yetki.addPermission(permission);
      role.addPermission(permission.id);
      yetki.addRole(role);

      // Check permission is in role
      expect(yetki.getRole('test_role')!.hasPermission('test_perm'), isTrue);

      // Remove permission
      yetki.removePermission('test_perm');

      // Check it was removed from role
      expect(yetki.getRole('test_role')!.hasPermission('test_perm'), isFalse);
    });
  });

  group('Yetki - Role permission management', () {
    test('Role permission methods work correctly', () {
      final role = Role(id: 'test_role', name: 'Test Role');

      // Initially empty
      expect(role.permissionIds, isEmpty);

      // Add permission
      role.addPermission('perm1');
      expect(role.permissionIds.length, equals(1));
      expect(role.hasPermission('perm1'), isTrue);

      // Add another
      role.addPermission('perm2');
      expect(role.permissionIds.length, equals(2));

      // Remove permission
      role.removePermission('perm1');
      expect(role.permissionIds.length, equals(1));
      expect(role.hasPermission('perm1'), isFalse);
      expect(role.hasPermission('perm2'), isTrue);

      // Clear all
      role.clearPermissions();
      expect(role.permissionIds, isEmpty);
    });
  });

  group('Yetki - Initialization with data', () {
    test('Role initializes with permissions', () {
      final role = Role(
        id: 'test_role',
        name: 'Test Role',
        permissionIds: {'perm1', 'perm2'},
      );

      expect(role.permissionIds.length, equals(2));
      expect(role.hasPermission('perm1'), isTrue);
      expect(role.hasPermission('perm2'), isTrue);
    });

    test('User initializes with roles and permissions', () {
      final user = YetkiUser(
        id: 'test_user',
        name: 'Test User',
        roleIds: {'role1', 'role2'},
        directPermissionIds: {'perm1', 'perm2'},
      );

      expect(user.roles.length, equals(2));
      expect(user.directPermissions.length, equals(2));
      expect(user.hasRole('role1'), isTrue);
      expect(user.hasRole('role2'), isTrue);
      expect(user.hasDirectPermission('perm1'), isTrue);
      expect(user.hasDirectPermission('perm2'), isTrue);
    });
  });

  group('Yetki - Object equality', () {
    test('Permission equality based on ID', () {
      final perm1a = Permission(id: 'p1', name: 'Permission 1');
      final perm1b = Permission(id: 'p1', name: 'Different Name');
      final perm2 = Permission(id: 'p2', name: 'Permission 2');

      expect(perm1a == perm1b, isTrue);
      expect(perm1a == perm2, isFalse);
      expect(perm1a.hashCode == perm1b.hashCode, isTrue);
    });

    test('Role equality based on ID', () {
      final role1a = Role(id: 'r1', name: 'Role 1');
      final role1b = Role(id: 'r1', name: 'Different Name');
      final role2 = Role(id: 'r2', name: 'Role 2');

      expect(role1a == role1b, isTrue);
      expect(role1a == role2, isFalse);
      expect(role1a.hashCode == role1b.hashCode, isTrue);
    });

    test('User equality based on ID', () {
      final user1a = YetkiUser(id: 'u1', name: 'User 1');
      final user1b = YetkiUser(id: 'u1', name: 'Different Name');
      final user2 = YetkiUser(id: 'u2', name: 'User 2');

      expect(user1a == user1b, isTrue);
      expect(user1a == user2, isFalse);
      expect(user1a.hashCode == user1b.hashCode, isTrue);
    });
  });

  group('Yetki - Serialization of models', () {
    test('Permission serialization', () {
      final permission = Permission(
        id: 'test_id',
        name: 'Test Name',
        description: 'Test Description',
      );

      final json = permission.toJson();
      final deserialized = Permission.fromJson(json);

      expect(deserialized.id, equals('test_id'));
      expect(deserialized.name, equals('Test Name'));
      expect(deserialized.description, equals('Test Description'));
    });

    test('Role serialization', () {
      final role = Role(
        id: 'test_id',
        name: 'Test Name',
        description: 'Test Description',
      );

      role.addPermission('perm1');
      role.addPermission('perm2');

      final json = role.toJson();
      final deserialized = Role.fromJson(json);

      expect(deserialized.id, equals('test_id'));
      expect(deserialized.name, equals('Test Name'));
      expect(deserialized.description, equals('Test Description'));
      expect(deserialized.permissionIds.length, equals(2));
      expect(deserialized.hasPermission('perm1'), isTrue);
      expect(deserialized.hasPermission('perm2'), isTrue);
    });

    test('User serialization', () {
      final user = YetkiUser(id: 'test_id', name: 'Test Name');

      user.assignRole('role1');
      user.assignRole('role2');
      user.grantDirectPermission('perm1');

      final json = user.toJson();
      final deserialized = YetkiUser.fromJson(json);

      expect(deserialized.id, equals('test_id'));
      expect(deserialized.name, equals('Test Name'));
      expect(deserialized.roles.length, equals(2));
      expect(deserialized.directPermissions.length, equals(1));
      expect(deserialized.hasRole('role1'), isTrue);
      expect(deserialized.hasRole('role2'), isTrue);
      expect(deserialized.hasDirectPermission('perm1'), isTrue);
    });
  });
}
