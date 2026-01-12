/// Pure Dart reactive state management primitives.
///
/// This library provides the reactive engine for the Levit framework.
/// It has zero Flutter dependencies and can be used in any Dart environment (Flutter, CLI, server-side).
///
/// ## Core Classes
///
/// *   **[Lx]**: Base reactive wrapper for any type.
/// *   **[LxList]**: Reactive list with automatic change detection.
/// *   **[LxMap]**: Reactive map with automatic change detection.
///
/// ## Async Reactive Types
///
/// *   **[AsyncStatus]**: Sealed status type (`AsyncIdle`, `AsyncWaiting`, `AsyncSuccess`, `AsyncError`).
/// *   **[LxFuture]**: Reactive wrapper for [Future].
/// *   **[LxStream]**: Reactive wrapper for [Stream].
/// *   **[LxComputed]**: Auto-tracking computed value (sync).
/// *   **[LxAsyncComputed]**: Async computed value.
///
/// ## Workers
///
/// *   **[watch]**: Core worker with support for stream transforms (debounce, throttle, etc.).
/// *   **[watchTrue]**: Fires callback when source becomes true.
/// *   **[watchFalse]**: Fires callback when source becomes false.
/// *   **[watchValue]**: Fires callback when source matches target value.
///
/// ## Usage
///
/// ```dart
/// final count = 0.lx;
/// final user = LxFuture(fetchUser());
///
/// // Watch any reactive source
/// watch(count, (v) => print('Count: $v'));
///
/// // Or with status handling
/// watch(user, (status) => print('Status: $status'));
///
/// count.value++;
/// ```
library levit_reactive;

export 'src/base_types.dart';
export 'src/collections.dart';
export 'src/computed.dart';
export 'src/core.dart';
export 'src/middlewares.dart';
export 'src/worker.dart';
