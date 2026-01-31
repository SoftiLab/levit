part of '../levit_dart_core.dart';

/// The primary entry point for orchestrating dependency injection and reactivity in Levit.
///
/// [Levit] provides a unified API for managing [LevitController] lifecycles,
/// resolving dependencies via [LevitScope], and working with reactive state.
class Levit {
  // ------------------------------------------------------------
  //    Reactive API accessors
  // ------------------------------------------------------------

  /// Whether to capture stack traces on state changes.
  ///
  /// This is performance intensive and should only be used during debugging.
  static bool get captureStackTrace => Lx.captureStackTrace;

  static set captureStackTrace(bool value) {
    Lx.captureStackTrace = value;
  }

  /// Whether to enable performance monitoring for all [LxWorker] instances.
  static bool get enableWatchMonitoring => Lx.enableWatchMonitoring;

  static set enableWatchMonitoring(bool value) {
    Lx.enableWatchMonitoring = value;
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications for all variables mutated inside the batch are deferred
  /// until the [callback] completes, ensuring only a single notification per variable.
  static R batch<R>(R Function() callback) {
    return Lx.batch(callback);
  }

  /// Executes asynchronous [callback] in a batch.
  ///
  /// Maintains the batching context across asynchronous gaps, similar to [batch].
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return Lx.batchAsync(callback);
  }

  /// Executes [action] while temporarily bypassing all registered middlewares.
  static void runWithoutStateMiddleware(void Function() action) {
    Lx.runWithoutMiddleware(action);
  }

  /// Removes all active state middlewares.
  static void clearStateMiddlewares() {
    Lx.clearMiddlewares();
  }

  /// Checks if a particular state middleware is currently registered.
  static bool containsStateMiddleware(LevitReactiveMiddleware middleware) {
    return Lx.containsMiddleware(middleware);
  }

  /// The context is passed to [LevitReactiveMiddleware.startedListening]
  /// and [LevitReactiveMiddleware.stoppedListening].
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return Lx.runWithContext(context, fn);
  }

  // ------------------------------------------------------------
  //    Levit API accessors
  // ------------------------------------------------------------

  /// Instantiates and registers a dependency using a [builder].
  ///
  /// The [builder] is executed immediately. If [Levit.enableAutoLinking] is
  /// active, any reactive variables created during execution are automatically
  /// captured and linked to the resulting instance for cleanup.
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Levit.put(() => MyService());
  /// ```
  ///
  /// If [permanent] is true, the instance survives a non-forced [reset].
  /// Use [tag] as an optional unique identifier to allow multiple instances
  /// of the same type [S].
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return Ls.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  ///
  /// If [permanent] is true, the registration persists through a [reset].
  /// If [isFactory] is true, a new instance is created every time [find] is called.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    Ls.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous [builder] for lazy instantiation.
  ///
  /// Use [findAsync] to retrieve the instance once the future completes.
  ///
  /// * [builder]: A function returning a [Future] of the dependency.
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration persists through a [reset].
  /// * [isFactory]: If `true`, the builder is re-run for every [findAsync] call.
  static Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return Ls.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Resolves a dependency of type [S] or identified by [key] or [tag].
  ///
  /// Throws an [Exception] if no registration is found.
  /// Resolves a dependency of type [S] or identified by [key] or [tag].
  ///
  /// Throws an [Exception] if no registration is found.
  static S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.findIn(Ls.currentScope, tag: tag) as S;
    }
    return Ls.find<S>(tag: tag);
  }

  /// Retrieves the registered instance of type [S], or returns `null` if not found.
  ///
  /// * [key]: A specific [LevitStore] to resolve.
  /// * [tag]: The unique identifier used during registration.
  static S? findOrNull<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      try {
        return key.findIn(Ls.currentScope, tag: tag) as S;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNull<S>(tag: tag);
  }

  /// Asynchronously resolves a dependency of type [S] or identified by [key] or [tag].
  ///
  /// Useful for dependencies registered via [lazyPutAsync].
  /// Throws an [Exception] if no registration is found.
  static Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
      if (result is Future && result is! S) return await result as S;
      return result as S;
    }
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S], or returns `null`.
  ///
  /// * [key]: A specific [LevitStore] to resolve.
  /// * [tag]: The unique identifier used during registration.
  static Future<S?> findOrNullAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      try {
        final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
        if (result is Future && result is! S?) return await result as S?;
        return result as S?;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNullAsync<S>(tag: tag);
  }

  /// Whether type [S] is registered in the current or any parent scope.
  static bool isRegistered<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.isRegisteredIn(Ls.currentScope, tag: tag);
    }
    return Ls.isRegistered<S>(tag: tag);
  }

  /// Whether type [S] has already been instantiated.
  static bool isInstantiated<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.isInstantiatedIn(Ls.currentScope, tag: tag);
    }
    return Ls.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  /// If [force] is true, deletes even if the dependency was marked as `permanent`.
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({dynamic key, String? tag, bool force = false}) {
    if (key is LevitStore) {
      return key.deleteIn(Ls.currentScope, tag: tag, force: force);
    }
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// If [force] is true, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    Ls.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// Child scopes can override parent dependencies and provide their own
  /// isolated lifecycle. The [name] is used for profiling and logs.
  static LevitScope createScope(String name) {
    return Ls.createScope(name);
  }

  // -------------------------------------------------------------
  //    Middleware accessors
  // -------------------------------------------------------------

  /// The total number of dependencies registered in the current active scope.
  static int get registeredCount => Ls.registeredCount;

  /// A list of all registration keys (type + tag) in the current active scope.
  static List<String> get registeredKeys => Ls.registeredKeys;

  /// Adds a global middleware for receiving dependency injection events.
  static void addDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.addMiddleware(middleware);
  }

  /// Removes a DI middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.removeMiddleware(middleware);
  }

  /// Adds a middleware to the list of active middlewares.
  static void addStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.addMiddleware(middleware);
  }

  /// Removes a middleware from the list of active middlewares.
  static void removeStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.removeMiddleware(middleware);
  }

  // -------------------------------------------------------------
  //   Auto-Linking
  // -------------------------------------------------------------

  /// Enables the "Auto-Linking" feature.
  ///
  /// When enabled, any [LxReactive] variable created inside a [Levit.put] builder or
  /// [LevitController.onInit] is automatically registered for cleanup with
  /// its parent controller.
  ///
  /// This ensures that transient state created within business logic components
  /// is deterministically cleaned up without manual tracking.
  static void enableAutoLinking() {
    Lx.addMiddleware(_AutoLinkMiddleware());
    LevitScope.addMiddleware(_AutoDisposeMiddleware());
  }

  /// Disables the "Auto-Linking" feature.
  static void disableAutoLinking() {
    Lx.removeMiddleware(_AutoLinkMiddleware());
    LevitScope.removeMiddleware(_AutoDisposeMiddleware());
  }

// -------------------------------------------------------------
//    Internal utils
// -------------------------------------------------------------

  /// Internal utility that detects and executes the appropriate cleanup method for an [item].
  static void _levitDisposeItem(dynamic item) {
    if (item == null) return;

    // 1. Framework Specifics (Priority)

    if (item is LxReactive) {
      item.close();
      return;
    }

    if (item is LevitScopeDisposable) {
      item.onClose();
      return;
    }

    if (item is LevitDisposable) {
      item.dispose();
      return;
    }

    // 2. The "Cancel" Group (Async tasks)
    // Most common: StreamSubscription, Timer
    if (item is StreamSubscription) {
      item.cancel();
      return;
    }
    if (item is Timer) {
      item.cancel();
      return;
    }

    try {
      // Duck typing for other cancelables (like CancelableOperation)
      (item as dynamic).cancel();
      return;
    } on NoSuchMethodError {
      // Not cancelable, fall through
    } on Exception catch (e) {
      // Prevent crash during cleanup (only for Exceptions)
      dev.log('Levit: Error cancelling ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 3. The "Dispose" Group (Flutter Controllers)
    // Most common: TextEditingController, ChangeNotifier, FocusNode
    try {
      (item as dynamic).dispose();
      return;
    } on NoSuchMethodError {
      // Not disposable, fall through
    } on Exception catch (e) {
      dev.log('Levit: Error disposing ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 4. The "Close" Group (Sinks, BLoCs, IO)
    // Most common: StreamController, Sink, Bloc
    if (item is Sink) {
      item.close();
      return;
    }

    try {
      (item as dynamic).close();
      return;
    } on NoSuchMethodError {
      // Not closeable, fall through
    } on Exception catch (e) {
      dev.log('Levit: Error closing ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 5. The "Callable" Group (Cleanup Callbacks)
    if (item is void Function()) {
      try {
        item();
      } catch (e) {
        dev.log('Levit: Error executing dispose callback',
            error: e, name: 'levit_dart');
      }
      return;
    }
  }
}

/// Fluent API for naming reactive variables.
extension LxNamingExtension<R extends LxReactive> on R {
  /// Sets the debug name of this reactive object and returns it.
  ///
  /// Useful for chaining:
  /// ```dart
  /// final count = 0.lx.named('count');
  /// ```
  R named(String name) {
    this.name = name;
    return this;
  }

  /// Registers this reactive object with an owner (fluent API).
  R register(String ownerId) {
    this.ownerId = ownerId;

    return this;
  }

  /// Marks this reactive object as sensitive (fluent API).
  R sensitive() {
    this.isSensitive = true;
    return this;
  }
}

/// Interface for objects that can be disposed of.
///
/// Use for complex logic that can be use inside LevitController or LevitStore
/// and have resources to dispose when the container is disposed.
///
abstract class LevitDisposable {
  void dispose();
}
