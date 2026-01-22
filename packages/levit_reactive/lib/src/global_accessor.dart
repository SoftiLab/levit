import 'core.dart';
import 'middlewares.dart';
import 'package:meta/meta.dart';
import 'watchers.dart';

/// The global entry point for the Levit reactive engine.
///
/// [Lx] provides static access to core functionality, including configuration,
/// dependency tracking, and batching.
class Lx {
  /// The active observer capturing dependencies.
  static LevitReactiveObserver? get proxy => LevitStateCore.proxy;

  /// Sets the active observer. Used by [LWatch] and [LxComputed].
  static set proxy(LevitReactiveObserver? value) {
    LevitStateCore.proxy = value;
  }

  /// Whether to capture stack traces on state changes (performance intensive).
  static bool get captureStackTrace => LevitStateCore.captureStackTrace;

  static set captureStackTrace(bool value) {
    LevitStateCore.captureStackTrace = value;
  }

  /// Global flag to enable or disable performance monitoring for all [LxWatch] instances.
  ///
  /// When `true` (default), watchers track execution counts and durations.
  static bool enableWatchMonitoring = true;

  /// Registers a new [LevitReactiveMiddleware] to intercept or observe state changes.
  static LevitReactiveMiddleware addMiddleware(
      LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.add(middleware);
  }

  /// Unregisters a previously added middleware.
  static bool removeMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.remove(middleware);
  }

  /// Removes all active middlewares.
  static void clearMiddlewares() {
    LevitReactiveMiddleware.clear();
  }

  /// Checks if a particular middleware is currently registered.
  static bool containsMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.contains(middleware);
  }

  /// Executes [action] while temporarily bypassing all registered middlewares.
  static void runWithoutMiddleware(void Function() action) {
    LevitReactiveMiddleware.runWithoutMiddleware(action);
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications for all variables mutated inside the batch are deferred
  /// until the callback completes, ensuring only a single notification per variable.
  static R batch<R>(R Function() callback) {
    return LevitStateCore.batch(callback);
  }

  /// Executes asynchronous [callback] in a batch.
  ///
  /// Like [batch], but maintains the batching context across asynchronous gaps.
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return LevitStateCore.batchAsync(callback);
  }

  /// Returns `true` if a batching operation is currently in progress.
  static bool get isBatching => LevitStateCore.isBatching;

  /// Internal: Enters an asynchronous tracking scope.
  @internal
  static void enterAsyncScope() {
    LevitStateCore.enterAsyncScope();
  }

  /// Internal: Exits an asynchronous tracking scope.
  @internal
  static void exitAsyncScope() {
    LevitStateCore.exitAsyncScope();
  }

  /// Internal: Zone key for identifying the active async computed tracker.
  @internal
  static Object get asyncComputedTrackerZoneKey =>
      LevitStateCore.asyncComputedTrackerZoneKey;
}
