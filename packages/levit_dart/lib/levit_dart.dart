/// Core Levit framework for Dart.
///
/// This package provides the foundational building blocks for Levit applications:
/// *   [LevitController]: The base class for business logic components.
/// *   [LevitTasksMixin]: Advanced task management for controllers.
/// *   Re-exports of [levit_di] for dependency injection.
/// *   Re-exports of [levit_reactive] for reactive primitives.

library;

import 'dart:async';
import 'dart:math' as math;

import 'package:levit_di/levit_di.dart';
import 'package:levit_reactive/levit_reactive.dart';

export 'package:levit_di/levit_di.dart';
export 'package:levit_reactive/levit_reactive.dart';

// ============================================================================
// LevitController - Pure Dart Controller Base
// ============================================================================

/// Base class for controllers with lifecycle management and resource cleanup.
///
/// [LevitController] implements [LevitDisposable] to provide [onInit] and
/// [onClose] hooks. It is designed to be used with the Levit dependency
/// injection system but can also be used standalone.
///
/// It exists to provide a standard structure for business logic components,
/// ensuring resources like streams and reactive variables are properly managed.
///
/// It provides the [autoDispose] method to simplify the cleanup of:
/// *   [LxReactive] variables.
/// *   [StreamSubscription]s.
/// *   Void callbacks (e.g., for custom cleanup logic).
abstract class LevitController implements LevitDisposable {
  bool _initialized = false;
  bool _disposed = false;
  bool _closed = false;
  final List<dynamic> _disposables = [];

  /// Returns `true` if [onInit] has been called.
  bool get initialized => _initialized;

  /// Returns `true` if the controller has been disposed (closed).
  bool get isDisposed => _disposed;

  /// Registers an object to be automatically cleaned up when the controller is closed.
  ///
  /// Supported types:
  /// *   [LxReactive]: Calls `.close()`.
  /// *   [StreamSubscription]: Calls `.cancel()`.
  /// *   `void Function()`: Calls the function.
  ///
  /// Returns the passed [object] for chaining.
  ///
  /// ```dart
  /// final subscription = autoDispose(stream.listen(...));
  /// ```
  T autoDispose<T>(T object) {
    _disposables.add(object);
    return object;
  }

  @override
  void onInit() {
    _initialized = true;
  }

  @override
  void onClose() {
    if (_closed) return;
    _closed = true;
    _disposed = true;

    for (final disposable in _disposables) {
      _disposeItem(disposable);
    }
    _disposables.clear();
  }

  // Duck typing for cancelable objects
  void _disposeItem(dynamic item) {
    if (item == null) return;

    // 1. Framework Specifics (Priority)
    if (item is LxReactive) {
      item.close();
      return;
    }

    // 2. The "Cancel" Group (Async tasks)
    // Most common: StreamSubscription, Timer
    try {
      if (item is StreamSubscription) {
        item.cancel();
        return;
      }
      // Duck typing for other cancelables (like Timer or CancelableOperation)
      (item as dynamic).cancel();
      return;
    } on NoSuchMethodError {
      // Not cancelable, fall through
    }

    // 3. The "Dispose" Group (Flutter Controllers)
    // Most common: TextEditingController, ChangeNotifier, FocusNode
    try {
      (item as dynamic).dispose();
      return;
    } on NoSuchMethodError {
      // Not disposable, fall through
    }

    // 4. The "Close" Group (Sinks, BLoCs, IO)
    // Most common: StreamController, Sink, Bloc
    try {
      (item as dynamic).close();
      return;
    } on NoSuchMethodError {
      // Not closeable, fall through
    }

    // 5. The "Callable" Group (Cleanup Callbacks)
    if (item is void Function()) {
      item();
      return;
    }

    // Optional: Log a warning in debug mode if an item was registered
    // but matched none of the cleanup patterns.
    // assert(false, 'Levit: Could not dispose object of type ${item.runtimeType}');
  }
}

// ============================================================================
// Service and Controller Mixins
// ============================================================================

/// Priority levels for task execution.
enum TaskPriority {
  /// High priority tasks are processed before normal tasks.
  high,

  /// Default priority for tasks.
  normal,

  /// Low priority tasks are processed after other tasks.
  low,
}

/// A mixin for [LevitController] that adds advanced task management capabilities.
///
/// Features include:
/// *   Concurrency limits (queuing).
/// *   Task priority ([TaskPriority]).
/// *   Automatic retries with exponential backoff.
///
/// This mixin is focused on task execution and does not expose reactive state for UI consumption.
/// See [LevitReactiveTasksMixin] if you need UI-specific reactive state for tasks.
mixin LevitTasksMixin on LevitController {
  late final _TaskEngine _taskEngine;

  /// The maximum number of concurrent tasks allowed.
  ///
  /// Defaults to a very large number (effectively infinite). Override this getter
  /// to enforce a limit (e.g., `3` for a connection pool).
  int get maxConcurrentTasks => 100000;

  /// Optional default error handler for all tasks run by this service.
  ///
  /// If provided, this function is called when a task fails after all retries.
  void Function(Object error, StackTrace stackTrace)? onServiceError;

  @override
  void onInit() {
    super.onInit();
    _taskEngine = _TaskEngine(maxConcurrent: maxConcurrentTasks);
  }

  /// Executes an asynchronous [task] with optional retry and priority logic.
  ///
  /// Returns the result of the task, or throws if it fails (unless handled internally).
  ///
  /// *   [task]: The async function to execute.
  /// *   [id]: An optional ID for the task (useful for cancellation).
  /// *   [priority]: The priority of the task relative to others in the queue.
  /// *   [retries]: The number of times to retry the task upon failure.
  /// *   [retryDelay]: The initial delay before the first retry.
  /// *   [useExponentialBackoff]: Whether to increase the delay exponentially for subsequent retries.
  /// *   [onError]: A custom error handler for this specific task. If not provided, [onServiceError] is used.
  Future<T?> runTask<T>(
    Future<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    return _taskEngine.schedule(
      task: task,
      id: id ?? 'task_${DateTime.now().microsecondsSinceEpoch}',
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: (e, s) {
        final handler = onError ?? onServiceError;
        if (handler != null) {
          handler(e, s);
        } else {
          // If no handler provided, we rethrow to the caller of the Future.
          // The Engine catches internally but the Completer must completeError.
          // This is handled by _TaskEngine returning rethrow capability via Future.error
          throw e; // RETHROW isn't quite right in callback. _TaskEngine handles this.
        }
      },
    );
  }

  /// Cancels a specific task by its ID.
  ///
  /// If the task is running, it will be marked for cancellation (though the Future cannot be interrupted).
  /// If it is queued, it will be removed from the queue.
  void cancelTask(String id) => _taskEngine.cancel(id);

  /// Cancels all running and queued tasks.
  void cancelAllTasks() => _taskEngine.cancelAll();
}

/// A mixin for [LevitController] that combines task management with reactive state.
///
/// This mixin is ideal for controllers that drive UI needing to show loading states,
/// progress bars, or error messages for asynchronous operations.
///
/// It exposes:
/// *   [tasks]: A reactive map of task IDs to their current [AsyncStatus].
/// *   [totalProgress]: A computed value (0.0 to 1.0) representing overall progress.
mixin LevitReactiveTasksMixin on LevitController {
  late final _TaskEngine _taskEngine;

  /// The maximum number of concurrent tasks allowed.
  int get maxConcurrentTasks => 100000;

  /// A reactive map of task IDs to their current status.
  ///
  /// Use this to display the state of individual tasks in the UI.
  final tasks = LxMap<String, AsyncStatus<dynamic>>();

  /// Optional weights for individual tasks, used to calculate [totalProgress].
  final _taskWeights = LxMap<String, double>();

  /// A computed value representing the weighted average progress (0.0 to 1.0) of all active tasks.
  ///
  /// **Warning:** This computation iterates over all active tasks. If you have hundreds
  /// of concurrent tasks, accessing this frequently triggers an O(N) loop.
  late final totalProgress = autoDispose(LxComputed<double>(() {
    if (tasks.isEmpty) return 0.0;
    double sumProgress = 0;
    double sumWeight = 0;

    for (final id in tasks.keys) {
      final status = tasks[id]!;
      final weight = _taskWeights[id] ?? 1.0;

      final p = switch (status) {
        AsyncSuccess() => 1.0,
        AsyncWaiting(:final progress) => progress ?? 0.0,
        _ => 0.0,
      };

      sumProgress += p * weight;
      sumWeight += weight;
    }

    return sumWeight == 0 ? 0.0 : sumProgress / sumWeight;
  }));

  /// Optional global error handler for tasks in this controller.
  void Function(Object error, StackTrace? stackTrace)? onTaskError;

  @override
  void onInit() {
    super.onInit();
    _taskEngine = _TaskEngine(maxConcurrent: maxConcurrentTasks);
  }

  /// Executes a [task] and automatically tracks its status in [tasks].
  ///
  /// *   [id]: A unique ID for the task (required for tracking).
  /// *   [task]: The async function to execute.
  /// *   [priority]: Task priority.
  /// *   [retries]: Number of retry attempts.
  /// *   [retryDelay]: Delay between retries.
  /// *   [useExponentialBackoff]: Exponential backoff strategy.
  /// *   [weight]: The weight of this task in [totalProgress] calculation (default 1.0).
  /// *   [onError]: Custom error handler.
  Future<T?> runTask<T>(
    String id,
    Future<T> Function() task, {
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    // Initialize status
    tasks[id] = const AsyncWaiting<dynamic>();
    _taskWeights[id] = weight;

    // Wrap execution to update UI state when it actually Runs
    Future<T> wrappedTask() async {
      // (Optional: update status to 'Running' vs 'Queued' if distinction existed)

      final result = await task();
      tasks[id] = AsyncSuccess<T>(result);
      return result;
    }

    return _taskEngine.schedule(
      task: wrappedTask,
      id: id,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: (e, s) {
        // This callback is invoked by engine only on FINAL failure
        tasks[id] = AsyncError<Object>(e, s, tasks[id]?.lastValue);
        final handler = onError ?? onTaskError;
        if (handler != null) {
          handler(e, s);
        } else {
          // If no custom handler, let it bubble up via Future result
          // But since the loop catches internally, we rely on return null or handled state.
        }
      },
    );
  }

  /// Manually updates the progress of a specific task.
  ///
  /// *   [id]: The task ID.
  /// *   [value]: The progress value (0.0 to 1.0).
  void updateTaskProgress(String id, double value) {
    if (tasks.containsKey(id)) {
      final current = tasks[id]!;
      tasks[id] = AsyncWaiting<dynamic>(current.lastValue, value);
    }
  }

  /// Clears a task from the state map and cancels it if running.
  void clearTask(String id) {
    tasks.remove(id);
    _taskWeights.remove(id);
    cancelTask(id);
  }

  /// Clears all completed ([AsyncSuccess] or [AsyncIdle]) tasks from the state map.
  void clearCompleted() {
    tasks.removeWhere(
        (id, status) => status is AsyncSuccess || status is AsyncIdle);
    _taskWeights.removeWhere((id, _) => !tasks.containsKey(id));
  }

  /// Cancels a specific task.
  void cancelTask(String id) => _taskEngine.cancel(id);

  /// Cancels all tasks.
  void cancelAllTasks() => _taskEngine.cancelAll();
}

// ============================================================================
// Internal Task Engine
// ============================================================================

class _TaskEngine {
  final int maxConcurrent;
  final _activeTasks = <String, _ActiveTask>{};
  final _queue = <_QueuedTask>[];

  _TaskEngine({required this.maxConcurrent});

  Future<T?> schedule<T>({
    required String id,
    required Future<T> Function() task,
    required TaskPriority priority,
    required int retries,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    required Function(Object, StackTrace) onError,
  }) async {
    // If we can run now, run.
    if (_activeTasks.length < maxConcurrent) {
      return _execute(
        id,
        task,
        retries,
        retryDelay,
        useExponentialBackoff,
        onError,
      );
    } else {
      // Enqueue
      final completer = Completer<T?>();
      _queue.add(_QueuedTask(
        id: id,
        task: task,
        priority: priority,
        retries: retries,
        retryDelay: retryDelay,
        useExponentialBackoff: useExponentialBackoff,
        onError: onError,
        completer: completer,
      ));
      _sortQueue(); // Ensure highest priority is first
      return completer.future;
    }
  }

  void _sortQueue() {
    // Sort logic: High (0) < Normal (1) < Low (2). Min first.
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  Future<T?> _execute<T>(
    String id,
    Future<T> Function() task,
    int retries,
    Duration? retryDelay,
    bool useExponentialBackoff,
    Function(Object, StackTrace) onError,
  ) async {
    // Track active task (stores cancel token logic if we implemented strictly, currently just marker)
    final activeTaskNode = _ActiveTask(id);
    _activeTasks[id] = activeTaskNode;

    int attempts = 0;
    while (true) {
      if (activeTaskNode.isCancelled) {
        _finalize(id);
        return null;
      }

      try {
        final result = await task();
        _finalize(id);
        return result;
      } catch (e, s) {
        if (attempts < retries && !activeTaskNode.isCancelled) {
          attempts++;
          final baseDelay = retryDelay ?? const Duration(milliseconds: 500);
          final delay = useExponentialBackoff
              ? baseDelay * math.pow(2, attempts - 1)
              : baseDelay;

          await Future.delayed(delay);
          continue; // Retry loop
        } else {
          // Final failure
          _finalize(id);
          onError(e, s);
          // Return null to signify failure (since we handled it via onError)
          // Optionally rethrow if onError logic didn't stop propagation?
          // For now, we return null to match T? signature.
          return null;
        }
      }
    }
  }

  void _finalize(String id) {
    _activeTasks.remove(id);
    _processQueue();
  }

  void _processQueue() {
    if (_queue.isEmpty || _activeTasks.length >= maxConcurrent) return;

    final next = _queue.removeAt(0); // Takes highest priority

    // Execute unwraps the dynamic-typed task closure from ScheduledTask
    // We need to cast or just run it. The completer handles the type.
    _runQueued(next);
  }

  Future<void> _runQueued(_QueuedTask item) async {
    try {
      final result = await _execute(
        item.id,
        item.task,
        item.retries,
        item.retryDelay,
        item.useExponentialBackoff,
        item.onError,
      );
      item.completer.complete(result);
    } catch (e, s) {
      item.completer.completeError(e, s);
    }
  }

  void cancel(String id) {
    if (_activeTasks.containsKey(id)) {
      _activeTasks[id]!.isCancelled = true;
      // We can't interrupt the Future, but the loop checks isCancelled before retry.
    }
    _queue.removeWhere((item) => item.id == id);
  }

  void cancelAll() {
    for (var t in _activeTasks.values) {
      t.isCancelled = true;
    }
    _queue.clear();
  }
}

class _ActiveTask {
  final String id;
  bool isCancelled = false;
  _ActiveTask(this.id);
}

class _QueuedTask {
  final String id;
  final Future<dynamic> Function() task;
  final TaskPriority priority;
  final int retries;
  final Duration? retryDelay;
  final bool useExponentialBackoff;
  final Function(Object, StackTrace) onError;
  final Completer completer;

  _QueuedTask({
    required this.id,
    required this.task,
    required this.priority,
    required this.retries,
    required this.retryDelay,
    required this.onError,
    required this.completer,
    this.useExponentialBackoff = true,
  });
}
