/// Custom exception class for Yetki-related errors.
class YetkiException implements Exception {
  /// Error message
  final String message;

  /// Creates a new [YetkiException] with the given message.
  YetkiException(this.message);

  @override
  String toString() => 'YetkiException: $message';
}
