/// Represents a permission in the RBAC system.
class Permission {
  /// Unique identifier for the permission
  final String id;

  /// Human-readable name of the permission
  final String name;

  /// Optional description of the permission
  final String? description;

  /// Creates a new [Permission] instance.
  ///
  /// [id] - Unique identifier for the permission
  /// [name] - Human-readable name of the permission
  /// [description] - Optional description of the permission
  Permission({required this.id, required this.name, this.description});

  /// Creates a permission from JSON.
  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Converts the permission to JSON.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'description': description};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Permission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Permission(id: $id, name: $name)';
}
