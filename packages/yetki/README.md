# yetki

[![pub package](https://img.shields.io/pub/v/yetki.svg)](https://pub.dev/packages/yetki)
[![CI](https://github.com/envererdem18/yetki/actions/workflows/ci.yml/badge.svg)](https://github.com/envererdem18/yetki/actions/workflows/ci.yml)

Role-based access control (RBAC) for Dart: users get roles, roles grant
permissions, and your code asks one question — *may this user do that?*

This package is pure Dart, so it also runs on the server and in CLI tools.
For Flutter widgets (`PermissionGuard`, `YetkiScope`, …) and
shared_preferences storage, use [`yetki_flutter`](https://pub.dev/packages/yetki_flutter),
which re-exports everything here.

## Features

- **Role inheritance**: an `editor` can inherit everything a `viewer` can do.
- **Wildcard grants**: `posts.*` grants every `posts.…` permission, and `*` grants everything.
- **Validated policy**: typos and dangling references throw instead of silently denying access. Batch operations and imports are all-or-nothing.
- **Immutable models** that compare by value.
- **Change notifications** through a `Stream`, so UI and routers can react.
- **Pluggable persistence** with any `YetkiStorage`. Writes are serialized and coalesced.
- **Versioned JSON import and export**, so a policy can come from your backend.

## Installation

```bash
dart pub add yetki          # Dart
flutter pub add yetki_flutter  # Flutter
```

## Quick start

```dart
import 'package:yetki/yetki.dart';

final yetki = Yetki()
  ..addPermissions(const [
    Permission(id: 'posts.read'),
    Permission(id: 'posts.write'),
    Permission(id: 'posts.delete'),
  ])
  ..addRoles([
    Role(id: 'viewer', permissions: {'posts.read'}),
    Role(id: 'editor', permissions: {'posts.write'}, inherits: {'viewer'}),
    Role(id: 'admin', permissions: {'*'}),
  ])
  ..setUser(YetkiUser(id: 'u1', roles: {'editor'}));

yetki.hasPermission('posts.read');   // true, inherited from viewer
yetki.hasPermission('posts.delete'); // false
yetki.hasRole('viewer');             // true, through inheritance
```

## Concepts

| Concept | What it is |
| --- | --- |
| `Permission` | A capability with a dot-separated id such as `posts.edit`. Segments must be non-empty and contain no whitespace or `*`. |
| Grant | What a role or user is given: a permission id, `prefix.*` or `*`. `posts.*` matches `posts.edit` and `posts.comments.delete`, but not `posts` itself. |
| `Role` | A named set of grants, plus the ids of roles it `inherits` from. Cycles are rejected. |
| `YetkiUser` | A user with assigned `roles` and optional `directPermissions`. |
| `Yetki` | The engine. It holds the policy (permissions and roles) and the current user, validates every change and answers checks. |

## Checking access

```dart
yetki.hasPermission('posts.write');
yetki.hasAnyPermission(['posts.write', 'posts.delete']);
yetki.hasAllPermissions(['posts.read', 'posts.write']);
yetki.hasRole('editor');
yetki.hasAnyRole(['editor', 'admin']);
yetki.grantedPermissions(); // {posts.read, posts.write}

// Throws YetkiAccessDeniedException when the permission is missing.
yetki.requirePermission('posts.write');

// Every check can target any user, not only the current one. This is
// useful on a server.
yetki.hasPermission('posts.delete', user: someOtherUser);
```

## Changing the policy and the user

Models are immutable, and all changes go through `Yetki`, which validates and
publishes them:

```dart
yetki.grantPermissionToRole('viewer', 'comments.read');
yetki.updateRole(yetki.getRole('editor')!.copyWith(name: 'Author'));
yetki.removeRole('viewer'); // also removed from users and child roles

yetki.assignRole('admin');  // on the current user
yetki.grantDirectPermission('billing.view');
yetki.clearUser();          // sign out
```

Invalid changes throw a subtype of the sealed `YetkiException` and leave the
policy untouched:

| Exception | When |
| --- | --- |
| `YetkiDuplicateException` | The id is already registered. |
| `YetkiNotFoundException` | A referenced permission or role is not registered. |
| `YetkiInvalidPolicyException` | An id or wildcard is invalid, roles inherit in a cycle, or the JSON is malformed. |
| `YetkiAccessDeniedException` | Thrown by `requirePermission`. |

## Reacting to changes

```dart
final subscription = yetki.changes.listen((_) => rebuildMenus());
```

Changes made in the same synchronous block produce a single event. Call
`await yetki.dispose()` when you no longer need the instance.

## Loading the policy from your backend

```dart
yetki.importFromJson(await api.fetchPolicyJson()); // atomic, throws on error
final json = yetki.exportToJson();                 // {"version": 1, ...}
```

The format contains permissions and roles, never the user. Roles and grants
that the current user holds but the new policy lacks are removed from the
user.

## Persistence

```dart
final yetki = await Yetki.create(
  storage: MyStorage(),                 // implements YetkiStorage
  onError: (error, stack) => log(error),
);
```

`Yetki.create` finishes restoring before it returns, so no change can race
with the load. After that, every policy change is written back. Writes run
one at a time, and changes made in the same synchronous block are saved in a
single write. `await yetki.flush()` waits for pending writes, and
`await yetki.reset()` clears memory and storage.

`InMemoryYetkiStorage` is included for tests. `yetki_flutter` provides
`SharedPreferencesYetkiStorage`.

## Security

Checks that run on a user's device only decide **what to show**. A user who
controls the device can change the app or its storage. **Always enforce
authorization on your server.** To match that model, yetki:

- never persists the current user. Who the user is and which roles they hold
  must come from your authentication backend on every start;
- persists only when you opt in with `Yetki.create(storage: ...)`.

---

## Migration from 0.1.x

0.2.0 is a redesign that fixes several correctness and security problems in
0.1.x. Every breaking change is listed below.

### Flutter users: depend on `yetki_flutter`

`yetki` no longer depends on Flutter or shared_preferences. Flutter apps
should depend on `yetki_flutter` instead. It re-exports `yetki`, so you only
change imports:

```diff
- import 'package:yetki/yetki.dart';
+ import 'package:yetki_flutter/yetki_flutter.dart';
```

The minimum Dart SDK is now 3.8.

### Singleton and caching are replaced

The `useSingleton` and `useCache` parameters and `Yetki.clearInstance()`
are gone. `Yetki()` now creates a purely in-memory instance.

- **Singleton**: create one instance and pass it around, for example through
  `YetkiScope` in Flutter or your DI container.
- **Caching** is now opt-in, and it is awaited so it cannot race with your
  changes. The default shared_preferences key is still `yetki_cache`, so an
  existing 0.1.x cache is picked up:

```diff
- final yetki = Yetki(useSingleton: true); // cached by default
+ final yetki = await Yetki.create(storage: SharedPreferencesYetkiStorage());
```

- `clearCache()` is replaced by `reset()`, which clears memory too.
- **The current user is no longer persisted.** In 0.1.x a revoked role could
  come back after a restart. Call `setUser` on every start with data from
  your backend.

### Models are immutable; change them through `Yetki`

In 0.1.x, changing a `Role` or `YetkiUser` after registering it bypassed
validation and was never saved. Those mutating methods are removed:

| 0.1.x | 0.2.0 |
| --- | --- |
| `role.addPermission(id)` | `yetki.grantPermissionToRole(role.id, id)`, or `role.withPermission(id)` before `addRole` |
| `role.removePermission(id)` | `yetki.revokePermissionFromRole(role.id, id)` |
| `role.hasPermission(id)` | `role.permissions.contains(id)` |
| `role.clearPermissions()` | `yetki.updateRole(role.copyWith(permissions: {}))` |
| `user.assignRole(id)` | `yetki.assignRole(id)` for the current user, or `user.withRole(id)` |
| `user.revokeRole(id)` | `yetki.revokeRole(id)` or `user.withoutRole(id)` |
| `user.grantDirectPermission(id)` | `yetki.grantDirectPermission(id)` or `user.withDirectPermission(id)` |
| `user.revokeDirectPermission(id)` | `yetki.revokeDirectPermission(id)` or `user.withoutDirectPermission(id)` |
| `user.clearRoles()` / `clearDirectPermissions()` | `user.copyWith(roles: {})` / `copyWith(directPermissions: {})` |

The usual 0.1.x pattern becomes:

```diff
- final editor = Role(id: 'editor', name: 'Editor');
- editor.addPermission('edit_users');
- yetki.addRole(editor);
- final user = YetkiUser(id: '1', name: 'Jane');
- user.assignRole('editor');
- yetki.setUser(user);
+ yetki.addRole(Role(id: 'editor', name: 'Editor', permissions: {'edit_users'}));
+ yetki.setUser(YetkiUser(id: '1', name: 'Jane', roles: {'editor'}));
```

### Renamed fields

| 0.1.x | 0.2.0 |
| --- | --- |
| `Role(permissionIds: ...)`, `role.permissionIds` (`List`) | `Role(permissions: ...)`, `role.permissions` (`Set`) |
| `YetkiUser(roleIds: ...)` | `YetkiUser(roles: ...)` |
| `YetkiUser(directPermissionIds: ...)` | `YetkiUser(directPermissions: ...)` |
| `user.roles`, `user.directPermissions` (`List`) | same names, now unmodifiable `Set`s |
| `yetki.getCurrentUser()` | `yetki.currentUser` (old name deprecated) |
| `yetki.getAllRoles()` | `yetki.roles` (old name deprecated) |
| `yetki.getAllPermissions()` | `yetki.permissions` (old name deprecated) |

`Permission.name`, `Role.name` and `YetkiUser.name` are now optional. The
first two default to the id.

### Stricter validation

- **Ids** must be non-empty, dot-separated segments without whitespace or
  `*`. `view_users` and `users.view` are valid; `view users` is not.
- **References must exist.** `addRole` throws `YetkiNotFoundException` when a
  role grants an unregistered permission or inherits an unregistered role.
  `setUser`, `assignRole` and `grantDirectPermission` throw when the role or
  permission is unregistered. Register permissions before roles, and parent
  roles before children, or use `addPermissions` and `addRoles`, which accept
  any order.
- `updateRole` rejects inheritance cycles.

### Behavior changes

- `removeRole` also unassigns the role from the current user and removes it
  from other roles' `inherits`. `removePermission` also revokes the
  permission from the current user. In 0.1.x, re-adding a removed id silently
  restored access.
- `hasRole` includes inherited roles and is `false` for unregistered roles.
  `YetkiUser.hasRole` still only checks direct assignment.
- `==` compares all fields, not just the id.
- `hasAll*` and `hasAny*` accept any `Iterable<String>`. This is not breaking.

### Import and export

- `importFromJson` throws a `YetkiException` instead of returning `false`,
  and it is atomic: on error, nothing changes.
- `exportToJson` writes a versioned format (`{"version": 1, "permissions":
  [...], "roles": [...]}`). `importFromJson` still reads the 0.1.x format
  and ignores its `currentUser`.
- The models' `fromJson` constructors take `Map<String, Object?>` and throw
  `YetkiInvalidPolicyException` on malformed input. They also accept 0.1.x
  field names.

### Exceptions

`YetkiException` is now a sealed base class and cannot be constructed
directly. `on YetkiException` still catches everything. Catch
`YetkiDuplicateException`, `YetkiNotFoundException`,
`YetkiInvalidPolicyException` or `YetkiAccessDeniedException` for specific
cases.

### Logging

yetki no longer calls `print`. Storage errors go to the `onError` callback
of `Yetki.create`, or to `dart:developer`'s `log` by default.

## License

MIT
