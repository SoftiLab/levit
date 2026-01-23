import 'dart:async';
import 'package:levit_dart/levit_dart.dart';

/// A mixin for [LevitController] that manages periodic timers.
///
/// Features:
/// *   [startPeriodic] to run a callback repeatedly.
/// *   Automatic cancellation of timers when the controller is closed.
mixin LevitPeriodicMixin on LevitController {
  final _timers = <Timer>[];

  /// Starts a periodic timer that runs [callback] every [duration].
  ///
  /// The timer is automatically cancelled when the controller is closed.
  /// Returns the [Timer] instance if you need to cancel it manually.
  Timer startPeriodic(Duration duration, void Function(Timer timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _timers.add(timer);

    // Auto-remove from list if cancelled manually?
    // Complicated because Timer doesn't have onCancel callback.
    // We rely on autoDispose or onClose to clean up.

    return timer;
  }

  @override
  void onClose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.onClose();
  }
}
