import 'package:test/test.dart';
import 'package:yetki/yetki.dart';

Yetki _blogPolicy() => Yetki()
  ..addPermissions([
    const Permission(id: 'posts.read'),
    const Permission(id: 'posts.write'),
    const Permission(id: 'posts.delete'),
    const Permission(id: 'users.manage'),
  ])
  ..addRoles([
    Role(id: 'viewer', permissions: {'posts.read'}),
    Role(id: 'editor', permissions: {'posts.write'}, inherits: {'viewer'}),
    Role(id: 'admin', permissions: {'*'}),
  ]);

void main() {
  group('permissions', () {
    late Yetki yetki;

    setUp(() => yetki = Yetki());

    test('add, get and list', () {
      final permission = const Permission(
        id: 'posts.read',
        name: 'Read posts',
        description: 'Allows reading posts',
      );
      expect(yetki.addPermission(permission), permission);
      expect(yetki.getPermission('posts.read'), permission);
      expect(yetki.permissions, [permission]);
    });

    test('name defaults to id', () {
      expect(const Permission(id: 'x').name, 'x');
    });

    test('duplicate id throws', () {
      yetki.addPermission(const Permission(id: 'a'));
      expect(
        () => yetki.addPermission(const Permission(id: 'a')),
        throwsA(isA<YetkiDuplicateException>()),
      );
    });

    test('invalid ids throw', () {
      for (final id in ['', 'a b', 'a.*', '*', 'a..b', '.a', 'a.']) {
        expect(
          () => yetki.addPermission(Permission(id: id)),
          throwsA(isA<YetkiInvalidPolicyException>()),
          reason: id,
        );
      }
    });

    test('addPermissions is all-or-nothing', () {
      expect(
        () => yetki.addPermissions([
          const Permission(id: 'a'),
          const Permission(id: 'a'),
        ]),
        throwsA(isA<YetkiDuplicateException>()),
      );
      expect(yetki.permissions, isEmpty);
    });

    test('update replaces, and throws for unknown ids', () {
      yetki.addPermission(const Permission(id: 'a'));
      yetki.updatePermission(const Permission(id: 'a', name: 'A'));
      expect(yetki.getPermission('a')!.name, 'A');
      expect(
        () => yetki.updatePermission(const Permission(id: 'b')),
        throwsA(isA<YetkiNotFoundException>()),
      );
    });

    test('lists are unmodifiable', () {
      yetki.addPermission(const Permission(id: 'a'));
      expect(
        () => yetki.permissions.add(const Permission(id: 'b')),
        throwsUnsupportedError,
      );
    });

    test('remove revokes from roles and the current user', () {
      final yetki = _blogPolicy()
        ..setUser(
          YetkiUser(
            id: 'u',
            roles: {'viewer'},
            directPermissions: {'posts.read', 'users.manage'},
          ),
        );

      expect(yetki.removePermission('posts.read'), isTrue);
      expect(yetki.getRole('viewer')!.permissions, isEmpty);
      expect(yetki.currentUser!.directPermissions, {'users.manage'});
      expect(yetki.hasPermission('posts.read'), isFalse);
      // Wildcards are kept.
      expect(yetki.getRole('admin')!.permissions, {'*'});
      expect(yetki.removePermission('posts.read'), isFalse);
    });
  });

  group('roles', () {
    late Yetki yetki;

    setUp(() {
      yetki = Yetki()
        ..addPermissions([
          const Permission(id: 'a'),
          const Permission(id: 'b'),
        ]);
    });

    test('add, get and list', () {
      final role = Role(id: 'r', name: 'R', permissions: {'a'});
      expect(yetki.addRole(role), role);
      expect(yetki.getRole('r'), role);
      expect(yetki.roles, [role]);
    });

    test('duplicate id throws', () {
      yetki.addRole(Role(id: 'r'));
      expect(
        () => yetki.addRole(Role(id: 'r')),
        throwsA(isA<YetkiDuplicateException>()),
      );
    });

    test('unknown permission throws', () {
      expect(
        () => yetki.addRole(Role(id: 'r', permissions: {'typo'})),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(yetki.roles, isEmpty);
    });

    test('valid wildcards are accepted without being registered', () {
      yetki.addRole(Role(id: 'r', permissions: {'*', 'posts.*'}));
      expect(
        () => yetki.addRole(Role(id: 's', permissions: {'posts*'})),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(
        () => yetki.addRole(Role(id: 's', permissions: {'.*'})),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
    });

    test('unknown parent throws', () {
      expect(
        () => yetki.addRole(Role(id: 'r', inherits: {'missing'})),
        throwsA(isA<YetkiNotFoundException>()),
      );
    });

    test('self inheritance throws', () {
      expect(
        () => yetki.addRole(Role(id: 'r', inherits: {'r'})),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
      yetki.addRole(Role(id: 'r'));
      expect(
        () => yetki.updateRole(Role(id: 'r', inherits: {'r'})),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
    });

    test('inheritance cycles throw and leave the policy unchanged', () {
      yetki
        ..addRole(Role(id: 'a'))
        ..addRole(Role(id: 'b', inherits: {'a'}))
        ..addRole(Role(id: 'c', inherits: {'b'}));
      expect(
        () => yetki.updateRole(Role(id: 'a', inherits: {'c'})),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
      expect(yetki.getRole('a')!.inherits, isEmpty);
    });

    test('addRoles accepts any order and is all-or-nothing', () {
      yetki.addRoles([
        Role(id: 'child', inherits: {'parent'}),
        Role(id: 'parent', permissions: {'a'}),
      ]);
      expect(yetki.roles, hasLength(2));

      expect(
        () => yetki.addRoles([
          Role(id: 'x'),
          Role(id: 'y', permissions: {'typo'}),
        ]),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(yetki.getRole('x'), isNull);
    });

    test('update throws for unknown roles', () {
      expect(
        () => yetki.updateRole(Role(id: 'r')),
        throwsA(isA<YetkiNotFoundException>()),
      );
    });

    test('grant and revoke permissions', () {
      yetki.addRole(Role(id: 'r'));
      expect(yetki.grantPermissionToRole('r', 'a').permissions, {'a'});
      expect(yetki.revokePermissionFromRole('r', 'a').permissions, isEmpty);
      expect(
        () => yetki.grantPermissionToRole('r', 'typo'),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(
        () => yetki.grantPermissionToRole('missing', 'a'),
        throwsA(isA<YetkiNotFoundException>()),
      );
    });

    test('remove unassigns from users and parents', () {
      final yetki = _blogPolicy()
        ..setUser(YetkiUser(id: 'u', roles: {'viewer', 'editor'}));

      expect(yetki.removeRole('viewer'), isTrue);
      expect(yetki.currentUser!.roles, {'editor'});
      expect(yetki.getRole('editor')!.inherits, isEmpty);
      expect(yetki.hasRole('viewer'), isFalse);
      expect(yetki.hasPermission('posts.read'), isFalse);

      // Re-adding a role with the same id must not silently restore access.
      yetki.addRole(Role(id: 'viewer', permissions: {'posts.read'}));
      expect(yetki.hasRole('viewer'), isFalse);
      expect(yetki.removeRole('missing'), isFalse);
    });
  });

  group('current user', () {
    late Yetki yetki;

    setUp(() => yetki = _blogPolicy());

    test('set, get and clear', () {
      final user = YetkiUser(id: 'u', name: 'Jane', roles: {'viewer'});
      yetki.setUser(user);
      expect(yetki.currentUser, user);
      yetki.clearUser();
      expect(yetki.currentUser, isNull);
    });

    test('unknown roles and permissions are rejected', () {
      expect(
        () => yetki.setUser(YetkiUser(id: 'u', roles: {'typo'})),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(
        () => yetki.setUser(YetkiUser(id: 'u', directPermissions: {'typo'})),
        throwsA(isA<YetkiNotFoundException>()),
      );
      expect(yetki.currentUser, isNull);
    });

    test('assign and revoke roles', () {
      yetki.setUser(YetkiUser(id: 'u'));
      expect(yetki.assignRole('viewer'), isTrue);
      expect(yetki.assignRole('viewer'), isFalse);
      expect(yetki.hasPermission('posts.read'), isTrue);
      expect(yetki.revokeRole('viewer'), isTrue);
      expect(yetki.revokeRole('viewer'), isFalse);
      expect(yetki.hasPermission('posts.read'), isFalse);
      expect(
        () => yetki.assignRole('typo'),
        throwsA(isA<YetkiNotFoundException>()),
      );
    });

    test('grant and revoke direct permissions', () {
      yetki.setUser(YetkiUser(id: 'u'));
      expect(yetki.grantDirectPermission('users.manage'), isTrue);
      expect(yetki.grantDirectPermission('users.manage'), isFalse);
      expect(yetki.hasPermission('users.manage'), isTrue);
      expect(yetki.revokeDirectPermission('users.manage'), isTrue);
      expect(yetki.hasPermission('users.manage'), isFalse);
    });

    test('user mutations without a user throw', () {
      expect(() => yetki.assignRole('viewer'), throwsStateError);
    });

    test('models cannot be mutated behind the instance', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'admin'}));
      expect(() => yetki.currentUser!.roles.add('x'), throwsUnsupportedError);
      expect(
        () => yetki.getRole('viewer')!.permissions.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('checks', () {
    late Yetki yetki;

    setUp(() => yetki = _blogPolicy());

    test('no user has nothing', () {
      expect(yetki.hasPermission('posts.read'), isFalse);
      expect(yetki.hasAnyPermission(['posts.read']), isFalse);
      expect(yetki.hasAllPermissions([]), isFalse);
      expect(yetki.hasRole('viewer'), isFalse);
      expect(yetki.hasAnyRole(['viewer']), isFalse);
      expect(yetki.hasAllRoles([]), isFalse);
      expect(yetki.grantedPermissions(), isEmpty);
    });

    test('role permissions', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      expect(yetki.hasPermission('posts.read'), isTrue);
      expect(yetki.hasPermission('posts.write'), isFalse);
    });

    test('direct permissions', () {
      yetki.setUser(YetkiUser(id: 'u', directPermissions: {'users.manage'}));
      expect(yetki.hasPermission('users.manage'), isTrue);
      expect(yetki.hasPermission('posts.read'), isFalse);
    });

    test('inherited permissions and roles', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'editor'}));
      expect(yetki.hasPermission('posts.write'), isTrue);
      expect(yetki.hasPermission('posts.read'), isTrue);
      expect(yetki.hasPermission('posts.delete'), isFalse);
      expect(yetki.hasRole('editor'), isTrue);
      expect(yetki.hasRole('viewer'), isTrue);
      expect(yetki.hasRole('admin'), isFalse);
      expect(yetki.currentUser!.hasRole('viewer'), isFalse);
    });

    test('multi-level inheritance', () {
      yetki.addRole(Role(id: 'chief', inherits: {'editor'}));
      yetki.setUser(YetkiUser(id: 'u', roles: {'chief'}));
      expect(yetki.hasPermission('posts.read'), isTrue);
      expect(yetki.hasAllRoles(['chief', 'editor', 'viewer']), isTrue);
    });

    test('global wildcard', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'admin'}));
      expect(yetki.hasPermission('posts.delete'), isTrue);
      expect(yetki.hasPermission('anything.at.all'), isTrue);
      expect(yetki.grantedPermissions(), hasLength(4));
    });

    test('prefix wildcard', () {
      yetki.setUser(YetkiUser(id: 'u', directPermissions: {'posts.*'}));
      expect(yetki.hasPermission('posts.read'), isTrue);
      expect(yetki.hasPermission('posts.comments.delete'), isTrue);
      expect(yetki.hasPermission('posts'), isFalse);
      expect(yetki.hasPermission('postsx.read'), isFalse);
      expect(yetki.hasPermission('users.manage'), isFalse);
      expect(yetki.grantedPermissions(), {
        'posts.read',
        'posts.write',
        'posts.delete',
      });
    });

    test('all / any', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      expect(yetki.hasAllPermissions(['posts.read']), isTrue);
      expect(yetki.hasAllPermissions(['posts.read', 'posts.write']), isFalse);
      expect(yetki.hasAnyPermission(['posts.read', 'posts.write']), isTrue);
      expect(yetki.hasAnyPermission(['posts.write']), isFalse);
      expect(yetki.hasAnyRole(['viewer', 'admin']), isTrue);
      expect(yetki.hasAllRoles(['viewer', 'admin']), isFalse);
    });

    test('checks for a user other than the current one', () {
      yetki.setUser(YetkiUser(id: 'me', roles: {'viewer'}));
      final other = YetkiUser(id: 'other', roles: {'admin'});
      expect(yetki.hasPermission('users.manage', user: other), isTrue);
      expect(yetki.hasRole('admin', user: other), isTrue);
      expect(yetki.hasPermission('users.manage'), isFalse);
    });

    test('checks see policy changes immediately', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      expect(yetki.hasPermission('posts.write'), isFalse);
      yetki.grantPermissionToRole('viewer', 'posts.write');
      expect(yetki.hasPermission('posts.write'), isTrue);
    });

    test('requirePermission', () {
      yetki.setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      yetki.requirePermission('posts.read');
      expect(
        () => yetki.requirePermission('posts.write'),
        throwsA(
          isA<YetkiAccessDeniedException>().having(
            (e) => e.permission,
            'permission',
            'posts.write',
          ),
        ),
      );
    });
  });

  group('changes', () {
    test('coalesces synchronous changes into one event', () async {
      final yetki = Yetki();
      final events = <void>[];
      yetki.changes.listen(events.add);

      yetki
        ..addPermission(const Permission(id: 'a'))
        ..addRole(Role(id: 'r', permissions: {'a'}))
        ..setUser(YetkiUser(id: 'u', roles: {'r'}));
      await pumpEventQueue();
      expect(events, hasLength(1));

      yetki.clearUser();
      await pumpEventQueue();
      expect(events, hasLength(2));
    });

    test('no-op changes do not emit', () async {
      final yetki = Yetki()..setUser(YetkiUser(id: 'u'));
      await pumpEventQueue();
      final events = <void>[];
      yetki.changes.listen(events.add);

      yetki.setUser(YetkiUser(id: 'u'));
      yetki.removeRole('missing');
      await pumpEventQueue();
      expect(events, isEmpty);
    });

    test('dispose closes the stream and blocks changes', () async {
      final yetki = Yetki()..addPermission(const Permission(id: 'a'));
      final done = expectLater(yetki.changes, emitsDone);
      await yetki.dispose();
      await done;
      expect(
        () => yetki.addPermission(const Permission(id: 'b')),
        throwsStateError,
      );
      expect(yetki.getPermission('a'), isNotNull);
    });
  });
}
