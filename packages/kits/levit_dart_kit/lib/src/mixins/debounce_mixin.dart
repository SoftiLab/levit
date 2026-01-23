import 'dart:async';
import 'package:levit_dart/levit_dart.dart';

/// A mixin for [LevitController] that provides debouncing capabilities.
///
/// Features:
/// *   [debounce] to limit the rate of function execution.
mixin LevitDebounceMixin on LevitController {
  final _debounceTimers = <String, Timer>{};

  /// Debounces a [callback] function.
  ///
  /// *   [id]: A unique identifier for this debounce operation.
  /// *   [duration]: The time to wait before executing the callback.
  /// *   [callback]: The function to execute.
  ///
  /// If this method is called again with the same [id] before [duration] has passed,
  /// the previous call is cancelled and the timer is reset.
  void debounce(String id, Duration duration, void Function() callback) {
    if (_debounceTimers.containsKey(id)) {
      _debounceTimers[id]?.cancel();
    }

    _debounceTimers[id] = Timer(duration, () {
      _debounceTimers.remove(id);
      callback();
    });
  }

  /// Cancels a pending debounce operation for [id].
  void cancelDebounce(String id) {
    if (_debounceTimers.containsKey(id)) {
      _debounceTimers[id]?.cancel();
      _debounceTimers.remove(id);
    }
  }

  /// Cancels all pending debounce operations.
  void cancelAllDebounces() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  @override
  void onClose() {
    cancelAllDebounces();
    super.onClose();
  }
}
