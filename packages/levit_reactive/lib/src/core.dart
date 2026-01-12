import 'dart:async';

// ============================================================================
// Global Reactive Configuration
// ============================================================================

/// An observer that tracks reactive dependencies during execution.
///
/// Implemented by [LWatch] and computed values to automatically detect
/// which [Lx] variables are accessed.
///
/// This mechanism allows Levit to implement "Observation by Access," where
/// components simply use values and the framework handles subscriptions.
abstract class LxObserver {
  /// Registers a [stream] dependency.
  void addStream<T>(Stream<T> stream);

  /// Registers a [notifier] dependency.
  void addNotifier(LxNotifier notifier);
}

/// Common interface for all reactive types.
///
/// Unifies [Lx], [LxFuture], and [LxStream] so they can be used interchangeably
/// with utilities like [watch].
///
/// This interface ensures that any reactive source can be observed, streamed,
/// and listened to in a consistent manner.
abstract interface class LxReactive<T> {
  /// Metadata flags for debugging and middleware.
  ///
  /// Can contain keys like `name` for identification in logs.
  abstract Map<String, dynamic> flags;

  /// The current value.
  ///
  /// Reading this registers the variable with the active [LxObserver].
  T get value;

  /// A stream of value changes.
  Stream<T> get stream;

  /// Adds a listener for value changes.
  ///
  /// [listener] will be invoked whenever [value] updates.
  void addListener(void Function() listener);

  /// Removes a listener.
  ///
  /// Removes [listener] from the reactive object.
  ///
  /// [listener] will no longer be invoked on updates.
  void removeListener(void Function() listener);

  /// Transforms the underlying stream using a standard [StreamTransformer]
  /// or a transformer function (like those from RxDart).
  ///
  /// Returns a new [LxStream] that tracks the lifecycle and status of the
  /// transformed stream.
  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer);

  /// Closes the reactive object and releases resources.
  ///
  /// Should be called when the object is no longer needed to prevent memory leaks.
  void close();
}

/// A specialized notifier for synchronous reactive updates.
///
/// Used internally to propagate changes without [StreamController] overhead.
/// It implements a propagation queue to handle complex dependency chains efficiently.
class LxNotifier {
  Set<void Function()>? _listeners = {};
  bool _disposed = false;

  /// Creates a new notifier.
  LxNotifier();

  /// Adds a listener.
  ///
  /// The [listener] is added to the set of callbacks invoked on notification.
  void addListener(void Function() listener) {
    if (_disposed) return;
    _listeners?.add(listener);
  }

  /// Removes a listener.
  ///
  /// The [listener] is removed from the callback set.
  void removeListener(void Function() listener) {
    _listeners?.remove(listener);
  }

  /// Notifies all listeners of a change.
  ///
  /// Handles batching and propagation cycles automatically to ensure consistency
  /// and performance during complex state updates.
  void notify() {
    if (_disposed || _listeners == null || _listeners!.isEmpty) return;

    // 0. Handle Async Batching
    final asyncBatch = Zone.current[Lx._batchZoneKey];
    if (asyncBatch is Set<LxNotifier>) {
      asyncBatch.add(this);
      return;
    }

    // 1. Handle Sync Batching
    if (Lx.isBatching) {
      Lx._batchedNotifiers.add(this);
      return;
    }

    // 2. Handle Iterative Propagation (Queueing)
    if (Lx._isPropagating) {
      Lx._propagationQueue.add(this);
      return;
    }

    // 3. Start Propagation Cycle
    Lx._isPropagating = true;
    try {
      _notifyListeners();

      if (Lx._propagationQueue.isNotEmpty) {
        var i = 0;
        while (i < Lx._propagationQueue.length) {
          final notifier = Lx._propagationQueue[i++];
          notifier._notifyListeners();
        }
      }
    } finally {
      Lx._isPropagating = false;
      if (Lx._propagationQueue.isNotEmpty) {
        Lx._propagationQueue.clear();
      }
    }
  }

  void _notifyListeners() {
    final listeners = _listeners;
    if (listeners == null || listeners.isEmpty) return;

    // Optimization for single listener (common case)
    if (listeners.length == 1) {
      listeners.first();
      return;
    }

    // Create a snapshot to allow adding/removing listeners during notification
    // without breaking the loop or causing ConcurrentModificationError.
    final snapshot = listeners.toList(growable: false);
    for (final listener in snapshot) {
      if (listeners.contains(listener)) {
        listener();
      }
    }
  }

  /// Disposes the notifier.
  ///
  /// Clears all listeners and marks the notifier as disposed.
  void dispose() {
    _disposed = true;
    _listeners = null;
  }

  /// Whether the notifier is disposed.
  bool get isDisposed => _disposed;

  /// Whether there are active listeners.
  bool get hasListener => _listeners != null && _listeners!.isNotEmpty;
}

// ============================================================================
// Lx<T> - The Core Reactive Primitive
// ============================================================================

/// A reactive wrapper for a value of type [T].
///
/// [Lx] is the core primitive of Levit's reactive system. It notifies
/// listeners whenever its value changes.
///
/// It supports:
/// *   **Observation**: Automatically tracked by [LxObserver].
/// *   **Stream Binding**: Can bind to external [Stream]s via [bind].
/// *   **Middleware**: Supports interceptors for logging and state history.
///
/// ## Usage
/// ```dart
/// final count = Lx<int>(0);
/// // or
/// final count = 0.lx;
///
/// count.value++; // Notifies observers
/// ```
class Lx<T> implements LxReactive<T> {
  T _value;
  StreamController<T>? _controller;
  final LxNotifier _notifier = LxNotifier();

  Stream<T>? _boundStream;
  int _externalListeners = 0;
  StreamSubscription<T>? _activeBoundSubscription;

  @override
  Map<String, dynamic> flags;

  /// Called when the stream is listened to.
  final void Function()? onListen;

  /// Called when the stream is cancelled.
  final void Function()? onCancel;

  bool _isActive = false;

  /// Creates a reactive wrapper around [initial].
  ///
  /// Optional [onListen] and [onCancel] callbacks hook into the subscription lifecycle.
  Lx(T initial, {this.onListen, this.onCancel})
      : _value = initial,
        flags = {};

  void _checkActive() {
    final shouldBeActive = hasListener;
    if (shouldBeActive && !_isActive) {
      _isActive = true;
      onListen?.call();
    } else if (!shouldBeActive && _isActive) {
      _isActive = false;
      onCancel?.call();
    }
  }

  // ==========================================================================
  // Static API - Configuration, Proxy, Batching
  // ==========================================================================

  /// The active observer capturing dependencies.
  static LxObserver? proxy;

  /// Global middlewares for intercepting state changes.
  static final List<LxMiddleware> middlewares = [];

  /// Adds a middleware with an optional filter.
  ///
  /// Returns the added [middleware].
  /// [filter] can be used to selectively apply the middleware to specific changes.
  static LxMiddleware addMiddleware(LxMiddleware middleware,
      {bool Function(StateChange change)? filter}) {
    if (filter != null) {
      middleware.filter = filter;
    }
    middlewares.add(middleware);
    return middleware;
  }

  /// Whether to capture stack traces on state changes (expensive).
  static bool captureStackTrace = false;

  /// Maximum history size for [LxHistoryMiddleware].
  static int maxHistorySize = 100;

  /// Internal zone key for async tracking.
  static final Object trackerZoneKey = Object();

  /// Internal zone key for async batching.
  static final Object _batchZoneKey = Object();

  static int _asyncZoneDepth = 0;

  /// Internal: Enters async tracking scope.
  static void enterAsyncScope() {
    _asyncZoneDepth++;
  }

  /// Internal: Exits async tracking scope.
  static void exitAsyncScope() {
    _asyncZoneDepth--;
  }

  static final List<LxNotifier> _propagationQueue = [];
  static bool _isPropagating = false;

  static int _batchDepth = 0;
  static final Set<LxNotifier> _batchedNotifiers = {};

  /// Whether a batch operation is in progress.
  static bool get isBatching => _batchDepth > 0;

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications are deferred until the batch completes. This prevents
  /// multiple rebuilds when updating multiple reactive variables at once.
  ///
  /// ```dart
  /// Lx.batch(() {
  ///   count.value++;
  ///   name.value = 'New';
  /// }); // Single update cycle
  /// ```
  static R batch<R>(R Function() callback) {
    _batchDepth++;
    if (_batchDepth == 1) {
      for (final mw in middlewares) {
        mw.onBatchStart();
      }
    }

    try {
      return callback();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0) {
        for (final mw in middlewares) {
          mw.onBatchEnd();
        }
        _flushGlobalBatch();
      }
    }
  }

  static void _flushGlobalBatch() {
    if (_batchedNotifiers.isEmpty) return;
    final notifiers = List<LxNotifier>.from(_batchedNotifiers);
    _batchedNotifiers.clear();
    for (final notifier in notifiers) {
      notifier.notify();
    }
  }

  /// Executes [callback] in an asynchronous batch.
  ///
  /// Notifications are deferred until the future returned by [callback] completes.
  /// Useful for async operations that perform multiple updates.
  static Future<R> batchAsync<R>(Future<R> Function() callback) async {
    _batchDepth++;
    if (_batchDepth == 1) {
      for (final mw in middlewares) mw.onBatchStart();
    }

    enterAsyncScope();

    final batchSet = <LxNotifier>{};
    try {
      return await runZoned(() => callback(),
          zoneValues: {_batchZoneKey: batchSet});
    } finally {
      exitAsyncScope();

      _batchDepth--;
      if (_batchDepth == 0) {
        for (final mw in middlewares) mw.onBatchEnd();
        _flushGlobalBatch();
      }

      for (final notifier in batchSet) {
        notifier.notify();
      }
    }
  }

  static bool _bypassMiddleware = false;

  /// Executes [action] without triggering middlewares.
  ///
  /// Useful for internal updates or restoring state without polluting the history.
  static void runWithoutMiddleware(void Function() action) {
    final prev = _bypassMiddleware;
    _bypassMiddleware = true;
    try {
      action();
    } finally {
      _bypassMiddleware = prev;
    }
  }

  // ==========================================================================
  // Instance API
  // ==========================================================================

  @override
  T get value {
    if (proxy != null) {
      _reportRead(proxy!);
    } else if (_asyncZoneDepth > 0) {
      final zoneTracker = Zone.current[trackerZoneKey];
      if (zoneTracker is LxObserver) {
        _reportRead(zoneTracker);
      }
    }
    return _value;
  }

  void _reportRead(LxObserver observer) {
    observer.addNotifier(_notifier);
    if (_controller != null || _boundStream != null) {
      observer.addStream(stream);
    }
  }

  set value(T val) {
    if (_value == val) return;

    final mws = middlewares;
    final oldValue = _value;

    if (Lx._bypassMiddleware || mws.isEmpty) {
      _value = val;
      _controller?.add(_value);
      _notifier.notify();
      return;
    }

    final change = StateChange<T>(
      timestamp: DateTime.now(),
      name: flags['name'] as String?,
      valueType: T,
      oldValue: oldValue,
      newValue: val,
      stackTrace: captureStackTrace ? StackTrace.current : null,
      restore: (v) {
        _value = v;
        _controller?.add(_value);
        _notifier.notify();
      },
    );

    for (final mw in mws) {
      if (!mw.shouldProcess(change)) continue;
      if (!mw.onBeforeChange(change)) {
        return;
      }
      if (change.isPropagationStopped) break;
    }

    _value = val;
    _controller?.add(_value);
    _notifier.notify();

    for (final mw in mws) {
      if (!mw.shouldProcess(change)) continue;
      mw.onAfterChange(change);
      if (change.isPropagationStopped) break;
    }
  }

  @override
  Stream<T> get stream {
    if (_boundStream != null) return _boundStream!;
    _controller ??= StreamController<T>.broadcast(
        onListen: () => _checkActive(), onCancel: () => _checkActive());
    return _controller!.stream;
  }

  /// Whether there are active listeners.
  bool get hasListener =>
      (_controller?.hasListener ?? false) ||
      _notifier.hasListener ||
      _externalListeners > 0;

  /// Binds an external stream to this reactive variable.
  ///
  /// Events from the [externalStream] will update the value and notify listeners.
  /// Useful for bridging [Lx] with other stream-based APIs.
  void bind(Stream<T> externalStream) {
    if (_boundStream != null && _boundStream == externalStream) return;

    unbind();

    _boundStream = externalStream.map((event) {
      _value = event;
      _controller?.add(event);
      _notifier.notify();
      return event;
    }).transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, st, sink) {
          _controller?.addError(error, st);
          sink.addError(error, st);
        },
      ),
    ).asBroadcastStream(
      onListen: (sub) {
        _externalListeners++;
        _checkActive();
      },
      onCancel: (subscription) {
        _externalListeners--;
        _checkActive();
        subscription.cancel();
      },
    );

    if (hasListener) {
      _activeBoundSubscription = _boundStream!.listen((_) {});
    }
  }

  /// Unbinds any external stream.
  ///
  /// Stops updates from the external stream and cleans up subscriptions.
  void unbind() {
    _activeBoundSubscription?.cancel();
    _activeBoundSubscription = null;
    _boundStream = null;
    _externalListeners = 0;
    _checkActive();
  }

  @override
  void close() {
    _controller?.close();
    _notifier.dispose();
    _checkActive();
  }

  /// Functional update: sets value if argument provided, returns value.
  ///
  /// [v] is the optional new value.
  T call([T? v]) {
    if (v is T) {
      value = v;
    }
    return value;
  }

  /// Triggers a notification without changing the value.
  ///
  /// Useful for mutable objects (e.g., lists) where the reference hasn't changed
  /// but internal content has.
  void refresh() {
    _controller?.add(_value);
    _notifier.notify();
  }

  /// Alias for [refresh].
  void notify() => refresh();

  /// Mutates the value in place and triggers a refresh.
  ///
  /// [mutator] is a function that modifies the current value.
  ///
  /// ```dart
  /// list.mutate((l) => l.add(item));
  /// ```
  void mutate(void Function(T value) mutator) {
    mutator(_value);
    refresh();
  }

  @override
  void addListener(void Function() listener) {
    _notifier.addListener(listener);
    _checkActive();

    if (_isActive && _boundStream != null && _activeBoundSubscription == null) {
      _activeBoundSubscription = _boundStream!.listen((_) {});
    }
  }

  @override
  void removeListener(void Function() listener) {
    _notifier.removeListener(listener);
    _checkActive();

    if (!hasListener) {
      _activeBoundSubscription?.cancel();
      _activeBoundSubscription = null;
    }
  }

  /// Updates the value using a transformation function.
  ///
  /// [fn] receives the current value and returns the new value.
  void updateValue(T Function(T val) fn) {
    value = fn(_value);
  }

  @override
  String toString() => _value.toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Lx<T>) return _value == other._value;
    if (other is T) return _value == other;
    return false;
  }

  @override
  int get hashCode => _value.hashCode;

  @override
  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

// ============================================================================
// AsyncStatus - Async Status Types
// ============================================================================

/// Sealed class representing the state of an asynchronous operation.
///
/// Used by [LxFuture] and [LxStream] to track loading, success, and error states.
sealed class AsyncStatus<T> {
  /// The last known successful value.
  ///
  /// Persists across loading and error states to allow "optimistic UI" patterns.
  final T? lastValue;

  const AsyncStatus(this.lastValue);

  /// Whether the status is [AsyncWaiting].
  bool get isLoading => this is AsyncWaiting<T>;

  /// Whether the status is [AsyncSuccess].
  bool get hasValue => this is AsyncSuccess<T>;

  /// Whether the status is [AsyncError].
  bool get hasError => this is AsyncError<T>;

  /// Returns the value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
        AsyncSuccess<T>(:final value) => value,
        _ => null,
      };

  /// Returns the error if failed, otherwise `null`.
  Object? get errorOrNull => switch (this) {
        AsyncError<T>(:final error) => error,
        _ => null,
      };

  /// Returns the stack trace if failed, otherwise `null`.
  StackTrace? get stackTraceOrNull => switch (this) {
        AsyncError<T>(:final stackTrace) => stackTrace,
        _ => null,
      };
}

/// Status: Idle (not started).
///
/// Represents the initial state before an operation begins.
final class AsyncIdle<T> extends AsyncStatus<T> {
  /// Creates an idle status, optionally with a [lastValue].
  const AsyncIdle([super.lastValue]);

  @override
  String toString() => 'AsyncIdle<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is AsyncIdle<T> && other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue);
}

/// Status: Waiting (loading/executing).
///
/// Represents an ongoing asynchronous operation.
final class AsyncWaiting<T> extends AsyncStatus<T> {
  /// Optional progress (0.0 to 1.0).
  final double? progress;

  /// Creates a waiting status.
  const AsyncWaiting([super.lastValue, this.progress]);

  @override
  String toString() =>
      'AsyncWaiting<$T>(lastValue: $lastValue, progress: $progress)';

  @override
  bool operator ==(Object other) =>
      other is AsyncWaiting<T> &&
      other.lastValue == lastValue &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue, progress);
}

/// Status: Success (completed with value).
///
/// Represents a successfully completed operation.
final class AsyncSuccess<T> extends AsyncStatus<T> {
  /// The successful value.
  final T value;

  /// Creates a success status.
  const AsyncSuccess(this.value) : super(value);

  @override
  String toString() => 'AsyncSuccess<$T>($value)';

  @override
  bool operator ==(Object other) =>
      other is AsyncSuccess<T> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Status: Error (failed).
///
/// Represents a failed operation.
final class AsyncError<T> extends AsyncStatus<T> {
  /// The error object.
  final Object error;

  /// The stack trace.
  final StackTrace? stackTrace;

  /// Creates a new [AsyncError] with the given [error] and optional [stackTrace].
  const AsyncError(this.error, [this.stackTrace, T? lastValue])
      : super(lastValue);

  @override
  String toString() => 'AsyncError<$T>($error, lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is AsyncError<T> &&
      other.error == error &&
      other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, error, lastValue);
}

// ============================================================================
// Middleware / Interceptor Pattern for Debugging
// ============================================================================

/// Represents a change in a reactive variable's state.
///
/// Passed to [LxMiddleware] to inspect or modify state changes.
class StateChange<T> {
  /// Time of the change.
  final DateTime timestamp;

  /// Name of the variable (if set via flags).
  final String? name;

  /// Type of the value.
  final Type valueType;

  /// Previous value.
  final T oldValue;

  /// New value.
  final T newValue;

  /// Stack trace (if enabled).
  final StackTrace? stackTrace;

  /// Function to restore this state (for undo).
  final void Function(dynamic value)? restore;

  /// Creates a state change record.
  StateChange({
    required this.timestamp,
    this.name,
    required this.valueType,
    required this.oldValue,
    required this.newValue,
    this.stackTrace,
    this.restore,
  });

  bool _propagationStopped = false;

  /// Stops propagation to subsequent middlewares.
  void stopPropagation() {
    _propagationStopped = true;
  }

  /// Whether propagation is stopped.
  bool get isPropagationStopped => _propagationStopped;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'name': name,
        'valueType': valueType.toString(),
        'oldValue': oldValue.toString(),
        'newValue': newValue.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };

  @override
  String toString() {
    final label = name ?? valueType.toString();
    return '[$timestamp] $label: $oldValue → $newValue';
  }
}

/// A batch of state changes grouped together.
///
/// Used when [Lx.batch] is active.
class CompositeStateChange implements StateChange<void> {
  /// The list of individual changes in this batch.
  final List<StateChange> changes;
  @override
  final DateTime timestamp;

  /// Creates a composite change.
  CompositeStateChange(this.changes) : timestamp = DateTime.now();

  @override
  String? get name => 'Batch(${changes.length})';

  @override
  Type get valueType => CompositeStateChange;

  @override
  void get oldValue => null;

  @override
  void get newValue => null;

  @override
  StackTrace? get stackTrace => null;

  @override
  void Function(dynamic value)? get restore => null;

  @override
  bool _propagationStopped = false;

  @override
  void stopPropagation() {
    _propagationStopped = true;
  }

  @override
  bool get isPropagationStopped => _propagationStopped;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'CompositeChange',
        'timestamp': timestamp.toIso8601String(),
        'changes': changes.map((c) => c.toJson()).toList(),
      };

  @override
  String toString() => '[$timestamp] Batch of ${changes.length} changes';
}

/// Base class for reactive middlewares.
///
/// Middleware can intercept, log, or modify state changes.
abstract class LxMiddleware {
  /// Base constructor for middleware.
  LxMiddleware();

  /// Filter predicate.
  bool Function(StateChange change)? filter;

  /// Checks if the change should be processed.
  bool shouldProcess(StateChange change) => filter?.call(change) ?? true;

  /// Called before a change is applied. Return `false` to veto.
  ///
  /// [change] contains details about the proposed update.
  bool onBeforeChange<T>(StateChange<T> change) => true;

  /// Called after a change is applied.
  ///
  /// [change] contains details about the completed update.
  void onAfterChange<T>(StateChange<T> change);

  /// Called on batch start.
  void onBatchStart() {}

  /// Called on batch end.
  void onBatchEnd() {}
}

// ============================================================================
// AsyncStatus Extensions
// ============================================================================

/// Extensions for reactive async status.
extension LxStatusReactiveExtensions<T> on LxReactive<AsyncStatus<T>> {
  /// Returns the value if success, else `null`.
  T? get valueOrNull => value.valueOrNull;

  /// Returns the error if error, else `null`.
  Object? get errorOrNull => value.errorOrNull;

  /// Returns the stack trace if error, else `null`.
  StackTrace? get stackTraceOrNull => value.stackTraceOrNull;

  /// Whether idle.
  bool get isIdle => value is AsyncIdle<T>;

  /// Whether waiting.
  bool get isWaiting => value is AsyncWaiting<T>;

  /// Whether success.
  bool get isSuccess => value is AsyncSuccess<T>;

  /// Whether error.
  bool get isError => value is AsyncError<T>;

  /// Alias for [isWaiting].
  bool get isLoading => isWaiting;

  /// Alias for [isSuccess].
  bool get hasValue => isSuccess;

  /// Returns the last known value.
  T? get lastValue => value.lastValue;

  /// Returns progress if waiting.
  double? get progress => switch (value) {
        AsyncWaiting<T>(:final progress) => progress,
        AsyncSuccess() => 1.0,
        _ => null,
      };

  /// Returns value if success, throws if error.
  ///
  /// Throws [StateError] if the operation is not yet complete or has no value.
  T get requireValue {
    final s = value;
    if (s is AsyncSuccess<T>) return s.value;
    if (s is AsyncError<T>) throw s.error;
    throw StateError('Async operation has no value yet (status: $s)');
  }

  /// Alias for [requireValue].
  T get computedValue => requireValue;

  /// Returns a future that completes when the operation succeeds or fails.
  ///
  /// If the current state is already success or error, returns immediately.
  /// Otherwise, waits for the next terminal state.
  Future<T> get wait {
    final s = value;
    if (s is AsyncSuccess<T>) return Future.value(s.value);
    if (s is AsyncError<T>) return Future.error(s.error, s.stackTrace);

    final completer = Completer<T>();
    StreamSubscription? sub;
    sub = stream.listen((s) {
      if (s is AsyncSuccess<T>) {
        sub?.cancel();
        completer.complete(s.value);
      } else if (s is AsyncError<T>) {
        sub?.cancel();
        completer.completeError(s.error, s.stackTrace ?? StackTrace.empty);
      }
    });
    return completer.future;
  }
}

// ============================================================================
// LxStream<T>
// ============================================================================

/// A reactive wrapper for a [Stream].
///
/// [LxStream] listens to a stream and tracks its state using [AsyncStatus].
/// It uses lazy subscriptions: the source stream is subscribed to only when
/// the [LxStream] (or its [status]) has active listeners. When all listeners
/// unsubscribe, the source subscription is cancelled.
///
/// Use this class to treat a stream as a reactive variable that can be observed
/// in the UI.
class LxStream<T> implements LxReactive<AsyncStatus<T>> {
  /// Internal reactive status storage.
  final Lx<AsyncStatus<T>> _statusLx;

  /// The bound stream (wrapped for lazy subscription).
  Stream<T>? _boundStream;

  @override
  Map<String, dynamic> flags;

  /// Creates an [LxStream] bound to the given [stream].
  ///
  /// *   [stream]: The source stream.
  /// *   [initial]: An optional initial value.
  LxStream(Stream<T> stream, {T? initial})
      : _statusLx = _initialStatus<T>(initial),
        flags = {} {
    _bind(stream);
  }

  /// Creates an [LxStream] in an [AsyncIdle] state.
  ///
  /// Use [bind] to start listening to a stream later.
  LxStream.idle({T? initial})
      : _statusLx = _initialStatus<T>(initial, idle: true),
        flags = {};

  static Lx<AsyncStatus<T>> _initialStatus<T>(T? initial, {bool idle = false}) {
    if (initial != null) {
      return Lx<AsyncStatus<T>>(AsyncSuccess<T>(initial));
    }
    return Lx<AsyncStatus<T>>(idle ? AsyncIdle<T>() : AsyncWaiting<T>());
  }

  void _bind(Stream<T> stream, {bool isInitial = true}) {
    final lastKnownValue = _statusLx.value.lastValue;

    // Update status to waiting when rebinding (not for initial constructor call with initial value)
    if (!isInitial) {
      _statusLx.value = AsyncWaiting<T>(lastKnownValue);
    }

    // Capture status changes from the stream
    final statusStream = stream
        .transform<AsyncStatus<T>>(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              sink.add(AsyncSuccess<T>(data));
            },
            handleError: (error, stackTrace, sink) {
              sink.add(
                  AsyncError<T>(error, stackTrace, _statusLx.value.lastValue));
            },
          ),
        )
        .asBroadcastStream(
          onCancel: (sub) => sub.cancel(),
        );

    // Bind _statusLx to progress/error updates
    _statusLx.bind(statusStream);

    // Provide the original stream as a lazy broadcast stream
    // We derive from _statusLx.stream to ensure that listening to valueStream
    // also keeps _statusLx updated (single source of truth).
    _boundStream = _statusLx.stream
        .where((s) => s.hasValue)
        .map((s) => s.valueOrNull as T);
  }

  // ---------------------------------------------------------------------------
  // Status Access (reactive - triggers LWatch registration)
  // ---------------------------------------------------------------------------

  /// The current [AsyncStatus] of the stream.
  AsyncStatus<T> get status => _statusLx.value;

  @override
  AsyncStatus<T> get value => _statusLx.value;

  /// A stream of status changes.
  @override
  Stream<AsyncStatus<T>> get stream => _statusLx.stream;

  /// The underlying value stream (unwrapped from status).
  ///
  /// Subscribing to this stream triggers the lazy source subscription.
  Stream<T> get valueStream {
    if (_boundStream == null) {
      throw StateError('No stream bound. Call bind() first.');
    }
    return _boundStream!;
  }

  // ---------------------------------------------------------------------------
  // Convenience Getters
  // ---------------------------------------------------------------------------

  /// Whether there are active subscribers to this status or value stream.
  bool get hasListener => _statusLx.hasListener;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Binds to a new stream, replacing the current one.
  void bind(Stream<T> stream) {
    unbind();
    _bind(stream, isInitial: false);
  }

  /// Unbinds the current stream, stopping subscriptions.
  void unbind() {
    _statusLx.unbind();
    _boundStream = null;
  }

  // ---------------------------------------------------------------------------
  // Listener API
  // ---------------------------------------------------------------------------

  @override
  void addListener(void Function() listener) {
    _statusLx.addListener(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _statusLx.removeListener(listener);
  }

  /// Closes the [LxStream].
  ///
  /// This stops listening to the source stream and releases resources.
  void close() {
    unbind();
    _statusLx.close();
  }

  @override
  String toString() => 'LxStream($status)';

  // ---------------------------------------------------------------------------
  // Transformations
  // ---------------------------------------------------------------------------

  /// Transforms each element of this stream into a new stream event.
  LxStream<R> map<R>(R Function(T event) convert) {
    return LxStream<R>(valueStream.map(convert));
  }

  /// Creates a stream where each data event of this stream is asynchronously mapped
  /// to a new event.
  LxStream<E> asyncMap<E>(FutureOr<E> Function(T event) convert) {
    return LxStream<E>(valueStream.asyncMap(convert));
  }

  /// Transforms each element of this stream into a sequence of elements.
  LxStream<R> expand<R>(Iterable<R> Function(T element) convert) {
    return LxStream<R>(valueStream.expand(convert));
  }

  /// Filters events from this stream.
  LxStream<T> where(bool Function(T event) test) {
    return LxStream<T>(valueStream.where(test));
  }

  /// Skips data events if they are equal to the previous data event.
  LxStream<T> distinct([bool Function(T previous, T next)? equals]) {
    return LxStream<T>(valueStream.distinct(equals));
  }

  // ---------------------------------------------------------------------------
  // Reductions (returning LxFuture)
  // ---------------------------------------------------------------------------

  /// Combines a sequence of values by repeatedly applying [combine].
  LxFuture<T> reduce(T Function(T previous, T element) combine) {
    return LxFuture<T>(valueStream.reduce(combine));
  }

  /// Combines a sequence of values by repeatedly applying [combine], starting
  /// with an [initialValue].
  LxFuture<R> fold<R>(
      R initialValue, R Function(R previous, T element) combine) {
    return LxFuture<R>(valueStream.fold(initialValue, combine));
  }

  @override
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<AsyncStatus<T>> stream) transformer) {
    return LxStream<R>(transformer(this.stream));
  }

// ---------------------------------------------------------------------------
// Transformations (returning LxStream)
// ---------------------------------------------------------------------------
}

/// Extension for creating [LxStream] from a [Stream].
extension LxStreamExtension<T> on Stream<T> {
  /// Wraps this stream in an [LxStream].
  LxStream<T> get lx => LxStream<T>(this);
}

// ============================================================================
// LxFuture<T>
// ============================================================================

/// A reactive wrapper for a [Future].
///
/// [LxFuture] executes a future and tracks its state using [AsyncStatus]
/// (Idle, Waiting, Success, Error). It uses lazy subscriptions: the future
/// is executed immediately, but status updates are only delivered when
/// there are active listeners.
///
/// Use this class to easily display the state of an asynchronous operation in
/// your UI (e.g., showing a loading spinner while fetching data).
class LxFuture<T> implements LxReactive<AsyncStatus<T>> {
  /// Internal reactive status storage.
  final Lx<AsyncStatus<T>> _statusLx;

  @override
  Map<String, dynamic> flags;

  /// Creates an [LxFuture] that immediately executes the given [future].
  ///
  /// *   [future]: The future to execute and track.
  /// *   [initial]: An optional initial value. If provided, the status starts as
  ///     [AsyncSuccess] with this value while the future is loading (useful for
  ///     optimistic UI or cached data).
  LxFuture(Future<T> future, {T? initial})
      : _statusLx = _initialStatus<T>(initial),
        flags = {} {
    _run(future);
  }

  /// Creates an [LxFuture] from a callback that returns a Future.
  ///
  /// This factory executes the callback immediately. It is useful when you want
  /// to defer the creation of the future until the [LxFuture] is instantiated.
  factory LxFuture.from(Future<T> Function() futureCallback, {T? initial}) {
    return LxFuture<T>(futureCallback(), initial: initial);
  }

  /// Creates an [LxFuture] in an [AsyncIdle] state.
  ///
  /// The future is not started until [refresh] is called.
  ///
  /// [initial] is an optional value to hold while idle.
  LxFuture.idle({T? initial})
      : _statusLx = _initialStatus<T>(initial, idle: true),
        flags = {};

  static Lx<AsyncStatus<T>> _initialStatus<T>(T? initial, {bool idle = false}) {
    if (initial != null) {
      return Lx<AsyncStatus<T>>(AsyncSuccess<T>(initial));
    }
    return Lx<AsyncStatus<T>>(idle ? AsyncIdle<T>() : AsyncWaiting<T>());
  }

  /// The internal future currently being tracked.
  Future<T>? _activeFuture;

  void _run(Future<T> future, {bool isRefresh = false}) {
    _activeFuture = future;
    final lastKnownValue = _statusLx.value.lastValue;

    // Always set to waiting on refresh. For initial run, preserve initial success value.
    if (isRefresh || _statusLx.value is! AsyncSuccess<T>) {
      _statusLx.value = AsyncWaiting<T>(lastKnownValue);
    }

    future.then((value) {
      // Only update if this future is still the active one (handle race conditions)
      if (_activeFuture == future) {
        _statusLx.value = AsyncSuccess<T>(value);
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (_activeFuture == future) {
        _statusLx.value = AsyncError<T>(error, stackTrace, lastKnownValue);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Status Access (reactive - triggers LWatch registration)
  // ---------------------------------------------------------------------------

  /// The current [AsyncStatus] of the future.
  ///
  /// Accessing this value from a reactive context (like [LWatch]) will
  /// automatically register this future as a dependency.
  AsyncStatus<T> get status => _statusLx.value;

  /// An alias for [status] required for the [LxReactive] interface.
  @override
  AsyncStatus<T> get value => _statusLx.value;

  /// A stream of status changes.
  ///
  /// The future execution itself is independent of this stream, but status
  /// updates are emitted here.
  @override
  Stream<AsyncStatus<T>> get stream => _statusLx.stream;

  /// Whether there are active subscribers to this future.
  bool get hasListener => _statusLx.hasListener;

  /// Returns a future that completes with the result.
  ///
  /// *   If an operation is currently in progress, returns the future of that operation.
  /// *   If successful, returns a future completing with the current value.
  /// *   If failed, returns a future completing with the error.
  /// *   If idle, throws a [StateError].
  Future<T> get wait {
    if (_activeFuture != null) return _activeFuture!;
    final s = status;
    if (s is AsyncSuccess<T>) return Future.value(s.value);
    if (s is AsyncError<T>) return Future.error(s.error, s.stackTrace);
    if (s is AsyncIdle<T>) {
      throw StateError('LxFuture is idle and has no active future to await.');
    }
    // Should be unreachable as _activeFuture handles Waiting state
    throw StateError('Unexpected state: $s'); // coverage:ignore-line
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Refreshes the state with a new future.
  ///
  /// This sets the status to [AsyncWaiting] and tracks the new [future].
  void refresh(Future<T> future) => _run(future, isRefresh: true);

  // ---------------------------------------------------------------------------
  // Listener API
  // ---------------------------------------------------------------------------

  /// Add a listener that will be called on every status change.
  @override
  void addListener(void Function() listener) {
    _statusLx.addListener(listener);
  }

  /// Remove a previously added listener.
  @override
  void removeListener(void Function() listener) {
    _statusLx.removeListener(listener);
  }

  /// Close and release resources.
  ///
  /// Call this when the [LxFuture] is no longer needed to free resources.
  void close() {
    _statusLx.close();
  }

  @override
  String toString() => 'LxFuture($status)';

  /// Converts this [LxFuture] into an [LxStream].
  ///
  /// The resulting stream will emit a single value (or error) when this future
  /// completes, and then close.
  LxStream<T> get asLxStream => LxStream<T>(wait.asStream());

  @override
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<AsyncStatus<T>> stream) transformer) {
    return LxStream<R>(transformer(_statusLx.stream));
  }
}

/// Extension for creating [LxFuture] from a [Future].
extension LxFutureExtension<T> on Future<T> {
  /// Creates an [LxFuture] from this future.
  ///
  /// ```dart
  /// final user = fetchUser().lx;
  /// ```
  LxFuture<T> get lx => LxFuture<T>(this);
}
