import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yetki_flutter/yetki_flutter.dart';

Yetki _policy() => Yetki()
  ..addPermissions(const [
    Permission(id: 'posts.read'),
    Permission(id: 'posts.delete'),
  ])
  ..addRoles([
    Role(id: 'viewer', permissions: {'posts.read'}),
    Role(id: 'admin', permissions: {'*'}, inherits: {'viewer'}),
  ]);

Widget _app(Yetki yetki, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: YetkiScope(yetki: yetki, child: child),
);

/// Lets a change event reach the scope, then renders the rebuilt frame.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('YetkiScope', () {
    testWidgets('of and context helpers', (tester) async {
      final yetki = _policy()..setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      late Yetki found;
      late bool canRead;
      late bool canDelete;
      await tester.pumpWidget(
        _app(
          yetki,
          Builder(
            builder: (context) {
              found = context.yetki;
              canRead = context.can('posts.read');
              canDelete = context.can('posts.delete');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, same(yetki));
      expect(canRead, isTrue);
      expect(canDelete, isFalse);
    });

    testWidgets('of throws without a scope, maybeOf returns null', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(YetkiScope.maybeOf(captured), isNull);
      expect(() => YetkiScope.of(captured), throwsFlutterError);
    });

    testWidgets('switching instances resubscribes', (tester) async {
      final first = _policy();
      final second = _policy();
      await tester.pumpWidget(
        _app(
          first,
          const PermissionGuard(permission: 'posts.read', child: Text('read')),
        ),
      );
      await tester.pumpWidget(
        _app(
          second,
          const PermissionGuard(permission: 'posts.read', child: Text('read')),
        ),
      );
      expect(find.text('read'), findsNothing);

      second.setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      await _settle(tester);
      expect(find.text('read'), findsOneWidget);
    });
  });

  group('guards', () {
    testWidgets('PermissionGuard rebuilds on changes', (tester) async {
      final yetki = _policy();
      await tester.pumpWidget(
        _app(
          yetki,
          const PermissionGuard(
            permission: 'posts.delete',
            fallback: Text('denied'),
            child: Text('delete'),
          ),
        ),
      );
      expect(find.text('denied'), findsOneWidget);

      yetki.setUser(YetkiUser(id: 'u', roles: {'admin'}));
      await _settle(tester);
      expect(find.text('delete'), findsOneWidget);

      yetki.clearUser();
      await _settle(tester);
      expect(find.text('denied'), findsOneWidget);
    });

    testWidgets('PermissionGuard.any and .all', (tester) async {
      final yetki = _policy()..setUser(YetkiUser(id: 'u', roles: {'viewer'}));
      await tester.pumpWidget(
        _app(
          yetki,
          const Column(
            children: [
              PermissionGuard.any(
                permissions: ['posts.read', 'posts.delete'],
                child: Text('any'),
              ),
              PermissionGuard.all(
                permissions: ['posts.read', 'posts.delete'],
                child: Text('all'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('any'), findsOneWidget);
      expect(find.text('all'), findsNothing);
    });

    testWidgets('RoleGuard follows inheritance', (tester) async {
      final yetki = _policy()..setUser(YetkiUser(id: 'u', roles: {'admin'}));
      await tester.pumpWidget(
        _app(
          yetki,
          const Column(
            children: [
              RoleGuard(role: 'viewer', child: Text('viewer')),
              RoleGuard.all(roles: ['viewer', 'admin'], child: Text('all')),
              RoleGuard.any(roles: ['nobody'], child: Text('any')),
            ],
          ),
        ),
      );
      expect(find.text('viewer'), findsOneWidget);
      expect(find.text('all'), findsOneWidget);
      expect(find.text('any'), findsNothing);
    });

    testWidgets('YetkiGuard and YetkiBuilder', (tester) async {
      final yetki = _policy();
      await tester.pumpWidget(
        _app(
          yetki,
          Column(
            children: [
              YetkiGuard(
                check: (y) => y.currentUser != null,
                child: const Text('signed in'),
              ),
              YetkiBuilder(
                builder: (context, y) =>
                    Text('granted: ${y.grantedPermissions().length}'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('signed in'), findsNothing);
      expect(find.text('granted: 0'), findsOneWidget);

      yetki.setUser(YetkiUser(id: 'u', roles: {'admin'}));
      await _settle(tester);
      expect(find.text('signed in'), findsOneWidget);
      expect(find.text('granted: 2'), findsOneWidget);
    });
  });

  test('YetkiListenable notifies on changes', () async {
    final yetki = _policy();
    final listenable = YetkiListenable(yetki);
    var notifications = 0;
    listenable.addListener(() => notifications++);

    yetki.setUser(YetkiUser(id: 'u'));
    await pumpEventQueue();
    expect(notifications, 1);

    listenable.dispose();
    yetki.clearUser();
    await pumpEventQueue();
    expect(notifications, 1);
  });

  group('SharedPreferencesYetkiStorage', () {
    test('persists the policy across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPreferencesYetkiStorage();
      final yetki = await Yetki.create(storage: storage)
        ..addPermission(const Permission(id: 'a'))
        ..addRole(Role(id: 'r', permissions: {'a'}));
      await yetki.flush();

      final restored = await Yetki.create(
        storage: SharedPreferencesYetkiStorage(),
      );
      expect(restored.getRole('r')!.permissions, {'a'});

      await restored.reset();
      expect(await storage.read(), isNull);
    });

    test('reads the 0.1.x cache without restoring its user', () async {
      SharedPreferences.setMockInitialValues({
        'yetki_cache':
            '{"permissions":{"a":{"id":"a","name":"A","description":null}},'
            '"roles":{},'
            '"currentUser":{"id":"u","name":"U","roleIds":[],'
            '"directPermissionIds":["a"]}}',
      });
      final yetki = await Yetki.create(
        storage: SharedPreferencesYetkiStorage(),
      );
      expect(yetki.getPermission('a'), isNotNull);
      expect(yetki.currentUser, isNull);
    });

    test('custom key', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = SharedPreferencesYetkiStorage(
        key: 'custom',
        preferences: preferences,
      );
      await storage.write('data');
      expect(preferences.getString('custom'), 'data');
    });
  });
}
