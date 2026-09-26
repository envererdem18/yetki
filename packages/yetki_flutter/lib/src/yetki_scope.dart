import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:yetki/yetki.dart';

/// Provides a [Yetki] to the widget tree and rebuilds dependents whenever its
/// policy or current user changes.
///
/// Read it with [YetkiScope.of], `context.yetki` or `context.can(...)`, or use
/// the guard widgets. The scope does not own the [Yetki]: dispose it yourself
/// when it is no longer needed.
class YetkiScope extends StatefulWidget {
  /// Creates a scope that provides [yetki] to [child].
  const YetkiScope({super.key, required this.yetki, required this.child});

  /// The instance to provide.
  final Yetki yetki;

  /// The widget below this scope.
  final Widget child;

  /// Returns the nearest [Yetki] and makes [context] rebuild when it changes.
  ///
  /// Throws a [FlutterError] if there is no [YetkiScope] above [context].
  static Yetki of(BuildContext context) {
    final yetki = maybeOf(context);
    if (yetki != null) return yetki;
    throw FlutterError.fromParts([
      ErrorSummary('YetkiScope.of() called with no YetkiScope in context.'),
      ErrorHint('Wrap your app (or this subtree) in a YetkiScope.'),
      context.describeElement('The context used was'),
    ]);
  }

  /// Like [of], but returns `null` if there is no [YetkiScope] above
  /// [context].
  static Yetki? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_YetkiInheritedScope>()?.yetki;

  @override
  State<YetkiScope> createState() => _YetkiScopeState();
}

class _YetkiScopeState extends State<YetkiScope> {
  StreamSubscription<void>? _subscription;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(YetkiScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yetki != widget.yetki) {
      unawaited(_subscription?.cancel());
      _subscribe();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.yetki.changes.listen((_) {
      if (mounted) setState(() => _version++);
    });
  }

  @override
  Widget build(BuildContext context) => _YetkiInheritedScope(
    yetki: widget.yetki,
    version: _version,
    child: widget.child,
  );
}

class _YetkiInheritedScope extends InheritedWidget {
  const _YetkiInheritedScope({
    required this.yetki,
    required this.version,
    required super.child,
  });

  final Yetki yetki;
  final int version;

  @override
  bool updateShouldNotify(_YetkiInheritedScope oldWidget) =>
      yetki != oldWidget.yetki || version != oldWidget.version;
}

/// Shortcuts for reading the nearest [YetkiScope].
///
/// Both members make the calling widget rebuild when the policy or the
/// current user changes.
extension YetkiBuildContext on BuildContext {
  /// The nearest [Yetki]. See [YetkiScope.of].
  Yetki get yetki => YetkiScope.of(this);

  /// Whether the current user has [permission]. See [Yetki.hasPermission].
  bool can(String permission) => YetkiScope.of(this).hasPermission(permission);
}
