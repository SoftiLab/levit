/// Flutter integration layer for the Levit framework.
///
/// This package provides the binding between Levit's core composition and
/// reactive layers and Flutter's widget tree.
///
/// ### Core Widgets
/// *   [LWatch]: The primary building block for reactive UIs. It automatically
///     tracks reactive dependencies accessed during build.
/// *   [LScope]: Provides widget-tree-scoped dependency injection with
///     deterministic cleanup.
/// *   [LView]: A base class for widgets that need access to a specific controller.
/// *   [LStatusBuilder]: A declarative builder for asynchronous state management.
///
/// `levit_flutter` enables scaling Flutter applications by providing explicit
/// rebuild boundaries and predictable resource lifecycles.
library;

export 'package:levit_dart/levit_dart.dart';

export 'src/scope.dart'
    hide LMultiScopeElement, LScopedViewElement, LScopeElement;
export 'src/status_builder.dart';
export 'src/view.dart';
export 'src/watch.dart' hide LConsumerElement, LWatchElement;
