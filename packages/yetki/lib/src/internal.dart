import 'exceptions.dart';

/// Reads a required string field from decoded JSON.
String readString(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value is String) return value;
  throw YetkiInvalidPolicyException(
    '$context: "$key" must be a string, got ${_describe(value)}',
  );
}

/// Reads an optional string field from decoded JSON.
String? readOptionalString(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw YetkiInvalidPolicyException(
    '$context: "$key" must be a string or null, got ${_describe(value)}',
  );
}

/// Reads an optional list of strings from decoded JSON, trying each key in
/// order so that legacy field names can be accepted.
Set<String> readStringSet(
  Map<String, Object?> json,
  List<String> keys,
  String context,
) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is List && value.every((e) => e is String)) {
      return value.cast<String>().toSet();
    }
    throw YetkiInvalidPolicyException(
      '$context: "$key" must be a list of strings, got ${_describe(value)}',
    );
  }
  return const {};
}

/// Casts decoded JSON to an object map or throws a policy error.
Map<String, Object?> asJsonObject(Object? value, String context) {
  if (value is Map<String, Object?>) return value;
  throw YetkiInvalidPolicyException(
    '$context must be a JSON object, got ${_describe(value)}',
  );
}

/// Order-independent equality of two sets.
bool setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

String _describe(Object? value) =>
    value == null ? 'null' : value.runtimeType.toString();
