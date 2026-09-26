import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:yetki/yetki.dart';

/// A storage whose reads and writes can be delayed and made to fail.
class _FakeStorage implements YetkiStorage {
  _FakeStorage([this.data]);

  String? data;
  final writes = <String>[];
  Completer<void>? writeGate;
  bool failWrites = false;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async {
    await writeGate?.future;
    if (failWrites) throw StateError('disk full');
    writes.add(data);
    this.data = data;
  }

  @override
  Future<void> delete() async => data = null;
}

const _legacyCache =
    '{"permissions":{"old":{"id":"old","name":"Old","description":null}},'
    '"roles":{"r":{"id":"r","name":"R","description":null,'
    '"permissionIds":["old"]}},'
    '"currentUser":{"id":"u","name":"U","roleIds":["r"],'
    '"directPermissionIds":[]}}';

void main() {
  group('export / import', () {
    test('round trip', () {
      final source = Yetki()
        ..addPermission(const Permission(id: 'a', description: 'd'))
        ..addRoles([
          Role(id: 'p', permissions: {'a'}),
          Role(id: 'c', permissions: {'x.*'}, inherits: {'p'}),
        ]);

      final target = Yetki()..importFromJson(source.exportToJson());
      expect(target.permissions, source.permissions);
      expect(target.roles, source.roles);
    });

    test('export is versioned and never contains the user', () {
      final yetki = Yetki()..setUser(YetkiUser(id: 'u'));
      final json = jsonDecode(yetki.exportToJson()) as Map<String, Object?>;
      expect(json['version'], 1);
      expect(json.containsKey('currentUser'), isFalse);
    });

    test('invalid input throws and changes nothing', () {
      final yetki = Yetki()
        ..addPermission(const Permission(id: 'keep'))
        ..addRole(Role(id: 'keep'));

      final invalid = [
        '{"invalid": "json"',
        '[]',
        '{"version": 2}',
        '{"permissions": [{"id": "a"}], "roles": [{"id": "r", "name": 5}]}',
        '{"permissions": [{"id": "a"}], "roles": '
            '[{"id": "r", "permissions": ["missing"]}]}',
        '{"roles": [{"id": "a", "inherits": ["b"]}, '
            '{"id": "b", "inherits": ["a"]}]}',
        '{"permissions": [{"id": "a"}, {"id": "a"}]}',
      ];
      for (final json in invalid) {
        expect(
          () => yetki.importFromJson(json),
          throwsA(isA<YetkiException>()),
          reason: json,
        );
        expect(yetki.getPermission('keep'), isNotNull, reason: json);
        expect(yetki.getRole('keep'), isNotNull, reason: json);
      }
    });

    test('import prunes what the current user can no longer hold', () {
      final yetki = Yetki()
        ..addPermission(const Permission(id: 'a'))
        ..addRole(Role(id: 'r', permissions: {'a'}))
        ..setUser(YetkiUser(id: 'u', roles: {'r'}, directPermissions: {'a'}));

      yetki.importFromJson('{"version": 1, "permissions": [], "roles": []}');
      expect(yetki.currentUser!.roles, isEmpty);
      expect(yetki.currentUser!.directPermissions, isEmpty);
      expect(yetki.hasPermission('a'), isFalse);
    });

    test('imports 0.1.x cache data and ignores its user', () {
      final yetki = Yetki()..importFromJson(_legacyCache);
      expect(yetki.getRole('r')!.permissions, {'old'});
      expect(yetki.currentUser, isNull);
    });
  });

  group('storage', () {
    test(
      'create restores before returning, so changes cannot race it',
      () async {
        // Regression: in 0.1.x, adding a permission right after construction
        // wiped the cached policy.
        final storage = _FakeStorage(_legacyCache);
        final yetki = await Yetki.create(storage: storage);
        yetki.addPermission(const Permission(id: 'new'));
        await yetki.flush();

        expect(yetki.permissions.map((p) => p.id), ['old', 'new']);
        final restored = await Yetki.create(storage: storage);
        expect(restored.permissions.map((p) => p.id), ['old', 'new']);
      },
    );

    test('model changes made through Yetki are persisted', () async {
      // Regression: in 0.1.x, mutating a role after addRole was never saved.
      final storage = _FakeStorage();
      final yetki = await Yetki.create(storage: storage)
        ..addPermission(const Permission(id: 'a'))
        ..addRole(Role(id: 'r'));
      yetki.grantPermissionToRole('r', 'a');
      await yetki.flush();

      final restored = await Yetki.create(storage: storage);
      expect(restored.getRole('r')!.permissions, {'a'});
    });

    test('the current user is never persisted', () async {
      // Regression: in 0.1.x, a revoked role came back after a restart.
      final storage = _FakeStorage();
      final yetki = await Yetki.create(storage: storage)
        ..addRole(Role(id: 'admin'))
        ..setUser(YetkiUser(id: 'u', roles: {'admin'}));
      await yetki.flush();

      expect(storage.data, isNot(contains('"u"')));
      final restored = await Yetki.create(storage: storage);
      expect(restored.currentUser, isNull);
      expect(restored.hasRole('admin'), isFalse);
    });

    test('synchronous changes are coalesced into one write', () async {
      final storage = _FakeStorage();
      final yetki = await Yetki.create(storage: storage);
      for (var i = 0; i < 20; i++) {
        yetki.addPermission(Permission(id: 'p$i'));
      }
      await yetki.flush();
      expect(storage.writes, hasLength(1));
      expect(storage.writes.single, contains('p19'));
    });

    test('writes are serialized and the last state wins', () async {
      final storage = _FakeStorage()..writeGate = Completer<void>();
      final yetki = await Yetki.create(storage: storage)
        ..addPermission(const Permission(id: 'first'));
      await pumpEventQueue();
      yetki.addPermission(const Permission(id: 'second'));
      storage.writeGate!.complete();
      await yetki.flush();

      expect(storage.writes, hasLength(2));
      expect(storage.data, contains('second'));
    });

    test('user changes do not write', () async {
      final storage = _FakeStorage();
      final yetki = await Yetki.create(storage: storage)
        ..setUser(YetkiUser(id: 'u'));
      await yetki.flush();
      expect(storage.writes, isEmpty);
    });

    test('write errors go to onError and later writes still run', () async {
      final errors = <Object>[];
      final storage = _FakeStorage()..failWrites = true;
      final yetki =
          await Yetki.create(
              storage: storage,
              onError: (error, _) => errors.add(error),
            )
            ..addPermission(const Permission(id: 'a'));
      await yetki.flush();
      expect(errors, [isA<StateError>()]);

      storage.failWrites = false;
      yetki.addPermission(const Permission(id: 'b'));
      await yetki.flush();
      expect(storage.data, contains('"b"'));
    });

    test('corrupt stored data is reported and ignored', () async {
      final errors = <Object>[];
      final yetki = await Yetki.create(
        storage: _FakeStorage('not json'),
        onError: (error, _) => errors.add(error),
      );
      expect(errors, [isA<YetkiInvalidPolicyException>()]);
      expect(yetki.permissions, isEmpty);
    });

    test('reset clears memory and storage', () async {
      final storage = _FakeStorage();
      final yetki = await Yetki.create(storage: storage)
        ..addRole(Role(id: 'r'))
        ..setUser(YetkiUser(id: 'u', roles: {'r'}));
      await yetki.reset();

      expect(storage.data, isNull);
      expect(yetki.roles, isEmpty);
      expect(yetki.currentUser, isNull);
    });

    test('InMemoryYetkiStorage', () async {
      final storage = InMemoryYetkiStorage();
      final yetki = await Yetki.create(storage: storage)
        ..addPermission(const Permission(id: 'a'));
      await yetki.flush();
      expect(storage.data, contains('"a"'));
      await storage.delete();
      expect(await storage.read(), isNull);
    });
  });
}
