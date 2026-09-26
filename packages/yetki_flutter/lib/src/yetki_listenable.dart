import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yetki/yetki.dart';

/// A [Listenable] that notifies whenever [yetki]'s policy or current user
/// changes.
///
/// Useful where Flutter APIs expect a [Listenable], such as go_router's
/// `refreshListenable`, so that redirects are re-evaluated when permissions
/// change. Call [dispose] when it is no longer needed.
class YetkiListenable extends ChangeNotifier {
  /// Creates a listenable for [yetki].
  YetkiListenable(this.yetki) {
    _subscription = yetki.changes.listen((_) => notifyListeners());
  }

  /// The instance being listened to.
  final Yetki yetki;

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
