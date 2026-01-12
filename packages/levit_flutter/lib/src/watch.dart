import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

/// A reactive widget that automatically rebuilds when accessed [Lx] values change.
///
/// [LWatch] uses "observation by access" to track dependencies. You do not need
/// to explicitly declare which variables to listen to. Instead, simply accessing
/// `.value` on any [LxReactive] object within the [builder] will automatically
/// register it as a dependency.
///
/// When any dependency changes, the widget marks itself as dirty and rebuilds.
///
/// ## Usage
///
/// ```dart
/// final count = 0.lx;
///
/// LWatch(() => Text('Count: ${count.value}'))
/// ```
///
/// ## How it works
///
/// 1.  During `build`, [LWatch] sets itself as the active [Lx.proxy].
/// 2.  Any access to [LxReactive.value] notifies the proxy.
/// 3.  [LWatch] subscribes to these notifications.
/// 4.  Subscriptions are recalculated on every rebuild, ensuring that
///     dependencies are always up-to-date (e.g., if a conditional branch changes).
///
/// ## Performance Tips
///
/// *   Keep the [builder] function pure and fast.
/// *   Avoid performing side effects or expensive computations directly in the builder.
/// *   Use [LValue] if you only need to observe a single specific variable
///     and want to avoid the overhead of proxy tracking.
class LWatch extends StatefulWidget {
  /// The builder function that constructs the widget tree.
  ///
  /// Any [LxReactive] value accessed within this function will be tracked.
  final Widget Function() builder;

  /// An optional label for debugging purposes.
  ///
  /// If provided, a debug message will be printed to the console whenever this
  /// widget rebuilds (in debug mode only).
  final String? debugLabel;

  /// Creates a reactive [LWatch] widget.
  const LWatch(this.builder, {super.key, this.debugLabel});

  @override
  State<LWatch> createState() => _WatchState();
}

class _WatchState extends State<LWatch> implements LxObserver {
  // Lazy allocation - only create Maps when first subscription is added
  Map<Stream, StreamSubscription>? _subscriptions;
  Map<LxNotifier, void Function()>? _notifiers;

  Set<Stream>? _newStreams;
  Set<LxNotifier>? _newNotifiers;

  bool _isDirty = false;

  // For identity-based skip optimization
  int _lastNotifierCount = 0;
  int _lastStreamCount = 0;

  @override
  void addStream<T>(Stream<T> stream) {
    _newStreams?.add(stream);
  }

  @override
  void addNotifier(LxNotifier notifier) {
    _newNotifiers?.add(notifier);
  }

  void _triggerRebuild() {
    if (!_isDirty && mounted) {
      _isDirty = true;
      // Direct element marking - faster than setState
      (context as Element).markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug output if label is set
    if (widget.debugLabel != null) {
      assert(() {
        debugPrint('LWatch[${widget.debugLabel}] rebuilding');
        return true;
      }());
    }

    _isDirty = false;
    _newStreams?.clear();
    _newNotifiers?.clear();
    _newStreams ??= {};
    _newNotifiers ??= {};

    // 1. Set ourselves as the active observer
    final previousProxy = Lx.proxy;
    Lx.proxy = this;

    final Widget result;
    try {
      // 2. Build - any Lx.value access will call addStream on us
      result = widget.builder();
    } finally {
      // 3. Restore the proxy
      Lx.proxy = previousProxy;
    }

    // 4. Update subscriptions based on what was accessed
    _updateSubscriptions(_newStreams!, _newNotifiers!);

    return result;
  }

  void _updateSubscriptions(
      Set<Stream> nextStreams, Set<LxNotifier> nextNotifiers) {
    // Fast-path: skip if counts match (likely unchanged)
    final nots = _notifiers;
    final subs = _subscriptions;

    final currentNotsCount = nots?.length ?? 0;
    final currentSubsCount = subs?.length ?? 0;

    if (nextNotifiers.length == _lastNotifierCount &&
        nextStreams.length == _lastStreamCount &&
        nextNotifiers.length == currentNotsCount &&
        nextStreams.length == currentSubsCount) {
      // Verify content match
      bool allNotifiersMatch = true;
      if (currentNotsCount > 0) {
        for (final n in nextNotifiers) {
          if (!nots!.containsKey(n)) {
            allNotifiersMatch = false;
            break;
          }
        }
      }

      if (allNotifiersMatch) {
        bool allStreamsMatch = true;
        if (currentSubsCount > 0) {
          for (final s in nextStreams) {
            if (!subs!.containsKey(s)) {
              allStreamsMatch = false;
              break;
            }
          }
        }
        if (allStreamsMatch) return; // Skip - nothing changed
      }
    }

    _lastNotifierCount = nextNotifiers.length;
    _lastStreamCount = nextStreams.length;

    // Lazy allocate if needed - ONLY if we actually have items to process

    // 1. Remove subscriptions that are no longer needed
    if (subs != null && subs.isNotEmpty) {
      final removedStreams =
          subs.keys.where((s) => !nextStreams.contains(s)).toList();
      for (final s in removedStreams) {
        subs.remove(s)?.cancel();
      }
    }

    // 2. Add new stream subscriptions
    if (nextStreams.isNotEmpty) {
      final targetSubs = _subscriptions ??= {};
      for (final s in nextStreams) {
        if (!targetSubs.containsKey(s)) {
          targetSubs[s] = s.listen((_) => _triggerRebuild());
        }
      }
    }

    // 3. Remove notifiers that are no longer needed
    if (nots != null && nots.isNotEmpty) {
      final removedNotifiers =
          nots.keys.where((n) => !nextNotifiers.contains(n)).toList();
      for (final n in removedNotifiers) {
        final listener = nots.remove(n);
        if (listener != null) n.removeListener(listener);
      }
    }

    // 4. Add new notifier listeners
    if (nextNotifiers.isNotEmpty) {
      final targetNots = _notifiers ??= {};
      for (final n in nextNotifiers) {
        if (!targetNots.containsKey(n)) {
          targetNots[n] = _triggerRebuild;
          n.addListener(_triggerRebuild);
        }
      }
    }
  }

  @override
  void dispose() {
    final subs = _subscriptions;
    if (subs != null) {
      for (final sub in subs.values) {
        sub.cancel();
      }
      subs.clear();
    }

    final nots = _notifiers;
    if (nots != null) {
      for (final entry in nots.entries) {
        entry.key.removeListener(entry.value);
      }
      nots.clear();
    }
    super.dispose();
  }
}

/// A reactive widget that observes a single specific reactive value.
///
/// Unlike [LWatch], which tracks dependencies automatically, [LValue]
/// requires you to explicitly provide the reactive variable [x]. This avoids
/// the overhead of the proxy mechanism and can be slightly more performant
/// for simple use cases.
///
/// ## Usage
/// ```dart
/// LValue<Lx<int>>(
///   count,
///   (value) => Text('Count: ${value.value}'),
/// )
/// ```
class LValue<T extends LxReactive> extends StatefulWidget {
  /// The builder function that receives the reactive value.
  final Widget Function(T value) builder;

  /// The reactive value to observe.
  final T x;

  /// Creates a widget that watches the specific reactive object [x].
  const LValue(this.x, this.builder, {super.key});

  @override
  State<LValue<T>> createState() => _LValueState<T>();
}

class _LValueState<T extends LxReactive> extends State<LValue<T>> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(LValue<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.x != oldWidget.x) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.x.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.x);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
