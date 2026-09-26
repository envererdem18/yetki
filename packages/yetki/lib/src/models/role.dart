import '../internal.dart';

/// A named set of permission grants that can be assigned to users.
///
/// [permissions] holds grants: exact permission ids, `*` for every permission,
/// or a prefix wildcard such as `posts.*`. [inherits] lists the ids of roles
/// whose grants this role also receives, so an `editor` role can inherit from
/// `viewer` instead of repeating its permissions.
///
/// Instances are immutable and compare by value. Use [copyWith],
/// [withPermission] or [withoutPermission] to derive a changed role, then pass
/// it to `Yetki.updateRole`.
final class Role {
  /// Creates a role. [name] defaults to [id].
  Role({
    required this.id,
    String? name,
    this.description,
    Iterable<String> permissions = const {},
    Iterable<String> inherits = const {},
  }) : name = name ?? id,
       permissions = Set.unmodifiable(permissions),
       inherits = Set.unmodifiable(inherits);

  /// Decodes a role produced by [toJson].
  ///
  /// Also accepts the `permissionIds` field written by yetki 0.1.x.
  /// Throws a `YetkiInvalidPolicyException` if [json] is malformed.
  factory Role.fromJson(Map<String, Object?> json) {
    const context = 'Role';
    return Role(
      id: readString(json, 'id', context),
      name: readOptionalString(json, 'name', context),
      description: readOptionalString(json, 'description', context),
      permissions: readStringSet(json, [
        'permissions',
        'permissionIds',
      ], context),
      inherits: readStringSet(json, ['inherits'], context),
    );
  }

  /// Unique identifier, for example `editor`.
  final String id;

  /// Human-readable name.
  final String name;

  /// Optional longer description.
  final String? description;

  /// Permission grants given directly by this role. Unmodifiable.
  final Set<String> permissions;

  /// Ids of the roles this role inherits grants from. Unmodifiable.
  final Set<String> inherits;

  /// Returns a copy with the given fields replaced.
  Role copyWith({
    String? name,
    String? description,
    Iterable<String>? permissions,
    Iterable<String>? inherits,
  }) => Role(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    permissions: permissions ?? this.permissions,
    inherits: inherits ?? this.inherits,
  );

  /// Returns a copy that also grants [permission].
  Role withPermission(String permission) =>
      copyWith(permissions: {...permissions, permission});

  /// Returns a copy that no longer grants [permission].
  Role withoutPermission(String permission) =>
      copyWith(permissions: permissions.where((p) => p != permission));

  /// Encodes this role as JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'permissions': permissions.toList(),
    if (inherits.isNotEmpty) 'inherits': inherits.toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          setEquals(other.permissions, permissions) &&
          setEquals(other.inherits, inherits);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    Object.hashAllUnordered(permissions),
    Object.hashAllUnordered(inherits),
  );

  @override
  String toString() => 'Role($id)';
}
