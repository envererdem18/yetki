import '../internal.dart';

/// A single capability, such as `posts.edit`, that can be granted to roles or
/// directly to users.
///
/// Ids are made of dot-separated segments. Segments must be non-empty and may
/// not contain whitespace or `*`. The dots let grants use wildcards: a role
/// granted `posts.*` has `posts.edit` and `posts.comments.delete`.
///
/// Instances are immutable and compare by value.
final class Permission {
  /// Creates a permission. [name] defaults to [id].
  const Permission({required this.id, String? name, this.description})
    : name = name ?? id;

  /// Decodes a permission produced by [toJson].
  ///
  /// Throws a `YetkiInvalidPolicyException` if [json] is malformed.
  factory Permission.fromJson(Map<String, Object?> json) {
    const context = 'Permission';
    return Permission(
      id: readString(json, 'id', context),
      name: readOptionalString(json, 'name', context),
      description: readOptionalString(json, 'description', context),
    );
  }

  /// Unique identifier, for example `posts.edit`.
  final String id;

  /// Human-readable name.
  final String name;

  /// Optional longer description.
  final String? description;

  /// Returns a copy with the given fields replaced.
  Permission copyWith({String? name, String? description}) => Permission(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
  );

  /// Encodes this permission as JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          other.id == id &&
          other.name == name &&
          other.description == description;

  @override
  int get hashCode => Object.hash(id, name, description);

  @override
  String toString() => 'Permission($id)';
}
