import 'dart:async';

import 'core.dart';

// ============================================================================
// Watch function
// ============================================================================

// ============================================================================
// Watch function
// ============================================================================

/// Creates a worker that executes [callback] when [source] changes.
///
/// This is the low-level primitive for building reactions. It subscribes to the
/// [source], optionally transforms the event stream (e.g., debounce), and
/// executes the callback.
///
/// *   [source]: The reactive variable to watch.
/// *   [callback]: The function to call when value changes.
/// *   [transform]: Optional stream transformer (e.g., debounce).
/// *   [onError]: Optional error handler.
/// *   [onProcessingError]: Optional handler for errors during callback execution.
///
/// Returns a function that, when called, disposes the worker and cancels subscriptions.
///
/// ## Usage
/// ```dart
/// final dispose = watch(count, (v) => print(v));
/// // later
/// dispose();
/// ```
void Function() watch<T>(
  LxReactive<T> source,
  void Function(T value) callback, {
  Function(Object error, StackTrace stackTrace)? onError,
  Function(Object error, StackTrace stackTrace)? onProcessingError,
}) {
  void executeCallback(T value) {
    try {
      final result = (callback as dynamic)(value);
      if (result is Future && onProcessingError != null) {
        result.catchError((e, s) => onProcessingError(e, s));
      }
    } catch (e, s) {
      if (onProcessingError != null) {
        onProcessingError(e, s);
      } else {
        rethrow;
      }
    }
  }

  if (onError == null) {
    void listener() => executeCallback(source.value);
    source.addListener(listener);
    return () => source.removeListener(listener);
  }

  final subscription = source.stream.listen(
    executeCallback,
    onError: onError,
  );
  return subscription.cancel;
}

// ============================================================================
// Convenience workers
// ============================================================================

/// Watches [source] and calls [callback] when it becomes true.
///
/// Useful for triggering one-off actions or navigation when a boolean condition is met.
void Function() watchTrue(
  LxReactive<bool> source,
  void Function() callback, {
  Function(Object error, StackTrace stackTrace)? onProcessingError,
}) {
  return watch<bool>(
    source,
    (value) {
      if (value) return callback();
    },
    onProcessingError: onProcessingError,
  );
}

/// Watches [source] and calls [callback] when it becomes false.
///
/// Useful for triggering actions when a boolean condition is no longer met.
void Function() watchFalse(
  LxReactive<bool> source,
  void Function() callback, {
  Function(Object error, StackTrace stackTrace)? onProcessingError,
}) {
  return watch<bool>(
    source,
    (value) {
      if (!value) return callback();
    },
    onProcessingError: onProcessingError,
  );
}

/// Watches [source] and calls [callback] when it matches [targetValue].
///
/// Triggers whenever [source] updates to a value equal to [targetValue].
void Function() watchValue<T>(
  LxReactive<T> source,
  T targetValue,
  void Function() callback, {
  Function(Object error, StackTrace stackTrace)? onProcessingError,
}) {
  return watch<T>(
    source,
    (value) {
      if (value == targetValue) return callback();
    },
    onProcessingError: onProcessingError,
  );
}

// ============================================================================
// AsyncStatus specialized workers
// ============================================================================

/// Watches an [AsyncStatus] source and calls specific callbacks for each state.
///
/// This is a convenient way to handle side effects based on the status of an
/// asynchronous operation (e.g., showing a toast on error, navigating on success).
void Function() watchStatus<T>(
  LxReactive<AsyncStatus<T>> source, {
  void Function()? onIdle,
  void Function()? onWaiting,
  void Function(T value)? onSuccess,
  void Function(Object error)? onError,
  Function(Object error, StackTrace stackTrace)? onProcessingError,
}) {
  return watch<AsyncStatus<T>>(
    source,
    (status) {
      if (status is AsyncIdle<T>) {
        return onIdle?.call();
      } else if (status is AsyncWaiting<T>) {
        return onWaiting?.call();
      } else if (status is AsyncSuccess<T>) {
        return onSuccess?.call(status.value);
      } else if (status is AsyncError<T>) {
        return onError?.call(status.error);
      }
    },
    onProcessingError: onProcessingError,
  );
}
