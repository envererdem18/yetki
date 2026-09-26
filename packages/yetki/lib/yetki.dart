/// Role-based access control (RBAC) for Dart.
///
/// Register `Permission`s and `Role`s on a `Yetki` instance, set the current
/// `YetkiUser`, then ask `Yetki.hasPermission` or `Yetki.hasRole`. Roles can
/// inherit from other roles, and grants can use wildcards such as `posts.*`.
///
/// For Flutter widgets and shared_preferences storage, see the
/// `yetki_flutter` package.
library;

export 'src/exceptions.dart';
export 'src/models/permission.dart';
export 'src/models/role.dart';
export 'src/models/user.dart';
export 'src/storage.dart';
export 'src/yetki.dart';
