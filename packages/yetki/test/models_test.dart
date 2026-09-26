import 'package:test/test.dart';
import 'package:yetki/yetki.dart';

void main() {
  group('Permission', () {
    test('value equality', () {
      expect(const Permission(id: 'a'), const Permission(id: 'a'));
      expect(
        const Permission(id: 'a'),
        isNot(const Permission(id: 'a', name: 'other')),
      );
    });

    test('JSON round trip', () {
      const permission = Permission(id: 'a', name: 'A', description: 'd');
      expect(Permission.fromJson(permission.toJson()), permission);
    });

    test('malformed JSON throws a YetkiException', () {
      expect(
        () => Permission.fromJson({'name': 'x'}),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
    });
  });

  group('Role', () {
    test('value equality ignores set order', () {
      expect(
        Role(id: 'r', permissions: {'a', 'b'}),
        Role(id: 'r', permissions: {'b', 'a'}),
      );
      expect(
        Role(id: 'r', permissions: {'a'}),
        isNot(Role(id: 'r', permissions: {'b'})),
      );
      expect(
        Role(id: 'r', permissions: {'a', 'b'}).hashCode,
        Role(id: 'r', permissions: {'b', 'a'}).hashCode,
      );
    });

    test('is immutable', () {
      final source = {'a'};
      final role = Role(id: 'r', permissions: source);
      source.add('b');
      expect(role.permissions, {'a'});
      expect(() => role.permissions.add('c'), throwsUnsupportedError);
    });

    test('with/without helpers return new instances', () {
      final role = Role(id: 'r');
      final granted = role.withPermission('a');
      expect(role.permissions, isEmpty);
      expect(granted.permissions, {'a'});
      expect(granted.withoutPermission('a').permissions, isEmpty);
    });

    test('JSON round trip', () {
      final role = Role(
        id: 'r',
        name: 'R',
        description: 'd',
        permissions: {'a', 'b.*'},
        inherits: {'p'},
      );
      expect(Role.fromJson(role.toJson()), role);
    });

    test('reads 0.1.x JSON', () {
      final role = Role.fromJson({
        'id': 'r',
        'name': 'R',
        'description': null,
        'permissionIds': ['a'],
      });
      expect(role.permissions, {'a'});
    });

    test('malformed JSON throws a YetkiException', () {
      expect(
        () => Role.fromJson({
          'id': 'r',
          'permissions': [1],
        }),
        throwsA(isA<YetkiInvalidPolicyException>()),
      );
    });
  });

  group('YetkiUser', () {
    test('value equality', () {
      expect(
        YetkiUser(id: 'u', roles: {'a', 'b'}),
        YetkiUser(id: 'u', roles: {'b', 'a'}),
      );
      expect(YetkiUser(id: 'u'), isNot(YetkiUser(id: 'u', roles: {'a'})));
    });

    test('helpers', () {
      final user = YetkiUser(id: 'u').withRole('r').withDirectPermission('p');
      expect(user.hasRole('r'), isTrue);
      expect(user.hasDirectPermission('p'), isTrue);
      expect(user.withoutRole('r').roles, isEmpty);
      expect(user.withoutDirectPermission('p').directPermissions, isEmpty);
    });

    test('JSON round trip', () {
      final user = YetkiUser(
        id: 'u',
        name: 'Jane',
        roles: {'r'},
        directPermissions: {'p'},
      );
      expect(YetkiUser.fromJson(user.toJson()), user);
    });

    test('reads 0.1.x JSON', () {
      final user = YetkiUser.fromJson({
        'id': 'u',
        'name': 'Jane',
        'roleIds': ['r'],
        'directPermissionIds': ['p'],
      });
      expect(user.roles, {'r'});
      expect(user.directPermissions, {'p'});
    });
  });

  test('exceptions have readable messages', () {
    expect(
      const YetkiNotFoundException('x').toString(),
      'YetkiNotFoundException: x',
    );
  });
}
