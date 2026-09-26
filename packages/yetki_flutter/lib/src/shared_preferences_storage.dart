import 'package:shared_preferences/shared_preferences.dart';
import 'package:yetki/yetki.dart';

/// A [YetkiStorage] backed by shared_preferences.
///
/// shared_preferences is plain, unencrypted storage that can be read and
/// edited on rooted devices and in the browser. Only the policy (permissions
/// and roles) is stored, never the current user, but treat it as a cache: your
/// server must still enforce authorization.
///
/// The default [key] is the one yetki 0.1.x used, so an existing cache is
/// picked up when upgrading. The user that 0.1.x stored there is ignored.
final class SharedPreferencesYetkiStorage implements YetkiStorage {
  /// Creates a storage that uses [key]. Pass [preferences] to use a specific
  /// instance instead of `SharedPreferences.getInstance()`.
  SharedPreferencesYetkiStorage({
    this.key = 'yetki_cache',
    SharedPreferences? preferences,
  }) : _preferences = preferences;

  /// The shared_preferences key the policy is stored under.
  final String key;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _instance async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read() async => (await _instance).getString(key);

  @override
  Future<void> write(String data) async {
    await (await _instance).setString(key, data);
  }

  @override
  Future<void> delete() async {
    await (await _instance).remove(key);
  }
}
