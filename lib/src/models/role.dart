/// Represents a role in the RBAC system.
class Role {
  /// Unique identifier for the role
  final String id;

  /// Human-readable name of the role
  final String name;

  /// Optional description of the role
  final String? description;

  /// Set of permission IDs associated with this role
  final Set<String> _permissionIds = {};

  /// Creates a new [Role] instance.
  ///
  /// [id] - Unique identifier for the role
  /// [name] - Human-readable name of the role
  /// [description] - Optional description of the role
  /// [permissionIds] - Initial set of permission IDs for this role
  Role({
    required this.id,
    required this.name,
    this.description,
    Set<String>? permissionIds,
  }) {
    if (permissionIds != null) {
      _permissionIds.addAll(permissionIds);
    }
  }

  /// Creates a role from JSON.
  factory Role.fromJson(Map<String, dynamic> json) {
    final role = Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );

    if (json.containsKey('permissionIds')) {
      final permissions = json['permissionIds'] as List;
      role._permissionIds.addAll(permissions.map((e) => e as String));
    }

    return role;
  }

  /// Converts the role to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissionIds': _permissionIds.toList(),
    };
  }

  /// Gets the list of permission IDs for this role.
  List<String> get permissionIds => _permissionIds.toList();

  /// Adds a permission to this role.
  ///
  /// [permissionId] - The ID of the permission to add
  ///
  /// Returns true if the permission was added, false if it already existed
  bool addPermission(String permissionId) {
    return _permissionIds.add(permissionId);
  }

  /// Removes a permission from this role.
  ///
  /// [permissionId] - The ID of the permission to remove
  ///
  /// Returns true if the permission was removed, false if it didn't exist
  bool removePermission(String permissionId) {
    return _permissionIds.remove(permissionId);
  }

  /// Checks if this role has a specific permission.
  ///
  /// [permissionId] - The ID of the permission to check
  ///
  /// Returns true if the role has the permission, false otherwise
  bool hasPermission(String permissionId) {
    return _permissionIds.contains(permissionId);
  }

  /// Clears all permissions from this role.
  void clearPermissions() {
    _permissionIds.clear();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Role && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role(id: $id, name: $name)';
}
