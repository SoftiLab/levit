import 'dart:async';

import 'core.dart';

/// A synchronous computed reactive value that tracks dependencies automatically.
///
/// Computed values are memoized and lazy. They only re-evaluate when their
/// dependencies change and they are being listened to.
///
/// Use [LxComputed] to derive state from other reactive variables without
/// manually managing subscriptions.
///
/// ## Usage
/// ```dart
/// final count = 0.lx;
/// final doubled = LxComputed(() => count.value * 2);
/// ```
abstract class LxComputed<T> implements LxReactive<T> {
  /// Creates a synchronous computed value.
  ///
  /// *   [compute]: The function to calculate the value.
  /// *   [equals]: Optional comparison function to determine if the value has changed.
  factory LxComputed(
    T Function() compute, {
    bool Function(T previous, T current)? equals,
  }) {
    return _SyncComputed<T>(compute, equals: equals);
  }

  /// Creates an asynchronous computed value.
  ///
  /// *   [compute]: The async function to calculate the value.
  /// *   [showWaiting]: If `true`, the status transitions to [AsyncWaiting]
  ///     during recomputations. Defaults to `false` (stale-while-revalidate).
  /// *   [initial]: Optional initial value.
  static LxAsyncComputed<T> async<T>(
    Future<T> Function() compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    T? initial,
  }) {
    return _AsyncComputed<T>(
      compute,
      equals: equals,
      showWaiting: showWaiting,
      initial: initial,
    );
  }

  /// Manually triggers a re-evaluation.
  void refresh();

  /// Closes the computed value, releasing subscriptions.
  ///
  /// This must be called when the computed value is no longer needed
  /// to prevent memory leaks from dependency subscriptions.
  @override
  void close();

  /// Whether there are active listeners.
  bool get hasListener;
}

/// An asynchronous computed reactive value.
///
/// Wraps the result in an [AsyncStatus]. Like [LxComputed], it tracks
/// dependencies automatically, even across async gaps.
///
/// ## Usage
/// ```dart
/// final userId = 1.lx;
/// final user = LxComputed.async(() => fetchUser(userId.value));
/// ```
abstract class LxAsyncComputed<T> implements LxReactive<AsyncStatus<T>> {
  /// Base constructor for async computed values.
  const LxAsyncComputed();

  /// The current status of the computation.
  AsyncStatus<T> get status;

  /// Whether there are active listeners.
  bool get hasListener;

  /// Manually triggers a re-evaluation.
  void refresh();

  /// Closes the computed value, releasing subscriptions.
  ///
  /// This must be called when the computed value is no longer needed.
  @override
  void close();
}

// =============================================================================
// Implementation
// =============================================================================

/// Shared base for computed implementations.
abstract class _ComputedBase<Val> {
  late final Lx<Val> _statusLx;
  final Map<Object, StreamSubscription?> _dependencySubscriptions = {};

  bool _isActive = false;
  bool _isClosed = false;

  _ComputedBase(Val initialValue) {
    _statusLx = Lx<Val>(
      initialValue,
      onListen: _onActive,
      onCancel: _onInactive,
    );
  }

  /// Called when the computed value gains its first listener.
  void _onActive();

  /// Called when the computed value loses all listeners.
  void _onInactive();

  /// Callback for dependency notifications.
  void _onDependencyChanged();

  // ---------------------------------------------------------------------------
  // Dependency Management
  // ---------------------------------------------------------------------------

  /// Clears all existing subscriptions and tracking.
  void _cleanupSubscriptions() {
    for (final sub in _dependencySubscriptions.values) {
      sub?.cancel();
    }
    for (final dep in _dependencySubscriptions.keys) {
      if (dep is LxNotifier) {
        dep.removeListener(_onDependencyChanged);
      }
    }
    _dependencySubscriptions.clear();
  }

  /// Subscribes to a specific dependency if not already tracked.
  bool _subscribeTo(Object dependency) {
    if (_dependencySubscriptions.containsKey(dependency)) return false;

    if (dependency is Stream) {
      final sub = dependency.listen((_) => _onDependencyChanged());
      _dependencySubscriptions[dependency] = sub;
    } else if (dependency is LxNotifier) {
      dependency.addListener(_onDependencyChanged);
      _dependencySubscriptions[dependency] = null;
    }
    return true;
  }

  /// Unsubscribes from a specific dependency.
  void _unsubscribeFrom(Object dependency) {
    final sub = _dependencySubscriptions.remove(dependency);
    if (sub != null) {
      sub.cancel();
    } else if (dependency is LxNotifier) {
      dependency.removeListener(_onDependencyChanged);
    }
  }

  /// Reconciles dependencies for sync computed.
  void _reconcileDependencies(Set<Object> newDependencies) {
    // 1. Identify Removed
    final currentDeps = _dependencySubscriptions.keys.toList(growable: false);
    for (final dep in currentDeps) {
      if (!newDependencies.contains(dep)) {
        _unsubscribeFrom(dep);
      }
    }

    // 2. Identify Added
    for (final dep in newDependencies) {
      if (!_dependencySubscriptions.containsKey(dep)) {
        _subscribeTo(dep);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive API
  // ---------------------------------------------------------------------------

  Val get value => _statusLx.value;

  Stream<Val> get stream => _statusLx.stream;

  bool get hasListener => _statusLx.hasListener;

  // ---------------------------------------------------------------------------
  // Listener API
  // ---------------------------------------------------------------------------

  void addListener(void Function() listener) => _statusLx.addListener(listener);

  void removeListener(void Function() listener) =>
      _statusLx.removeListener(listener);

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _cleanupSubscriptions();
    _statusLx.close();
  }
}

// =============================================================================
// Sync Computed
// =============================================================================

class _SyncComputed<T> extends _ComputedBase<T> implements LxComputed<T> {
  final T Function() _compute;
  final bool Function(T previous, T current) _equals;
  bool _isDirty = true;
  bool _isComputing = false;

  @override
  Map<String, dynamic> flags = {};

  _SyncComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
  })  : _equals = equals ?? ((a, b) => a == b),
        super(_compute()); // Seed initial value via immediate compute

  @override
  void _onActive() {
    _isActive = true;
    _isDirty = true;
    // Initial tracking setup
    _cleanupSubscriptions();
    _recompute(isInitial: true);
  }

  @override
  void _onInactive() {
    _isActive = false;
    _isDirty = true;
    _cleanupSubscriptions();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || !_isActive) return;
    if (!_isDirty && !_isComputing) {
      _isDirty = true;
      _recompute(isInitial: false);
    }
  }

  void _recompute({required bool isInitial}) {
    if (_isClosed || !_isActive || _isComputing) return;

    final tracker = _DependencyTracker();
    final previousProxy = Lx.proxy;
    Lx.proxy = tracker;
    _isComputing = true;

    T result;
    bool success = false;

    try {
      result = _compute();
      success = true;
    } catch (e) {
      // Propagation stopped by error
      rethrow;
    } finally {
      Lx.proxy = previousProxy;
      _isComputing = false;
    }

    if (success) {
      if (isInitial || !_equals(_statusLx.value, result)) {
        _statusLx.value = result;
      }
      _isDirty = false;
    }

    // Capture dependencies from tracker
    _reconcileDependencies(tracker.dependencies);
  }

  void _ensureFresh() {
    if (_isDirty && !_isComputing) {
      _recompute(isInitial: false);
    }
  }

  @override
  T get value {
    if (_isActive) {
      _ensureFresh();
      return _statusLx.value;
    }

    // Pull-on-read mode
    try {
      return _compute();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void refresh() {
    _isDirty = true;
    if (_isActive && !_isComputing) {
      _ensureFresh();
    }
  }

  @override
  String toString() => 'LxComputed($value)';

  @override
  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

// =============================================================================
// Async Computed
// =============================================================================

class _AsyncComputed<T> extends _ComputedBase<AsyncStatus<T>>
    implements LxAsyncComputed<T> {
  final Future<T> Function() _compute;
  final bool Function(T previous, T current) _equals;
  final bool _showWaiting;

  T? _lastComputedValue;
  bool _hasValue = false;
  int _executionId = 0;
  bool _hasProducedResult = false;

  @override
  Map<String, dynamic> flags = {};

  _AsyncComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    T? initial,
  })  : _equals = equals ?? ((a, b) => a == b),
        _showWaiting = showWaiting,
        _lastComputedValue = initial,
        _hasValue = initial != null,
        super(initial != null ? AsyncSuccess<T>(initial) : AsyncWaiting<T>());

  @override
  void _onActive() {
    _isActive = true;
    _run();
  }

  @override
  void _onInactive() {
    _isActive = false;
    _executionId++; // Cancel pending
    _cleanupSubscriptions();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || !_isActive) return;
    _run();
  }

  void _run() {
    if (_isClosed || !_isActive) return;

    final myExecutionId = ++_executionId;
    final lastKnown = _statusLx.value.lastValue;
    final isInitial = !_hasProducedResult;

    // Async strategy: Clean immediately, subscribe as we go (via Live Tracker).
    _cleanupSubscriptions();

    if (_showWaiting || isInitial) {
      _statusLx.value = AsyncWaiting<T>(lastKnown);
    }

    final tracker = _AsyncLiveTracker(this, myExecutionId);
    final previousProxy = Lx.proxy;
    Lx.proxy = tracker;

    Future<T>? future;
    Object? syncError;
    StackTrace? syncStack;
    bool syncFailed = false;

    // Execute with Zone to capture async dependencies
    try {
      future = runZoned(
        () => _compute(),
        zoneValues: {Lx.trackerZoneKey: tracker},
        zoneSpecification: _asyncZoneSpec(),
      );
    } catch (e, st) {
      syncError = e;
      syncStack = st;
      syncFailed = true;
    } finally {
      Lx.proxy = previousProxy;
    }

    // Handle Synchronous Error
    if (syncFailed) {
      if (myExecutionId == _executionId) {
        _hasProducedResult = true;
        _statusLx.value = AsyncError<T>(syncError!, syncStack!, lastKnown);
      }
      return;
    }

    // Handle Future Result
    if (future != null) {
      future.then((result) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          _applyResult(result, isInitial: isInitial);
        }
      }).catchError((e, st) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          _statusLx.value = AsyncError<T>(e, st, lastKnown);
        }
      });
    }
  }

  void _applyResult(T result, {required bool isInitial}) {
    if (!isInitial && _hasValue && _equals(_lastComputedValue as T, result)) {
      // Value unchanged.
      // If we were waiting, flip to Success with same value.
      if (_statusLx.value is AsyncWaiting<T>) {
        _statusLx.value = AsyncSuccess<T>(result);
      }
      return;
    }

    _lastComputedValue = result;
    _hasValue = true;
    _statusLx.value = AsyncSuccess<T>(result);
  }

  @override
  AsyncStatus<T> get status => _statusLx.value;

  @override
  void refresh() => _run();

  @override
  String toString() => 'LxComputed.async($status)';

  @override
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<AsyncStatus<T>> stream) transformer) {
    return LxStream<R>(transformer(_statusLx.stream));
  }
}

// =============================================================================
// Helper Classes
// =============================================================================

/// Captures all dependencies into a set (for Sync Computed).
class _DependencyTracker implements LxObserver {
  final Set<Object> dependencies = {};

  @override
  void addStream<T>(Stream<T> stream) => dependencies.add(stream);

  @override
  void addNotifier(LxNotifier notifier) => dependencies.add(notifier);
}

/// Immediately subscribes to dependencies (for Async Computed).
class _AsyncLiveTracker implements LxObserver {
  final _AsyncComputed _computed;
  final int _executionId;

  _AsyncLiveTracker(this._computed, this._executionId);

  bool get _isCurrent => _computed._executionId == _executionId;

  @override
  void addStream<T>(Stream<T> stream) {
    if (_isCurrent) _computed._subscribeTo(stream);
  }

  @override
  void addNotifier(LxNotifier notifier) {
    if (_isCurrent) _computed._subscribeTo(notifier);
  }
}

/// Zone Specification for Async Tracking (reduced boilerplate).
ZoneSpecification _asyncZoneSpec() {
  return ZoneSpecification(
    run: <R>(self, parent, zone, f) {
      Lx.enterAsyncScope();
      try {
        return parent.run(zone, f);
      } finally {
        Lx.exitAsyncScope();
      }
    },
    runUnary: <R, T>(self, parent, zone, f, arg) {
      Lx.enterAsyncScope();
      try {
        return parent.runUnary(zone, f, arg);
      } finally {
        Lx.exitAsyncScope();
      }
    },
    runBinary: <R, T1, T2>(self, parent, zone, f, arg1, arg2) {
      Lx.enterAsyncScope();
      try {
        return parent.runBinary(zone, f, arg1, arg2);
      } finally {
        Lx.exitAsyncScope();
      }
    },
    registerCallback: <R>(self, parent, zone, f) {
      final wrapped = parent.registerCallback(zone, f);
      return () {
        Lx.enterAsyncScope();
        try {
          return wrapped();
        } finally {
          Lx.exitAsyncScope();
        }
      };
    },
    registerUnaryCallback: <R, T>(self, parent, zone, f) {
      final wrapped = parent.registerUnaryCallback(zone, f);
      return (arg) {
        Lx.enterAsyncScope();
        try {
          return wrapped(arg);
        } finally {
          Lx.exitAsyncScope();
        }
      };
    },
    registerBinaryCallback: <R, T1, T2>(self, parent, zone, f) {
      final wrapped = parent.registerBinaryCallback(zone, f);
      return (arg1, arg2) {
        Lx.enterAsyncScope();
        try {
          return wrapped(arg1, arg2);
        } finally {
          Lx.exitAsyncScope();
        }
      };
    },
    scheduleMicrotask: (self, parent, zone, f) {
      parent.scheduleMicrotask(zone, () {
        Lx.enterAsyncScope();
        try {
          f();
        } finally {
          Lx.exitAsyncScope();
        }
      });
    },
  );
}

// =============================================================================
// Extensions
// =============================================================================

/// Extension to create [LxComputed] from a synchronous function.
extension LxFunctionExtension<T> on T Function() {
  /// Transforms this function into a [LxComputed] value.
  ///
  /// ```dart
  /// final count = 0.lx;
  /// final doubled = (() => count.value * 2).lx;
  /// ```
  LxComputed<T> get lx => LxComputed<T>(this);
}

/// Extension to create [LxAsyncComputed] from an asynchronous function.
extension LxAsyncFunctionExtension<T> on Future<T> Function() {
  /// Transforms this async function into a [LxAsyncComputed] value.
  ///
  /// ```dart
  /// final userId = 1.lx;
  /// final user = (() => fetchUser(userId.value)).lx;
  /// ```
  LxAsyncComputed<T> get lx => LxComputed.async<T>(this);
}
