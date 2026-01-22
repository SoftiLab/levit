import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

/// A reactive widget that automatically rebuilds when accessed [LxReactive] values change.
///
/// [LWatch] is the primary bridge between the reactive state in your controllers
/// and the Flutter UI. It uses a "proxy-based tracking" mechanism to detect
/// which reactive variables are used during the execution of its [builder].
///
/// ### Usage
/// Simply wrap any widget that depends on reactive state in an [LWatch].
///
/// // Example usage:
/// ```dart
/// final count = 0.lx;
///
/// LWatch(() => Text('Count: ${count.value}'))
/// ```
///
/// ### Architectural Rationale
/// Traditionally, Flutter requires manual listeners or broad rebuilds via
/// `setState`. [LWatch] provides fine-grained updates by only rebuilding the
/// specific subtree that depends on the changed state, significantly improving
/// performance in complex UIs.
class LWatch extends Widget {
  /// The builder function that constructs the reactive widget tree.
  final Widget Function() builder;

  /// An optional label for debugging and performance profiling.
  final String? debugLabel;

  /// Creates a reactive [LWatch] widget.
  const LWatch(this.builder, {super.key, this.debugLabel});

  @override
  Element createElement() => LWatchElement(this);
}

class LWatchElement extends ComponentElement implements LevitReactiveObserver {
  LWatchElement(LWatch super.widget);

  @override
  void update(LWatch newWidget) {
    super.update(newWidget);
    markNeedsBuild(); // Force rebuild on update
    rebuild();
  }

  // Fast path for single notifier (most common case)
  LevitReactiveNotifier? _singleNotifier;
  bool _usingSinglePath = false;

  // Slow path for multiple dependencies
  Map<Stream, StreamSubscription>? _subscriptions;
  Map<LevitReactiveNotifier, void Function()>? _notifiers;

  // Optimized: Use List instead of Set for zero-allocation capture
  List<Stream>? _newStreams;
  List<LevitReactiveNotifier>? _newNotifiers;

  bool _isDirty = false;

  @override
  void addStream<T>(Stream<T> stream) {
    (_newStreams ??= []).add(stream);
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    (_newNotifiers ??= []).add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    // No-op
  }

  void _cleanupAll() {
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    final subs = _subscriptions;
    if (subs != null && subs.isNotEmpty) {
      for (final sub in subs.values) {
        sub.cancel();
      }
      subs.clear();
    }

    final nots = _notifiers;
    if (nots != null && nots.isNotEmpty) {
      for (final entry in nots.entries) {
        entry.key.removeListener(entry.value);
      }
      nots.clear();
    }
  }

  void _triggerRebuild() {
    if (!_isDirty && mounted) {
      _isDirty = true;
      markNeedsBuild();
    }
  }

  @override
  Widget build() {
    if ((widget as LWatch).debugLabel != null) {
      assert(() {
        debugPrint('LWatch[${(widget as LWatch).debugLabel}] rebuilding');
        return true;
      }());
    }

    _isDirty = false;
    _newStreams = null;
    _newNotifiers = null;

    final previousProxy = Lx.proxy;
    Lx.proxy = this;

    final Widget result;
    try {
      result = (widget as LWatch).builder();
    } finally {
      Lx.proxy = previousProxy;
    }

    _updateSubscriptions(_newStreams, _newNotifiers);

    return result;
  }

  void _updateSubscriptions(
      List<Stream>? nextStreams, List<LevitReactiveNotifier>? nextNotifiers) {
    // 1. FAST PATH: Single Notifier, No Streams
    if (nextStreams == null &&
        nextNotifiers != null &&
        nextNotifiers.length == 1) {
      final notifier = nextNotifiers[0];
      if (_usingSinglePath && identical(_singleNotifier, notifier)) {
        return; // Exact match, zero work
      }

      _cleanupAll();
      _singleNotifier = notifier;
      _usingSinglePath = true;
      notifier.addListener(_triggerRebuild);
      return;
    }

    // 2. EMPTY PATH: No dependencies
    if (nextStreams == null && nextNotifiers == null) {
      if (_usingSinglePath ||
          (_subscriptions?.isNotEmpty ?? false) ||
          (_notifiers?.isNotEmpty ?? false)) {
        _cleanupAll();
      }
      return;
    }

    // 3. SLOW PATH: Multiple Notifiers or Streams
    // Clean up fast path if used
    if (_usingSinglePath) {
      _singleNotifier?.removeListener(_triggerRebuild);
      _singleNotifier = null;
      _usingSinglePath = false;
    }

    // Process Streams
    final currentSubs = _subscriptions;
    if (nextStreams != null) {
      final targetSubs = _subscriptions ??= {};
      // Add new
      for (var i = 0; i < nextStreams.length; i++) {
        final s = nextStreams[i];
        if (!targetSubs.containsKey(s)) {
          targetSubs[s] = s.listen((_) => _triggerRebuild());
        }
      }
      // Remove old (only if we have existing subs)
      if (currentSubs != null && currentSubs.isNotEmpty) {
        // Avoid toSet() allocation - use list containment check
        currentSubs.removeWhere((stream, sub) {
          for (var i = 0; i < nextStreams.length; i++) {
            if (identical(stream, nextStreams[i])) return false;
          }
          sub.cancel();
          return true;
        });
      }
    } else if (currentSubs != null && currentSubs.isNotEmpty) {
      // Clear all streams if none new
      for (final sub in currentSubs.values) {
        sub.cancel();
      }
      currentSubs.clear();
    }

    // Process Notifiers
    final currentNots = _notifiers;
    if (nextNotifiers != null) {
      final targetNots = _notifiers ??= {};
      // Add new
      for (var i = 0; i < nextNotifiers.length; i++) {
        final n = nextNotifiers[i];
        if (!targetNots.containsKey(n)) {
          targetNots[n] = _triggerRebuild;
          n.addListener(_triggerRebuild);
        }
      }
      // Remove old - avoid toSet() allocation
      if (currentNots != null && currentNots.isNotEmpty) {
        currentNots.removeWhere((notifier, listener) {
          for (var i = 0; i < nextNotifiers.length; i++) {
            if (identical(notifier, nextNotifiers[i])) return false;
          }
          notifier.removeListener(listener);
          return true;
        });
      }
    } else if (currentNots != null && currentNots.isNotEmpty) {
      // Clear all notifiers if none new
      for (final entry in currentNots.entries) {
        entry.key.removeListener(entry.value);
      }
      currentNots.clear();
    }
  }

  @override
  void unmount() {
    _cleanupAll();
    super.unmount();
  }
}

/// A reactive widget that observes a single, specific reactive value.
///
/// Unlike [LWatch], which tracks dependencies automatically using a proxy,
/// [LConsumer] requires you to explicitly provide the reactive object to watch.
///
/// ### Usage
/// Use [LConsumer] when you want to be explicit about dependencies or when
/// avoiding the minor overhead of automatic tracking.
///
/// // Example usage:
/// ```dart
/// LConsumer(myCount, (count) => Text('Value: ${count.value}'))
/// ```
class LConsumer<T extends LxReactive> extends Widget {
  /// The builder function that receives the specific reactive instance [x].
  final Widget Function(T x) builder;

  /// The reactive instance to observe.
  final T x;

  /// Creates a widget that specifically watches the reactive object [x].
  const LConsumer(this.x, this.builder, {super.key});

  @override
  Element createElement() => LConsumerElement<T>(this);
}

class LConsumerElement<T extends LxReactive> extends ComponentElement {
  LConsumerElement(LConsumer<T> super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    (widget as LConsumer<T>).x.addListener(_onNotify);
  }

  void _onNotify() {
    if (mounted) markNeedsBuild();
  }

  @override
  void update(LConsumer<T> newWidget) {
    final oldWidget = widget as LConsumer<T>;
    super.update(newWidget);
    if (newWidget.x != oldWidget.x) {
      oldWidget.x.removeListener(_onNotify);
      newWidget.x.addListener(_onNotify);
    }
    markNeedsBuild(); // Force rebuild
    rebuild();
  }

  @override
  Widget build() {
    return (widget as LConsumer<T>).builder((widget as LConsumer<T>).x);
  }

  @override
  void unmount() {
    (widget as LConsumer<T>).x.removeListener(_onNotify);
    super.unmount();
  }
}
