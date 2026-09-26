import '../internal.dart';

/// A user and the roles and direct permission grants assigned to them.
///
/// Instances are immutable and compare by value. Use [copyWith] or the `with`
/// helpers to derive a changed user, or call the matching methods on `Yetki`
/// to change the current user.
final class YetkiUser {
  /// Creates a user.
  YetkiUser({
    required this.id,
    this.name,
    Iterable<String> roles = const {},
    Iterable<String> directPermissions = const {},
  }) : roles = Set.unmodifiable(roles),
       directPermissions = Set.unmodifiable(directPermissions);

  /// Decodes a user produced by [toJson].
  ///
  /// Also accepts the `roleIds` and `directPermissionIds` fields written by
  /// yetki 0.1.x. Throws a `YetkiInvalidPolicyException` if [json] is
  /// malformed.
  factory YetkiUser.fromJson(Map<String, Object?> json) {
    const context = 'YetkiUser';
    return YetkiUser(
      id: readString(json, 'id', context),
      name: readOptionalString(json, 'name', context),
      roles: readStringSet(json, ['roles', 'roleIds'], context),
      directPermissions: readStringSet(json, [
        'directPermissions',
        'directPermissionIds',
      ], context),
    );
  }

  /// Unique identifier.
  final String id;

  /// Optional display name.
  final String? name;

  /// Ids of the roles assigned to this user. Unmodifiable.
  final Set<String> roles;

  /// Permission grants given to this user directly, outside of any role.
  /// Unmodifiable.
  final Set<String> directPermissions;

  /// Whether [roleId] is assigned to this user directly.
  ///
  /// This ignores role inheritance; use `Yetki.hasRole` for that.
  bool hasRole(String roleId) => roles.contains(roleId);

  /// Whether [permission] is granted to this user directly.
  ///
  /// This ignores roles and wildcards; use `Yetki.hasPermission` for that.
  bool hasDirectPermission(String permission) =>
      directPermissions.contains(permission);

  /// Returns a copy with the given fields replaced.
  YetkiUser copyWith({
    String? name,
    Iterable<String>? roles,
    Iterable<String>? directPermissions,
  }) => YetkiUser(
    id: id,
    name: name ?? this.name,
    roles: roles ?? this.roles,
    directPermissions: directPermissions ?? this.directPermissions,
  );

  /// Returns a copy that also has [roleId].
  YetkiUser withRole(String roleId) => copyWith(roles: {...roles, roleId});

  /// Returns a copy without [roleId].
  YetkiUser withoutRole(String roleId) =>
      copyWith(roles: roles.where((r) => r != roleId));

  /// Returns a copy that is also granted [permission] directly.
  YetkiUser withDirectPermission(String permission) =>
      copyWith(directPermissions: {...directPermissions, permission});

  /// Returns a copy without the direct grant [permission].
  YetkiUser withoutDirectPermission(String permission) => copyWith(
    directPermissions: directPermissions.where((p) => p != permission),
  );

  /// Encodes this user as JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    'roles': roles.toList(),
    'directPermissions': directPermissions.toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YetkiUser &&
          other.id == id &&
          other.name == name &&
          setEquals(other.roles, roles) &&
          setEquals(other.directPermissions, directPermissions);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAllUnordered(roles),
    Object.hashAllUnordered(directPermissions),
  );

  @override
  String toString() => 'YetkiUser($id)';
}
