/// Persists a serialized yetki policy (permissions and roles).
///
/// Implement this to keep the policy in a file, a database, secure storage or
/// anywhere else. `yetki_flutter` ships a shared_preferences implementation.
///
/// The current user is never written to storage: who the user is and which
/// roles they hold must come from your authentication backend on every start.
abstract interface class YetkiStorage {
  /// Returns the stored data, or `null` if nothing has been stored.
  Future<String?> read();

  /// Replaces the stored data with [data].
  Future<void> write(String data);

  /// Deletes the stored data.
  Future<void> delete();
}

/// A [YetkiStorage] that keeps data in memory. Useful for tests.
final class InMemoryYetkiStorage implements YetkiStorage {
  /// Creates an in-memory storage, optionally pre-filled with [data].
  InMemoryYetkiStorage([this.data]);

  /// The currently stored data.
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;

  @override
  Future<void> delete() async => data = null;
}
