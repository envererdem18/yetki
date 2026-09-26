/// Base class of every error thrown by yetki.
///
/// The hierarchy is sealed, so a `switch` over a [YetkiException] can handle
/// every case exhaustively. Catch this type to handle all yetki errors at once.
sealed class YetkiException implements Exception {
  const YetkiException(this.message);

  /// Human-readable description of the error.
  final String message;

  String get _name;

  @override
  String toString() => '$_name: $message';
}

/// Thrown when adding a permission or role whose id is already registered.
final class YetkiDuplicateException extends YetkiException {
  /// Creates a [YetkiDuplicateException].
  const YetkiDuplicateException(super.message);

  @override
  String get _name => 'YetkiDuplicateException';
}

/// Thrown when an operation references a permission or role that is not
/// registered.
final class YetkiNotFoundException extends YetkiException {
  /// Creates a [YetkiNotFoundException].
  const YetkiNotFoundException(super.message);

  @override
  String get _name => 'YetkiNotFoundException';
}

/// Thrown when a policy is malformed: an invalid id or wildcard, a role
/// inheritance cycle, or JSON that cannot be decoded into a policy.
final class YetkiInvalidPolicyException extends YetkiException {
  /// Creates a [YetkiInvalidPolicyException].
  const YetkiInvalidPolicyException(super.message);

  @override
  String get _name => 'YetkiInvalidPolicyException';
}

/// Thrown by `Yetki.requirePermission` when the user lacks a permission.
final class YetkiAccessDeniedException extends YetkiException {
  /// Creates a [YetkiAccessDeniedException] for [permission].
  const YetkiAccessDeniedException(this.permission, super.message);

  /// The permission that was required.
  final String permission;

  @override
  String get _name => 'YetkiAccessDeniedException';
}
