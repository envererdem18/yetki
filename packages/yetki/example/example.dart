// ignore_for_file: avoid_print

import 'package:yetki/yetki.dart';

Future<void> main() async {
  // An in-memory instance. Use `await Yetki.create(storage: ...)` to persist
  // the policy between runs.
  final yetki = Yetki();

  // 1. Register permissions. Dot-separated ids enable wildcard grants.
  yetki.addPermissions(const [
    Permission(id: 'posts.read', name: 'Read posts'),
    Permission(id: 'posts.write', name: 'Write posts'),
    Permission(id: 'posts.delete', name: 'Delete posts'),
    Permission(id: 'users.manage', name: 'Manage users'),
  ]);

  // 2. Register roles. `editor` inherits everything `viewer` can do, and
  //    `moderator` gets every `posts.*` permission through a wildcard.
  yetki.addRoles([
    Role(id: 'viewer', permissions: {'posts.read'}),
    Role(id: 'editor', permissions: {'posts.write'}, inherits: {'viewer'}),
    Role(id: 'moderator', permissions: {'posts.*'}),
    Role(id: 'admin', permissions: {'*'}),
  ]);

  // 3. Set the signed-in user, typically built from your auth backend.
  yetki.setUser(YetkiUser(id: 'u1', name: 'Jane', roles: {'editor'}));

  print('=== editor ===');
  print('posts.read:   ${yetki.hasPermission('posts.read')}'); // true
  print('posts.write:  ${yetki.hasPermission('posts.write')}'); // true
  print('posts.delete: ${yetki.hasPermission('posts.delete')}'); // false
  print('is viewer:    ${yetki.hasRole('viewer')}'); // true, inherited
  print('granted:      ${yetki.grantedPermissions()}');

  // 4. React to changes, e.g. to rebuild UI or refresh routes.
  final subscription = yetki.changes.listen((_) {
    print('-- policy or user changed --');
  });

  // 5. Change the current user or the policy through Yetki, which validates
  //    every change and notifies listeners.
  yetki.grantDirectPermission('users.manage');
  yetki.grantPermissionToRole('editor', 'posts.delete');
  await Future<void>.delayed(Duration.zero);

  print('=== after changes ===');
  print('users.manage: ${yetki.hasPermission('users.manage')}'); // true
  print('posts.delete: ${yetki.hasPermission('posts.delete')}'); // true

  // 6. Check any user, not just the current one.
  final moderator = YetkiUser(id: 'u2', roles: {'moderator'});
  print('=== moderator ===');
  print(
    'posts.delete: ${yetki.hasPermission('posts.delete', user: moderator)}',
  );

  // 7. Guard an operation.
  try {
    yetki.requirePermission('billing.refund');
  } on YetkiAccessDeniedException catch (e) {
    print('denied: ${e.message}');
  }

  // 8. Invalid changes throw and leave the policy untouched.
  try {
    yetki.addRole(Role(id: 'broken', permissions: {'posts.raed'}));
  } on YetkiNotFoundException catch (e) {
    print('rejected: ${e.message}');
  }

  // 9. Export the policy (never the user) and load it elsewhere.
  final json = yetki.exportToJson();
  final copy = Yetki()..importFromJson(json);
  print('copied roles: ${copy.roles.map((r) => r.id).toList()}');

  await subscription.cancel();
  await yetki.dispose();
}
