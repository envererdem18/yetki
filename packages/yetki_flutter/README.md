# yetki_flutter

[![pub package](https://img.shields.io/pub/v/yetki_flutter.svg)](https://pub.dev/packages/yetki_flutter)
[![CI](https://github.com/envererdem18/yetki/actions/workflows/ci.yml/badge.svg)](https://github.com/envererdem18/yetki/actions/workflows/ci.yml)

Flutter bindings for [`yetki`](https://pub.dev/packages/yetki), a role-based
access control (RBAC) library. The widgets rebuild automatically when the
policy or the current user changes.

This package re-exports `package:yetki`, so one import is enough. See the
[yetki README](https://pub.dev/packages/yetki) for roles, permissions,
wildcards and inheritance.

## Installation

```bash
flutter pub add yetki_flutter
```

## Setup

```dart
import 'package:flutter/material.dart';
import 'package:yetki_flutter/yetki_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: cache the policy between launches.
  final yetki = await Yetki.create(storage: SharedPreferencesYetkiStorage());
  yetki.importFromJson(await api.fetchPolicyJson());

  runApp(YetkiScope(yetki: yetki, child: const MyApp()));
}
```

After sign-in, set the user. Anything that depends on it rebuilds:

```dart
context.yetki.setUser(YetkiUser(id: user.id, roles: user.roles));
```

## Widgets

```dart
// A single permission, with an optional fallback.
PermissionGuard(
  permission: 'posts.delete',
  fallback: const Text('Read only'),
  child: DeleteButton(),
)

// Any or all of several permissions.
PermissionGuard.any(permissions: ['posts.edit', 'posts.delete'], child: ...)
PermissionGuard.all(permissions: ['users.read', 'users.edit'], child: ...)

// Roles, including inherited ones.
RoleGuard(role: 'admin', child: AdminPanel())
RoleGuard.any(roles: ['editor', 'admin'], child: ...)

// Any custom check.
YetkiGuard(check: (yetki) => yetki.currentUser != null, child: ...)

// Full access to the instance.
YetkiBuilder(
  builder: (context, yetki) => Text('${yetki.grantedPermissions().length} permissions'),
)
```

In any `build` method:

```dart
if (context.can('posts.edit')) ...   // rebuilds on change
final yetki = context.yetki;         // same as YetkiScope.of(context)
```

## Routing

`YetkiListenable` turns changes into a `Listenable`. With go_router, for
example, it re-runs redirects when permissions change:

```dart
final router = GoRouter(
  refreshListenable: YetkiListenable(yetki),
  redirect: (context, state) {
    if (state.matchedLocation.startsWith('/admin') &&
        !yetki.hasPermission('admin.access')) {
      return '/';
    }
    return null;
  },
  routes: [...],
);
```

## Storage

`SharedPreferencesYetkiStorage` stores the policy under the key
`yetki_cache`, the key yetki 0.1.x used, so existing caches keep working.
The current user is never stored.

shared_preferences is **not encrypted**. It is fine for caching a policy
that your server also enforces. To keep the policy somewhere else, such as
flutter_secure_storage, implement `YetkiStorage`:

```dart
class SecureYetkiStorage implements YetkiStorage {
  const SecureYetkiStorage(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: 'yetki');
  @override
  Future<void> write(String data) => _storage.write(key: 'yetki', value: data);
  @override
  Future<void> delete() => _storage.delete(key: 'yetki');
}
```

> Client-side checks only decide what to show. Always enforce authorization
> on your server.

## Migrating from yetki 0.1.x

Replace the `yetki` dependency with `yetki_flutter` and change your imports
to `package:yetki_flutter/yetki_flutter.dart`. The remaining changes are
listed in
[yetki's migration guide](https://pub.dev/packages/yetki#migration-from-01x).
Wrap your app in a `YetkiScope` instead of using a singleton, and replace
`if (yetki.hasPermission(...))` checks in `build` methods with
`PermissionGuard` or `context.can(...)` so they update when permissions
change.

## License

MIT
