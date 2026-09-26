import 'package:flutter/material.dart';
import 'package:yetki_flutter/yetki_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the cached policy before the first frame, so that no change can
  // race with loading it.
  final yetki = await Yetki.create(storage: SharedPreferencesYetkiStorage());

  // In a real app the policy usually comes from your backend:
  //   yetki.importFromJson(await api.fetchPolicy());
  if (yetki.roles.isEmpty) {
    yetki
      ..addPermissions(const [
        Permission(id: 'dashboard.view', name: 'View dashboard'),
        Permission(id: 'users.manage', name: 'Manage users'),
      ])
      ..addRoles([
        Role(id: 'member', permissions: {'dashboard.view'}),
        Role(id: 'admin', permissions: {'users.*'}, inherits: {'member'}),
      ]);
  }

  runApp(YetkiScope(yetki: yetki, child: const ExampleApp()));
}

/// Demonstrates guard widgets reacting to user changes.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('yetki example')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              YetkiBuilder(
                builder: (context, yetki) => Text(
                  'Signed in as: ${yetki.currentUser?.name ?? 'nobody'}',
                ),
              ),
              const PermissionGuard(
                permission: 'dashboard.view',
                fallback: Text('Sign in to see the dashboard'),
                child: Text('📊 Dashboard'),
              ),
              const PermissionGuard(
                permission: 'users.manage',
                child: Text('👥 User management'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => context.yetki.setUser(
                      YetkiUser(id: '1', name: 'Member', roles: {'member'}),
                    ),
                    child: const Text('Sign in as member'),
                  ),
                  FilledButton(
                    onPressed: () => context.yetki.setUser(
                      YetkiUser(id: '2', name: 'Admin', roles: {'admin'}),
                    ),
                    child: const Text('Sign in as admin'),
                  ),
                  OutlinedButton(
                    onPressed: context.yetki.clearUser,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
