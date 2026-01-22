/// Pure Dart reactive state management primitives.
///
/// This package provides the low-level reactive engine of the Levit framework.
/// It is dependency-free and focuses on high-performance, fine-grained state
/// tracking using a proxy-based mechanism.
///
/// ### Core Abstractions
/// *   [LxReactive]: The base interface for all reactive objects.
/// *   [Lx]: The primary entry point for creating reactive variables and managing
///     the global reactive state (proxies, batches, middlewares).
/// *   [LxComputed]: Derived reactive state that automatically tracks dependencies.
///
/// `levit_reactive` is designed to be the foundational layer for any Dart
/// application requiring deterministic state derivation.
library;

export 'src/async_status.dart';
export 'src/async_types.dart';
export 'src/base_types.dart';
export 'src/collections.dart';
export 'src/computed.dart';
export 'src/core.dart' hide LevitStateCore;
export 'src/global_accessor.dart';
export 'src/middlewares.dart' hide LevitStateMiddlewareChain;
export 'src/watchers.dart';
