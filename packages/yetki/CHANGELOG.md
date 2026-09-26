## 0.2.0

A redesign that fixes correctness and security problems in 0.1.x. This
release has breaking changes; see the
[migration guide](README.md#migration-from-01x).

### Fixed

- Loading the cache no longer races with changes made right after
  construction. Previously this could wipe the cached policy or the new
  changes.
- Changes made to a `Role` or `YetkiUser` after registering them are no
  longer lost. Models are now immutable, and every change goes through
  `Yetki`.
- A revoked role no longer comes back after a restart. The current user is
  no longer persisted.
- `removeRole` and `removePermission` now also clean up the current user and
  role inheritance, so re-adding an id no longer restores access silently.
- `hasRole` is now `false` for roles that are not registered.
- `importFromJson` is now atomic and reports errors by throwing.
- Singleton instances no longer silently ignore constructor arguments.
- The library no longer calls `print`.

### Added

- Role inheritance (`Role.inherits`) with cycle detection.
- Wildcard grants: `posts.*` and `*`.
- Validation of ids and references, with a sealed `YetkiException`
  hierarchy.
- `Yetki.changes` stream and `dispose()`.
- `Yetki.create(storage:, onError:)` and the `YetkiStorage` interface, with
  `InMemoryYetkiStorage`. Writes are serialized and coalesced; `flush()` and
  `reset()` were added.
- `addPermissions`, `addRoles`, `updatePermission`,
  `grantPermissionToRole`, `revokePermissionFromRole`, and current-user
  helpers `assignRole`, `revokeRole`, `grantDirectPermission` and
  `revokeDirectPermission`.
- `requirePermission`, `grantedPermissions`, and an optional `user:`
  argument on every check.
- `copyWith` and `with…`/`without…` helpers, and value equality on all
  models.
- Versioned export format. The 0.1.x format can still be imported.

### Changed

- The package is now pure Dart. Flutter integration and shared_preferences
  storage moved to the new `yetki_flutter` package.
- The minimum Dart SDK is now 3.8.
- `getCurrentUser`, `getAllRoles` and `getAllPermissions` are deprecated in
  favor of the `currentUser`, `roles` and `permissions` getters.

### Removed

- `useSingleton`, `useCache`, `clearInstance()` and `clearCache()`.
- The mutating methods on `Role` and `YetkiUser`.

## 0.1.0

- Initial public release: permissions, roles, users, singleton support and
  shared_preferences caching.

## 0.0.2

- Updated pubspec.yaml.
