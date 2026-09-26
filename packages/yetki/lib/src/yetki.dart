import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'exceptions.dart';
import 'models/permission.dart';
import 'models/role.dart';
import 'models/user.dart';
import 'policy.dart';
import 'storage.dart';

/// Receives errors that yetki cannot throw to a caller, such as a failed
/// background write to [YetkiStorage].
typedef YetkiErrorHandler = void Function(Object error, StackTrace stackTrace);

/// A role-based access control engine.
///
/// A [Yetki] holds a *policy* — the registered [Permission]s and [Role]s —
/// and the *current user*, and answers questions such as [hasPermission] and
/// [hasRole] about that user (or any other [YetkiUser]).
///
/// Every change goes through this class, which validates it, so the policy
/// can never reference a permission or role that does not exist. Listen to
/// [changes] to react when anything changes.
///
/// Use the default constructor for an in-memory instance, or [Yetki.create]
/// to restore the policy from a [YetkiStorage] and save it back on change.
///
/// Access checks on the client only decide what to *show*. Always enforce
/// authorization on your server as well.
class Yetki {
  /// Creates an in-memory instance with an empty policy and no current user.
  Yetki() : this._(null, null);

  Yetki._(this._storage, YetkiErrorHandler? onError)
    : _onError = onError ?? _logError;

  /// Creates an instance whose policy is restored from [storage] and saved
  /// back to it after every change.
  ///
  /// The returned future completes once the stored policy has been loaded, so
  /// no change can race with the restore. If the stored data cannot be read
  /// or decoded, [onError] is called and the instance starts with an empty
  /// policy. [onError] also receives errors from later background writes; by
  /// default they are logged with `dart:developer`.
  static Future<Yetki> create({
    YetkiStorage? storage,
    YetkiErrorHandler? onError,
  }) async {
    final yetki = Yetki._(storage, onError);
    await yetki._restore();
    return yetki;
  }

  final YetkiStorage? _storage;
  final YetkiErrorHandler _onError;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Policy _policy = Policy();
  YetkiUser? _currentUser;
  Access? _currentAccess;

  Future<void> _queue = Future.value();
  bool _saveScheduled = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Emits an event after one or more changes to the policy or the current
  /// user. Changes made in the same synchronous block produce one event.
  Stream<void> get changes => _changes.stream;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// All registered permissions. Unmodifiable.
  List<Permission> get permissions =>
      List.unmodifiable(_policy.permissions.values);

  /// Returns the permission with [id], or `null` if it is not registered.
  Permission? getPermission(String id) => _policy.permissions[id];

  /// Registers [permission] and returns it.
  ///
  /// Throws [YetkiInvalidPolicyException] if its id is invalid, and
  /// [YetkiDuplicateException] if the id is already registered.
  Permission addPermission(Permission permission) {
    _checkNotDisposed();
    validateId(permission.id, 'permission');
    if (_policy.permissions.containsKey(permission.id)) {
      throw YetkiDuplicateException(
        'Permission "${permission.id}" is already registered',
      );
    }
    _policy.permissions[permission.id] = permission;
    _changed();
    return permission;
  }

  /// Registers every permission in [permissions]. Either all of them are
  /// added or, if one is invalid, none are.
  void addPermissions(Iterable<Permission> permissions) {
    _checkNotDisposed();
    final candidate = _policy.copy();
    for (final permission in permissions) {
      validateId(permission.id, 'permission');
      if (candidate.permissions.containsKey(permission.id)) {
        throw YetkiDuplicateException(
          'Permission "${permission.id}" is already registered',
        );
      }
      candidate.permissions[permission.id] = permission;
    }
    _policy = candidate;
    _changed();
  }

  /// Replaces the registered permission that has the same id as [permission].
  ///
  /// Throws [YetkiNotFoundException] if no such permission is registered.
  Permission updatePermission(Permission permission) {
    _checkNotDisposed();
    if (!_policy.permissions.containsKey(permission.id)) {
      throw YetkiNotFoundException(
        'Permission "${permission.id}" is not registered',
      );
    }
    _policy.permissions[permission.id] = permission;
    _changed();
    return permission;
  }

  /// Unregisters the permission with [id] and revokes it from every role and
  /// from the current user.
  ///
  /// Wildcard grants such as `posts.*` are kept. Returns `false` if no such
  /// permission was registered.
  bool removePermission(String id) {
    _checkNotDisposed();
    if (_policy.permissions.remove(id) == null) return false;
    for (final role in [..._policy.roles.values]) {
      if (role.permissions.contains(id)) {
        _policy.roles[role.id] = role.withoutPermission(id);
      }
    }
    _pruneCurrentUser();
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Roles
  // ---------------------------------------------------------------------------

  /// All registered roles. Unmodifiable.
  List<Role> get roles => List.unmodifiable(_policy.roles.values);

  /// Returns the role with [id], or `null` if it is not registered.
  Role? getRole(String id) => _policy.roles[id];

  /// Registers [role] and returns it.
  ///
  /// Every permission it grants and every role it inherits from must already
  /// be registered. Throws [YetkiDuplicateException] if the id is taken,
  /// [YetkiNotFoundException] for an unknown reference and
  /// [YetkiInvalidPolicyException] for an invalid id or wildcard.
  Role addRole(Role role) {
    _checkNotDisposed();
    if (_policy.roles.containsKey(role.id)) {
      throw YetkiDuplicateException('Role "${role.id}" is already registered');
    }
    _commitRole(role);
    return role;
  }

  /// Registers every role in [roles], in any order, so roles may inherit
  /// from others in the same batch. Either all of them are added or, if one
  /// is invalid, none are.
  void addRoles(Iterable<Role> roles) {
    _checkNotDisposed();
    final candidate = _policy.copy();
    final added = <Role>[];
    for (final role in roles) {
      if (candidate.roles.containsKey(role.id)) {
        throw YetkiDuplicateException(
          'Role "${role.id}" is already registered',
        );
      }
      candidate.roles[role.id] = role;
      added.add(role);
    }
    added.forEach(candidate.checkRole);
    _policy = candidate;
    _changed();
  }

  /// Replaces the registered role that has the same id as [role].
  ///
  /// Throws [YetkiNotFoundException] if no such role is registered, and the
  /// same errors as [addRole] if the new version is invalid, including a
  /// [YetkiInvalidPolicyException] if it would create an inheritance cycle.
  Role updateRole(Role role) {
    _checkNotDisposed();
    if (!_policy.roles.containsKey(role.id)) {
      throw YetkiNotFoundException('Role "${role.id}" is not registered');
    }
    _commitRole(role);
    return role;
  }

  /// Grants [permission] (an id or a wildcard) to the role [roleId] and
  /// returns the updated role.
  Role grantPermissionToRole(String roleId, String permission) =>
      updateRole(_requireRole(roleId).withPermission(permission));

  /// Revokes [permission] from the role [roleId] and returns the updated
  /// role.
  Role revokePermissionFromRole(String roleId, String permission) =>
      updateRole(_requireRole(roleId).withoutPermission(permission));

  /// Unregisters the role with [id], removes it from the parents of every
  /// other role and unassigns it from the current user.
  ///
  /// Returns `false` if no such role was registered.
  bool removeRole(String id) {
    _checkNotDisposed();
    if (_policy.roles.remove(id) == null) return false;
    for (final role in [..._policy.roles.values]) {
      if (role.inherits.contains(id)) {
        _policy.roles[role.id] = role.copyWith(
          inherits: role.inherits.where((r) => r != id),
        );
      }
    }
    _pruneCurrentUser();
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Current user
  // ---------------------------------------------------------------------------

  /// The user that checks apply to by default, or `null` if none is set.
  YetkiUser? get currentUser => _currentUser;

  /// Sets the current user.
  ///
  /// Every role and direct grant of [user] must be registered, otherwise a
  /// [YetkiNotFoundException] is thrown. The current user is never persisted.
  void setUser(YetkiUser user) {
    _checkNotDisposed();
    _policy.checkUser(user);
    if (user == _currentUser) return;
    _currentUser = user;
    _changed(persist: false);
  }

  /// Clears the current user, for example on sign-out.
  void clearUser() {
    _checkNotDisposed();
    if (_currentUser == null) return;
    _currentUser = null;
    _changed(persist: false);
  }

  /// Assigns the role [roleId] to the current user.
  ///
  /// Returns `false` if it was already assigned. Throws a [StateError] if
  /// there is no current user.
  bool assignRole(String roleId) =>
      _updateUser((user) => user.withRole(roleId));

  /// Unassigns the role [roleId] from the current user.
  ///
  /// Returns `false` if it was not assigned. Throws a [StateError] if there
  /// is no current user.
  bool revokeRole(String roleId) =>
      _updateUser((user) => user.withoutRole(roleId));

  /// Grants [permission] (an id or a wildcard) directly to the current user.
  ///
  /// Returns `false` if it was already granted. Throws a [StateError] if
  /// there is no current user.
  bool grantDirectPermission(String permission) =>
      _updateUser((user) => user.withDirectPermission(permission));

  /// Revokes the direct grant [permission] from the current user.
  ///
  /// Returns `false` if it was not granted. Throws a [StateError] if there
  /// is no current user.
  bool revokeDirectPermission(String permission) =>
      _updateUser((user) => user.withoutDirectPermission(permission));

  // ---------------------------------------------------------------------------
  // Checks
  // ---------------------------------------------------------------------------

  /// Whether [user] (the current user by default) has [permission] through a
  /// direct grant, one of their roles, or a role those roles inherit from.
  ///
  /// Wildcard grants match too: `posts.*` allows `posts.edit` and `*` allows
  /// everything. Returns `false` when there is no user.
  bool hasPermission(String permission, {YetkiUser? user}) =>
      _accessOf(user)?.allows(permission) ?? false;

  /// Whether [user] has every permission in [permissions].
  bool hasAllPermissions(Iterable<String> permissions, {YetkiUser? user}) {
    final access = _accessOf(user);
    return access != null && permissions.every(access.allows);
  }

  /// Whether [user] has at least one permission in [permissions].
  bool hasAnyPermission(Iterable<String> permissions, {YetkiUser? user}) {
    final access = _accessOf(user);
    return access != null && permissions.any(access.allows);
  }

  /// Throws a [YetkiAccessDeniedException] unless [user] has [permission].
  void requirePermission(String permission, {YetkiUser? user}) {
    if (hasPermission(permission, user: user)) return;
    final who = user ?? _currentUser;
    throw YetkiAccessDeniedException(
      permission,
      who == null
          ? 'No user is set, so "$permission" is denied'
          : 'User "${who.id}" lacks permission "$permission"',
    );
  }

  /// Whether [user] (the current user by default) holds [roleId], either
  /// directly or because one of their roles inherits from it.
  ///
  /// Roles that are not registered are never held.
  bool hasRole(String roleId, {YetkiUser? user}) =>
      _accessOf(user)?.roles.contains(roleId) ?? false;

  /// Whether [user] holds every role in [roleIds].
  bool hasAllRoles(Iterable<String> roleIds, {YetkiUser? user}) {
    final access = _accessOf(user);
    return access != null && roleIds.every(access.roles.contains);
  }

  /// Whether [user] holds at least one role in [roleIds].
  bool hasAnyRole(Iterable<String> roleIds, {YetkiUser? user}) {
    final access = _accessOf(user);
    return access != null && roleIds.any(access.roles.contains);
  }

  /// The ids of every registered permission [user] (the current user by
  /// default) has, with wildcards expanded.
  Set<String> grantedPermissions({YetkiUser? user}) {
    final access = _accessOf(user);
    if (access == null) return const {};
    return _policy.permissions.keys.where(access.allows).toSet();
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Encodes the policy (permissions and roles, not the user) as JSON.
  Map<String, Object?> toJson() => _policy.toJson();

  /// Encodes the policy as a JSON string.
  String exportToJson() => jsonEncode(toJson());

  /// Replaces the policy with one decoded from [json], such as a string
  /// produced by [exportToJson] or received from your backend.
  ///
  /// The import is atomic: if [json] is malformed or invalid, a
  /// [YetkiException] is thrown and nothing changes. Roles and grants the
  /// current user holds that the new policy lacks are removed from them.
  void importFromJson(String json) => importFromMap(_decode(json));

  /// Like [importFromJson], but takes already decoded JSON.
  void importFromMap(Map<String, Object?> json) {
    _checkNotDisposed();
    _policy = Policy.fromJson(json);
    _pruneCurrentUser();
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Completes once every change made so far has been written to storage.
  Future<void> flush() => _queue;

  /// Clears the policy and the current user, and deletes the stored data.
  Future<void> reset() async {
    _checkNotDisposed();
    _policy = Policy();
    _currentUser = null;
    _currentAccess = null;
    _scheduleNotify();
    final storage = _storage;
    if (storage != null) await _enqueue(storage.delete);
  }

  /// Closes [changes] and waits for pending writes. The instance can still
  /// answer checks afterwards, but can no longer be changed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Not awaited: a paused listener would otherwise block disposal.
    unawaited(_changes.close());
    await flush();
  }

  // ---------------------------------------------------------------------------
  // Deprecated 0.1.x API
  // ---------------------------------------------------------------------------

  /// Use [currentUser] instead.
  @Deprecated('Use currentUser instead. Will be removed in 1.0.0.')
  YetkiUser? getCurrentUser() => currentUser;

  /// Use [roles] instead.
  @Deprecated('Use roles instead. Will be removed in 1.0.0.')
  List<Role> getAllRoles() => roles;

  /// Use [permissions] instead.
  @Deprecated('Use permissions instead. Will be removed in 1.0.0.')
  List<Permission> getAllPermissions() => permissions;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Access? _accessOf(YetkiUser? user) {
    if (user != null) return _policy.accessOf(user);
    final current = _currentUser;
    if (current == null) return null;
    return _currentAccess ??= _policy.accessOf(current);
  }

  Role _requireRole(String roleId) {
    final role = _policy.roles[roleId];
    if (role == null) {
      throw YetkiNotFoundException('Role "$roleId" is not registered');
    }
    return role;
  }

  void _commitRole(Role role) {
    final candidate = _policy.copy()..roles[role.id] = role;
    candidate.checkRole(role);
    _policy = candidate;
    _changed();
  }

  bool _updateUser(YetkiUser Function(YetkiUser user) update) {
    final user = _currentUser;
    if (user == null) throw StateError('No current user is set');
    final updated = update(user);
    if (updated == user) return false;
    setUser(updated);
    return true;
  }

  void _pruneCurrentUser() {
    final user = _currentUser;
    if (user != null) _currentUser = _policy.prune(user);
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('This Yetki instance has been disposed');
  }

  void _changed({bool persist = true}) {
    _currentAccess = null;
    if (persist) _scheduleSave();
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  /// Queues a write of the policy. Writes run one at a time, and changes made
  /// before a queued write starts are all saved by that single write.
  void _scheduleSave() {
    final storage = _storage;
    if (storage == null || _saveScheduled) return;
    _saveScheduled = true;
    unawaited(
      _enqueue(() async {
        _saveScheduled = false;
        try {
          await storage.write(exportToJson());
        } catch (error, stackTrace) {
          _onError(error, stackTrace);
        }
      }),
    );
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _restore() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final data = await storage.read();
      if (data != null) _policy = Policy.fromJson(_decode(data));
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  static Map<String, Object?> _decode(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw YetkiInvalidPolicyException('Invalid JSON: ${e.message}');
    }
    if (decoded is Map<String, Object?>) return decoded;
    throw const YetkiInvalidPolicyException('Policy must be a JSON object');
  }

  static void _logError(Object error, StackTrace stackTrace) {
    developer.log(
      'Storage error',
      name: 'yetki',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
