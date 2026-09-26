import 'package:flutter/widgets.dart';
import 'package:yetki/yetki.dart';

import 'yetki_scope.dart';

/// Builds a widget from the nearest [Yetki], rebuilding when it changes.
class YetkiBuilder extends StatelessWidget {
  /// Creates a builder.
  const YetkiBuilder({super.key, required this.builder});

  /// Called with the nearest [Yetki] whenever it changes.
  final Widget Function(BuildContext context, Yetki yetki) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context, YetkiScope.of(context));
}

/// Shows [child] if [check] passes for the nearest [Yetki], and [fallback]
/// otherwise. Re-evaluates whenever the policy or the current user changes.
///
/// [PermissionGuard] and [RoleGuard] cover the common checks.
class YetkiGuard extends StatelessWidget {
  /// Creates a guard with a custom [check].
  const YetkiGuard({
    super.key,
    required this.check,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  /// Decides whether [child] is shown.
  final bool Function(Yetki yetki) check;

  /// Shown when [check] passes.
  final Widget child;

  /// Shown when [check] fails. Defaults to an empty box.
  final Widget fallback;

  @override
  Widget build(BuildContext context) =>
      check(YetkiScope.of(context)) ? child : fallback;
}

/// Shows [child] only if the current user has the required permissions.
///
/// ```dart
/// PermissionGuard(
///   permission: 'posts.delete',
///   child: DeleteButton(),
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  /// Requires [permission].
  const PermissionGuard({
    super.key,
    required String permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _permission = permission,
       _permissions = const [],
       _requireAll = true;

  /// Requires at least one of [permissions].
  const PermissionGuard.any({
    super.key,
    required List<String> permissions,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _permission = null,
       _permissions = permissions,
       _requireAll = false;

  /// Requires every one of [permissions].
  const PermissionGuard.all({
    super.key,
    required List<String> permissions,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _permission = null,
       _permissions = permissions,
       _requireAll = true;

  final String? _permission;
  final List<String> _permissions;
  final bool _requireAll;

  /// Shown when the check passes.
  final Widget child;

  /// Shown when the check fails. Defaults to an empty box.
  final Widget fallback;

  @override
  Widget build(BuildContext context) => YetkiGuard(
    check: (yetki) {
      final single = _permission;
      if (single != null) return yetki.hasPermission(single);
      return _requireAll
          ? yetki.hasAllPermissions(_permissions)
          : yetki.hasAnyPermission(_permissions);
    },
    fallback: fallback,
    child: child,
  );
}

/// Shows [child] only if the current user holds the required roles, directly
/// or through inheritance.
class RoleGuard extends StatelessWidget {
  /// Requires [role].
  const RoleGuard({
    super.key,
    required String role,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _role = role,
       _roles = const [],
       _requireAll = true;

  /// Requires at least one of [roles].
  const RoleGuard.any({
    super.key,
    required List<String> roles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _role = null,
       _roles = roles,
       _requireAll = false;

  /// Requires every one of [roles].
  const RoleGuard.all({
    super.key,
    required List<String> roles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  }) : _role = null,
       _roles = roles,
       _requireAll = true;

  final String? _role;
  final List<String> _roles;
  final bool _requireAll;

  /// Shown when the check passes.
  final Widget child;

  /// Shown when the check fails. Defaults to an empty box.
  final Widget fallback;

  @override
  Widget build(BuildContext context) => YetkiGuard(
    check: (yetki) {
      final single = _role;
      if (single != null) return yetki.hasRole(single);
      return _requireAll ? yetki.hasAllRoles(_roles) : yetki.hasAnyRole(_roles);
    },
    fallback: fallback,
    child: child,
  );
}
