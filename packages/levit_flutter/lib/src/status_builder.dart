import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';

import 'watch.dart';

/// A unified widget for handling the various states of an asynchronous operation.
///
/// [LStatusBuilder] simplifies the UI logic for [AsyncStatus] (Idle, Waiting, Success, Error).
/// It works seamlessly with [LxFuture], [LxStream], [LxAsyncComputed], or any
/// reactive variable holding an [AsyncStatus].
///
/// Under the hood, it uses [LWatch] to automatically listen for status changes.
///
/// ## Usage
///
/// ```dart
/// // 1. From an existing reactive source (default)
/// LStatusBuilder(
///   source: userRx,
///   onSuccess: (user) => UserProfile(user),
/// )
///
/// // 2. From a Future (managed internally)
/// LStatusBuilder.future(
///   future: () => fetchUser(),
///   onSuccess: (user) => UserProfile(user),
/// )
///
/// // 3. From a Stream
/// LStatusBuilder.stream(
///   stream: messageStream,
///   onSuccess: (msg) => MessageTile(msg),
/// )
/// ```
class LStatusBuilder<T> extends StatefulWidget {
  final LxReactive<AsyncStatus<T>>? _source;
  final Future<T> Function()? _futureFactory;
  final Stream<T>? _stream;
  final Future<T> Function()? _asyncCompute;
  final T? _initialValue;

  final Widget Function(T data) onSuccess;
  final Widget Function()? onWaiting;

  /// Builder for error state.
  final Widget Function(Object error, StackTrace? stackTrace)? onError;
  final Widget Function()? onIdle;

  /// Creates a status builder from an existing reactive source.
  const LStatusBuilder({
    super.key,
    required LxReactive<AsyncStatus<T>> source,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
    this.onIdle,
  })  : _source = source,
        _futureFactory = null,
        _stream = null,
        _asyncCompute = null,
        _initialValue = null;

  /// Creates a status builder that manages an [LxFuture].
  const LStatusBuilder.future({
    super.key,
    required Future<T> Function() future,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
    T? initial,
  })  : _source = null,
        _futureFactory = future,
        _stream = null,
        _asyncCompute = null,
        _initialValue = initial,
        onIdle = null; // internal future starts immediately managed

  /// Creates a status builder that manages an [LxStream].
  const LStatusBuilder.stream({
    super.key,
    required Stream<T> stream,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
    T? initial,
  })  : _source = null,
        _futureFactory = null,
        _stream = stream,
        _asyncCompute = null,
        _initialValue = initial,
        onIdle = null;

  /// Creates a status builder from an asynchronous computation.
  const LStatusBuilder.computed({
    super.key,
    required Future<T> Function() compute,
    required this.onSuccess,
    this.onWaiting,
    this.onError,
  })  : _source = null,
        _futureFactory = null,
        _stream = null,
        _asyncCompute = compute,
        _initialValue = null,
        onIdle = null;

  @override
  State<LStatusBuilder<T>> createState() => _LStatusBuilderState<T>();
}

class _LStatusBuilderState<T> extends State<LStatusBuilder<T>> {
  LxReactive<AsyncStatus<T>>? _internalSource;

  LxReactive<AsyncStatus<T>> get _effectiveSource {
    if (widget._source != null) return widget._source!;
    return _internalSource!;
  }

  @override
  void initState() {
    super.initState();
    _initSource();
  }

  @override
  void didUpdateWidget(LStatusBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-init if factories changed (simple equality check might not be enough for closures)
    // If external source changed:
    if (widget._source != oldWidget._source) {
      // Internal source not needed if external provided
      _disposeInternal();
    }
  }

  void _initSource() {
    if (widget._source != null) return;

    if (widget._futureFactory != null) {
      _internalSource =
          LxFuture<T>(widget._futureFactory!(), initial: widget._initialValue);
    } else if (widget._stream != null) {
      _internalSource =
          LxStream<T>(widget._stream!, initial: widget._initialValue);
    } else if (widget._asyncCompute != null) {
      _internalSource =
          LxComputed.async(widget._asyncCompute!) as LxReactive<AsyncStatus<T>>;
    }
  }

  void _disposeInternal() {
    _internalSource?.close();
    _internalSource = null;
  }

  @override
  void dispose() {
    _disposeInternal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      final status = _effectiveSource.value;
      return switch (status) {
        AsyncIdle<T>() => widget.onIdle?.call() ??
            widget.onWaiting?.call() ??
            const SizedBox.shrink(),
        AsyncWaiting<T>() =>
          widget.onWaiting?.call() ?? const SizedBox.shrink(),
        AsyncError<T>(:final error, :final stackTrace) =>
          widget.onError?.call(error, stackTrace) ??
              Center(child: Text('Error: $error')),
        AsyncSuccess<T>(:final value) => widget.onSuccess(value),
      };
    });
  }
}
