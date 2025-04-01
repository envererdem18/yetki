/// Represents a user in the RBAC system.
class YetkiUser {
  /// Unique identifier for the user
  final String id;

  /// Username or display name
  final String name;

  /// Set of role IDs assigned to this user
  final Set<String> _roleIds = {};

  /// Set of direct permission IDs assigned to this user
  final Set<String> _directPermissionIds = {};

  /// Creates a new [YetkiUser] instance.
  ///
  /// [id] - Unique identifier for the user
  /// [name] - Username or display name
  /// [roleIds] - Initial set of role IDs for this user
  /// [directPermissionIds] - Initial set of direct permission IDs for this user
  YetkiUser({
    required this.id,
    required this.name,
    Set<String>? roleIds,
    Set<String>? directPermissionIds,
  }) {
    if (roleIds != null) {
      _roleIds.addAll(roleIds);
    }
    if (directPermissionIds != null) {
      _directPermissionIds.addAll(directPermissionIds);
    }
  }

  /// Creates a user from JSON.
  factory YetkiUser.fromJson(Map<String, dynamic> json) {
    final user = YetkiUser(
      id: json['id'] as String,
      name: json['name'] as String,
    );

    if (json.containsKey('roleIds')) {
      final roles = json['roleIds'] as List;
      user._roleIds.addAll(roles.map((e) => e as String));
    }

    if (json.containsKey('directPermissionIds')) {
      final permissions = json['directPermissionIds'] as List;
      user._directPermissionIds.addAll(permissions.map((e) => e as String));
    }

    return user;
  }

  /// Converts the user to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roleIds': _roleIds.toList(),
      'directPermissionIds': _directPermissionIds.toList(),
    };
  }

  /// Gets the list of role IDs for this user.
  List<String> get roles => _roleIds.toList();

  /// Gets the list of direct permission IDs for this user.
  List<String> get directPermissions => _directPermissionIds.toList();

  /// Assigns a role to this user.
  ///
  /// [roleId] - The ID of the role to assign
  ///
  /// Returns true if the role was assigned, false if it was already assigned
  bool assignRole(String roleId) {
    return _roleIds.add(roleId);
  }

  /// Revokes a role from this user.
  ///
  /// [roleId] - The ID of the role to revoke
  ///
  /// Returns true if the role was revoked, false if it wasn't assigned
  bool revokeRole(String roleId) {
    return _roleIds.remove(roleId);
  }

  /// Checks if this user has a specific role.
  ///
  /// [roleId] - The ID of the role to check
  ///
  /// Returns true if the user has the role, false otherwise
  bool hasRole(String roleId) {
    return _roleIds.contains(roleId);
  }

  /// Grants a direct permission to this user.
  ///
  /// [permissionId] - The ID of the permission to grant
  ///
  /// Returns true if the permission was granted, false if it was already granted
  bool grantDirectPermission(String permissionId) {
    return _directPermissionIds.add(permissionId);
  }

  /// Revokes a direct permission from this user.
  ///
  /// [permissionId] - The ID of the permission to revoke
  ///
  /// Returns true if the permission was revoked, false if it wasn't granted
  bool revokeDirectPermission(String permissionId) {
    return _directPermissionIds.remove(permissionId);
  }

  /// Checks if this user has a specific direct permission.
  ///
  /// [permissionId] - The ID of the permission to check
  ///
  /// Returns true if the user has the direct permission, false otherwise
  bool hasDirectPermission(String permissionId) {
    return _directPermissionIds.contains(permissionId);
  }

  /// Clears all roles from this user.
  void clearRoles() {
    _roleIds.clear();
  }

  /// Clears all direct permissions from this user.
  void clearDirectPermissions() {
    _directPermissionIds.clear();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is YetkiUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'YetkiUser(id: $id, name: $name)';
}
