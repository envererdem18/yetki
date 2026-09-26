import 'exceptions.dart';
import 'internal.dart';
import 'models/permission.dart';
import 'models/role.dart';
import 'models/user.dart';

/// Version written to the `version` field of serialized policies.
const policyFormatVersion = 1;

final _idPattern = RegExp(r'^[^\s.*]+(\.[^\s.*]+)*$');

/// Whether [grant] is `*` or a prefix wildcard such as `posts.*`.
bool isWildcard(String grant) => grant == '*' || grant.endsWith('.*');

/// Throws unless [id] is a valid permission or role id.
void validateId(String id, String kind) {
  if (!_idPattern.hasMatch(id)) {
    throw YetkiInvalidPolicyException(
      'Invalid $kind id "$id": use non-empty dot-separated segments without '
      'whitespace or "*"',
    );
  }
}

/// The mutable permission and role registry behind a `Yetki` instance, with
/// the validation and resolution rules that keep it consistent.
final class Policy {
  /// Creates a policy from the given maps, which are keyed by id.
  Policy([Map<String, Permission>? permissions, Map<String, Role>? roles])
    : permissions = permissions ?? {},
      roles = roles ?? {};

  /// Decodes and fully validates a serialized policy.
  ///
  /// Accepts the current format as well as the 0.1.x cache format, whose
  /// `permissions` and `roles` are objects keyed by id. Any `currentUser`
  /// field in legacy data is ignored.
  factory Policy.fromJson(Object? decoded) {
    final json = asJsonObject(decoded, 'Policy');
    final version = json['version'];
    if (version != null && version != policyFormatVersion) {
      throw YetkiInvalidPolicyException(
        'Unsupported policy format version $version '
        '(this yetki reads version $policyFormatVersion)',
      );
    }

    final policy = Policy();
    for (final p in _entries(json['permissions'], 'permissions')) {
      final permission = Permission.fromJson(p);
      if (policy.permissions.containsKey(permission.id)) {
        throw YetkiDuplicateException(
          'Permission "${permission.id}" appears more than once',
        );
      }
      policy.permissions[permission.id] = permission;
    }
    for (final r in _entries(json['roles'], 'roles')) {
      final role = Role.fromJson(r);
      if (policy.roles.containsKey(role.id)) {
        throw YetkiDuplicateException(
          'Role "${role.id}" appears more than once',
        );
      }
      policy.roles[role.id] = role;
    }
    policy.validate();
    return policy;
  }

  /// Registered permissions keyed by id.
  final Map<String, Permission> permissions;

  /// Registered roles keyed by id.
  final Map<String, Role> roles;

  /// Returns a shallow copy that can be changed and validated without
  /// affecting this policy.
  Policy copy() => Policy({...permissions}, {...roles});

  /// Throws unless [grant] is a registered permission id or a valid wildcard.
  void checkGrant(String grant, String owner) {
    if (grant == '*') return;
    if (grant.endsWith('.*')) {
      validateId(grant.substring(0, grant.length - 2), 'wildcard prefix');
      return;
    }
    if (!permissions.containsKey(grant)) {
      throw YetkiNotFoundException(
        'Permission "$grant" granted to $owner is not registered',
      );
    }
  }

  /// Throws unless [role] has a valid id, grants and parent roles, and does
  /// not take part in an inheritance cycle. [role] must already be in [roles].
  void checkRole(Role role) {
    validateId(role.id, 'role');
    for (final grant in role.permissions) {
      checkGrant(grant, 'role "${role.id}"');
    }
    for (final parent in role.inherits) {
      if (!roles.containsKey(parent)) {
        throw YetkiNotFoundException(
          'Role "$parent" inherited by role "${role.id}" is not registered',
        );
      }
    }
    _checkNoCycle(role.id);
  }

  /// Throws unless every role and direct grant of [user] is registered.
  void checkUser(YetkiUser user) {
    for (final roleId in user.roles) {
      if (!roles.containsKey(roleId)) {
        throw YetkiNotFoundException(
          'Role "$roleId" assigned to user "${user.id}" is not registered',
        );
      }
    }
    for (final grant in user.directPermissions) {
      checkGrant(grant, 'user "${user.id}"');
    }
  }

  /// Validates the whole policy.
  void validate() {
    for (final entry in permissions.entries) {
      validateId(entry.key, 'permission');
      if (entry.value.id != entry.key) {
        throw YetkiInvalidPolicyException(
          'Permission stored under "${entry.key}" has id "${entry.value.id}"',
        );
      }
    }
    for (final entry in roles.entries) {
      if (entry.value.id != entry.key) {
        throw YetkiInvalidPolicyException(
          'Role stored under "${entry.key}" has id "${entry.value.id}"',
        );
      }
      checkRole(entry.value);
    }
  }

  /// Returns [user] without any role or direct grant this policy no longer
  /// contains, or [user] itself if nothing had to be removed.
  YetkiUser prune(YetkiUser user) {
    final roleIds = user.roles.where(roles.containsKey).toSet();
    final grants = user.directPermissions
        .where((g) => isWildcard(g) || permissions.containsKey(g))
        .toSet();
    if (roleIds.length == user.roles.length &&
        grants.length == user.directPermissions.length) {
      return user;
    }
    return user.copyWith(roles: roleIds, directPermissions: grants);
  }

  /// Resolves the roles and grants [user] effectively holds.
  Access accessOf(YetkiUser user) {
    final effectiveRoles = <String>{};
    final pending = [...user.roles];
    while (pending.isNotEmpty) {
      final role = roles[pending.removeLast()];
      if (role == null || !effectiveRoles.add(role.id)) continue;
      pending.addAll(role.inherits);
    }
    return Access(effectiveRoles, {
      ...user.directPermissions,
      for (final roleId in effectiveRoles) ...roles[roleId]!.permissions,
    });
  }

  /// Encodes this policy in the current format.
  Map<String, Object?> toJson() => {
    'version': policyFormatVersion,
    'permissions': [for (final p in permissions.values) p.toJson()],
    'roles': [for (final r in roles.values) r.toJson()],
  };

  void _checkNoCycle(String roleId) {
    final visited = <String>{};
    final pending = [...?roles[roleId]?.inherits];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (current == roleId) {
        throw YetkiInvalidPolicyException(
          'Role "$roleId" inherits from itself through its parent roles',
        );
      }
      if (visited.add(current)) pending.addAll([...?roles[current]?.inherits]);
    }
  }

  static Iterable<Map<String, Object?>> _entries(Object? value, String key) {
    if (value == null) return const [];
    // Current format: a list of objects.
    if (value is List) {
      return [for (final e in value) asJsonObject(e, 'Each of "$key"')];
    }
    // 0.1.x format: an object keyed by id.
    if (value is Map<String, Object?>) {
      return [for (final e in value.values) asJsonObject(e, 'Each of "$key"')];
    }
    throw YetkiInvalidPolicyException('"$key" must be a list');
  }
}

/// The resolved roles and grants of one user, used to answer checks quickly.
final class Access {
  /// Creates the access for the given effective roles and grants.
  Access(this.roles, Set<String> grants)
    : _all = grants.contains('*'),
      _exact = grants.where((g) => !isWildcard(g)).toSet(),
      _prefixes = [
        for (final g in grants)
          if (g != '*' && g.endsWith('.*')) g.substring(0, g.length - 1),
      ];

  /// Assigned roles plus every role they inherit from.
  final Set<String> roles;

  final bool _all;
  final Set<String> _exact;

  /// Wildcard prefixes including the trailing dot, e.g. `posts.`.
  final List<String> _prefixes;

  /// Whether these grants allow [permission].
  bool allows(String permission) =>
      _all ||
      _exact.contains(permission) ||
      _prefixes.any(permission.startsWith);
}
