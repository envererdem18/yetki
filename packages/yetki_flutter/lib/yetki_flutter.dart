/// Flutter bindings for the `yetki` RBAC library.
///
/// Wrap your app in a `YetkiScope`, then use `PermissionGuard`, `RoleGuard`,
/// `YetkiBuilder` or `context.can(...)` to show UI based on the current
/// user's permissions. Everything from `package:yetki` is re-exported.
library;

export 'package:yetki/yetki.dart';

export 'src/guards.dart';
export 'src/shared_preferences_storage.dart';
export 'src/yetki_listenable.dart';
export 'src/yetki_scope.dart';
