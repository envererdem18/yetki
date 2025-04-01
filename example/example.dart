import 'package:yetki/yetki.dart';

void main() async {
  // Create a new Yetki instance with default settings
  // (useCache: true, useSingleton: false)
  final yetki = Yetki();

  print('=== Creating Permissions ===');

  // Create some permissions
  final viewDashboard = Permission(
    id: 'view_dashboard',
    name: 'View Dashboard',
    description: 'Allows viewing the main dashboard',
  );

  final createPosts = Permission(
    id: 'create_posts',
    name: 'Create Posts',
    description: 'Allows creating new posts',
  );

  final editPosts = Permission(
    id: 'edit_posts',
    name: 'Edit Posts',
    description: 'Allows editing existing posts',
  );

  final deletePosts = Permission(
    id: 'delete_posts',
    name: 'Delete Posts',
    description: 'Allows deleting posts',
  );

  final manageUsers = Permission(
    id: 'manage_users',
    name: 'Manage Users',
    description: 'Allows managing users',
  );

  // Add permissions to the system
  yetki.addPermission(viewDashboard);
  yetki.addPermission(createPosts);
  yetki.addPermission(editPosts);
  yetki.addPermission(deletePosts);
  yetki.addPermission(manageUsers);

  print('Added permissions:');
  for (final permission in yetki.getAllPermissions()) {
    print('- ${permission.name} (${permission.id})');
  }

  print('\n=== Creating Roles ===');

  // Create roles
  final viewerRole = Role(
    id: 'viewer',
    name: 'Viewer',
    description: 'Basic viewer with limited access',
  );
  viewerRole.addPermission(viewDashboard.id);

  final contributorRole = Role(
    id: 'contributor',
    name: 'Contributor',
    description: 'Can create and edit content',
  );
  contributorRole.addPermission(viewDashboard.id);
  contributorRole.addPermission(createPosts.id);
  contributorRole.addPermission(editPosts.id);

  final editorRole = Role(
    id: 'editor',
    name: 'Editor',
    description: 'Can manage all content',
  );
  editorRole.addPermission(viewDashboard.id);
  editorRole.addPermission(createPosts.id);
  editorRole.addPermission(editPosts.id);
  editorRole.addPermission(deletePosts.id);

  final adminRole = Role(
    id: 'admin',
    name: 'Administrator',
    description: 'Full system access',
  );
  adminRole.addPermission(viewDashboard.id);
  adminRole.addPermission(createPosts.id);
  adminRole.addPermission(editPosts.id);
  adminRole.addPermission(deletePosts.id);
  adminRole.addPermission(manageUsers.id);

  // Add roles to the system
  yetki.addRole(viewerRole);
  yetki.addRole(contributorRole);
  yetki.addRole(editorRole);
  yetki.addRole(adminRole);

  print('Added roles:');
  for (final role in yetki.getAllRoles()) {
    print(
      '- ${role.name} (${role.id}) with permissions: ${role.permissionIds.join(', ')}',
    );
  }

  print('\n=== Creating Users ===');

  // Create some users
  final viewerUser = YetkiUser(id: 'user1', name: 'John Viewer');
  viewerUser.assignRole(viewerRole.id);

  final contributorUser = YetkiUser(id: 'user2', name: 'Alice Contributor');
  contributorUser.assignRole(contributorRole.id);

  final editorUser = YetkiUser(id: 'user3', name: 'Bob Editor');
  editorUser.assignRole(editorRole.id);

  final adminUser = YetkiUser(id: 'user4', name: 'Charlie Admin');
  adminUser.assignRole(adminRole.id);

  // User with multiple roles
  final specialUser = YetkiUser(id: 'user5', name: 'David Special');
  specialUser.assignRole(contributorRole.id);
  // Grant a direct permission without a role
  specialUser.grantDirectPermission(deletePosts.id);

  print('Created users with different roles');

  print('\n=== Testing Permissions ===');

  // Test with viewer
  yetki.setUser(viewerUser);
  print('User: ${viewerUser.name}');
  print('Can view dashboard: ${yetki.hasPermission(viewDashboard.id)}');
  print('Can create posts: ${yetki.hasPermission(createPosts.id)}');
  print('Can edit posts: ${yetki.hasPermission(editPosts.id)}');
  print('Can delete posts: ${yetki.hasPermission(deletePosts.id)}');
  print('Can manage users: ${yetki.hasPermission(manageUsers.id)}');

  // Test with contributor
  yetki.setUser(contributorUser);
  print('\nUser: ${contributorUser.name}');
  print('Can view dashboard: ${yetki.hasPermission(viewDashboard.id)}');
  print('Can create posts: ${yetki.hasPermission(createPosts.id)}');
  print('Can edit posts: ${yetki.hasPermission(editPosts.id)}');
  print('Can delete posts: ${yetki.hasPermission(deletePosts.id)}');
  print('Can manage users: ${yetki.hasPermission(manageUsers.id)}');

  // Test with admin
  yetki.setUser(adminUser);
  print('\nUser: ${adminUser.name}');
  print('Can view dashboard: ${yetki.hasPermission(viewDashboard.id)}');
  print('Can create posts: ${yetki.hasPermission(createPosts.id)}');
  print('Can edit posts: ${yetki.hasPermission(editPosts.id)}');
  print('Can delete posts: ${yetki.hasPermission(deletePosts.id)}');
  print('Can manage users: ${yetki.hasPermission(manageUsers.id)}');

  // Test with special user with direct permission
  yetki.setUser(specialUser);
  print('\nUser: ${specialUser.name} (Contributor + direct delete permission)');
  print('Can view dashboard: ${yetki.hasPermission(viewDashboard.id)}');
  print('Can create posts: ${yetki.hasPermission(createPosts.id)}');
  print('Can edit posts: ${yetki.hasPermission(editPosts.id)}');
  print('Can delete posts: ${yetki.hasPermission(deletePosts.id)}');
  print('Can manage users: ${yetki.hasPermission(manageUsers.id)}');

  print('\n=== Testing Role-based Checks ===');
  yetki.setUser(specialUser);
  print('User: ${specialUser.name}');
  print('Is viewer: ${yetki.hasRole(viewerRole.id)}');
  print('Is contributor: ${yetki.hasRole(contributorRole.id)}');
  print('Is editor: ${yetki.hasRole(editorRole.id)}');
  print('Is admin: ${yetki.hasRole(adminRole.id)}');
  print(
    'Has any editor/admin role: ${yetki.hasAnyRole([editorRole.id, adminRole.id])}',
  );

  print('\n=== Serialization Example ===');

  // Export the current state
  final jsonData = yetki.exportToJson();
  print('Exported JSON data (${jsonData.length} characters)');

  // Create a new instance and import the data
  final newYetki = Yetki(useCache: false);
  newYetki.importFromJson(jsonData);

  print('Imported data to new instance:');
  print('- ${newYetki.getAllPermissions().length} permissions');
  print('- ${newYetki.getAllRoles().length} roles');

  print('\n=== Cache Example ===');
  print(
    'The permissions and roles are automatically cached with shared_preferences',
  );
  print('When restarting the app, they will be loaded from cache');
  print('To clear the cache: await yetki.clearCache()');

  print('\n=== Singleton Example ===');

  // Create singleton instances
  final singletonYetki1 = Yetki(useSingleton: true);
  final singletonYetki2 = Yetki(useSingleton: true);

  print('Using singleton mode:');
  print(
    'Instances are identical: ${identical(singletonYetki1, singletonYetki2)}',
  );

  // Clear the singleton instance for testing
  Yetki.clearInstance();

  // Create non-singleton instances
  final normalYetki1 = Yetki(useSingleton: false);
  final normalYetki2 = Yetki(useSingleton: false);

  print('Using normal mode:');
  print('Instances are identical: ${identical(normalYetki1, normalYetki2)}');
}
