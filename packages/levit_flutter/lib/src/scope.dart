import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';
import 'package:levit_flutter/src/watch.dart';

/// An internal widget that propagates the [LevitScope] down the widget tree.
class _ScopeProvider extends InheritedWidget {
  final LevitScope scope;

  const _ScopeProvider({
    required this.scope,
    required super.child,
  });

  static LevitScope? of(BuildContext context) {
    // We use getInheritedWidgetOfExactType instead of dependOnInheritedWidgetOfExactType
    // because the scope itself doesn't change after creation, and we don't want
    // rebuilds just because we accessed the scope.
    return context.getInheritedWidgetOfExactType<_ScopeProvider>()?.scope;
  }

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) => scope != oldWidget.scope;
}

/// Mixin that provides common scope initialization and disposal logic.
mixin _ScopeMixin<T extends StatefulWidget> on State<T> {
  late final LevitScope _scope;
  bool _scopeInitialized = false;

  /// Creates a child scope from the parent scope (or global Levit).
  LevitScope _createScope(BuildContext context, String scopeName) {
    final parentScope = _ScopeProvider.of(context);
    if (parentScope != null) {
      return parentScope.createScope(scopeName);
    }
    return Levit.createScope(scopeName);
  }

  /// Wraps a child with the scope provider. Call after scope is initialized.
  Widget wrapWithScope(Widget child) {
    return _ScopeProvider(scope: _scope, child: child);
  }

  /// Disposes the scope if initialized.
  void disposeScope() {
    if (_scopeInitialized) {
      _scope.reset(force: true);
    }
  }
}

/// A widget that creates and manages a dependency injection scope.
///
/// [LScope] establishes a new [LevitScope] as a child of the nearest parent scope
/// (or the global [Levit] container). It registers a single dependency of type [T]
/// within this scope.
///
/// When the [LScope] is disposed (removed from the widget tree), its scope is
/// automatically closed, triggering the disposal of any registered objects
/// that implement [LevitDisposable].
///
/// Use this widget to provide a local controller or service to a specific
/// part of your UI, ensuring it is cleaned up when no longer needed.
///
/// ## Usage
/// ```dart
/// LScope<ProductController>(
///   init: () => ProductController(),
///   child: ProductPage(),
/// )
/// ```
class LScope<T> extends StatefulWidget {
  /// The factory function to create the dependency.
  final T Function() init;

  /// The child widget tree that will have access to this scope.
  final Widget child;

  /// An optional tag to identify the dependency.
  final String? tag;

  /// Whether the dependency should persist even after reset (defaults to false).
  ///
  /// Note: The scope itself is destroyed when the widget is disposed, so
  /// this flag is less relevant for [LScope] than for global registration,
  /// but it prevents accidental deletion if manual `delete` calls are made.
  final bool permanent;

  /// An optional name for the scope (useful for debugging).
  final String? name;

  /// Creates a scoped dependency provider.
  const LScope({
    super.key,
    required this.init,
    required this.child,
    this.tag,
    this.permanent = false,
    this.name,
  });

  @override
  State<LScope<T>> createState() => _LScopeState<T>();
}

class _LScopeState<T> extends State<LScope<T>> with _ScopeMixin<LScope<T>> {
  void _initScope(BuildContext context) {
    if (_scopeInitialized) return;
    final scopeName = widget.name ?? 'LScope<${T.toString()}>';
    _scope = _createScope(context, scopeName);
    _scope.put<T>(widget.init(), tag: widget.tag, permanent: widget.permanent);
    _scopeInitialized = true;
  }

  @override
  void didUpdateWidget(LScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tag != oldWidget.tag || widget.name != oldWidget.name) {
      // Ideally, we should recreate scope, but that loses state.
      // For now, at least warn in debug.
      assert(() {
        debugPrint(
            'WARNING: LScope tag/name changed but scope cannot be updated dynamically.');
        return true;
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    _initScope(context);
    return wrapWithScope(widget.child);
  }

  @override
  void dispose() {
    disposeScope();
    super.dispose();
  }
}

/// A widget that manages multiple dependency injection bindings in a single scope.
///
/// Use [LMultiScope] when you need to provide multiple controllers or services
/// to a subtree without nesting multiple [LScope] widgets.
///
/// ## Usage
/// ```dart
/// LMultiScope(
///   scopes: [
///     ScopeBinding(() => AuthController()),
///     ScopeBinding(() => UserController()),
///   ],
///   child: MyApp(),
/// )
/// ```
class LMultiScope extends StatefulWidget {
  /// The list of bindings to register in the scope.
  final List<ScopeBinding> scopes;

  /// The child widget tree.
  final Widget child;

  /// An optional name for the scope (useful for debugging).
  final String? name;

  /// Creates a multi-binding scope provider.
  const LMultiScope({
    super.key,
    required this.scopes,
    required this.child,
    this.name,
  });

  @override
  State<LMultiScope> createState() => _LMultiScopeState();
}

class _LMultiScopeState extends State<LMultiScope>
    with _ScopeMixin<LMultiScope> {
  void _initScope(BuildContext context) {
    if (_scopeInitialized) return;
    final scopeName = widget.name ?? 'LMultiScope';
    _scope = _createScope(context, scopeName);
    for (final scope in widget.scopes) {
      scope._registerIn(_scope);
    }
    _scopeInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _initScope(context);
    return wrapWithScope(widget.child);
  }

  @override
  void dispose() {
    disposeScope();
    super.dispose();
  }
}

/// Configuration for a single binding in [LMultiScope].
class ScopeBinding<T> {
  /// Factory function to create the dependency.
  final T Function() init;

  /// Optional tag for the binding.
  final String? tag;

  /// Whether the binding is permanent.
  final bool permanent;

  /// Creates a binding definition.
  const ScopeBinding(this.init, {this.tag, this.permanent = false});

  void _registerIn(LevitScope scope) {
    scope.put<T>(init(), tag: tag, permanent: permanent);
  }
}

/// Helper class for scoped DI access via [BuildContext].
class LevitContext {
  final BuildContext _context;

  LevitContext(this._context);

  /// Finds and returns an instance of type [S] from the nearest scope.
  S find<S>({String? tag}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.find<S>(tag: tag);
    }
    return Levit.find<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the nearest scope (or globally).
  bool isRegistered<S>({String? tag}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isRegistered<S>(tag: tag);
    }
    return Levit.isRegistered<S>(tag: tag);
  }

  /// Registers a dependency dynamically in the nearest scope.
  S put<S>(S dependency, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(dependency, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(dependency, tag: tag, permanent: permanent);
  }
}

/// Extensions on [BuildContext] for easy access to the dependency injection system.
extension LevitContextExtension on BuildContext {
  /// Access the scoped dependency injection system.
  ///
  /// usage: `context.levit.find<MyController>()`
  LevitContext get levit => LevitContext(this);
}

/// A convenience widget that combines scope creation, controller instantiation,
/// and reactive UI building.
///
/// [LScopedView] simplifies the common pattern of creating a controller for a
/// specific page or view. It manages the lifecycle of the controller (init/dispose)
/// and automatically wraps the content in [LWatch] if [autoWatch] is true.
///
/// Use this class to quickly build pages that have a dedicated controller.
///
/// ## Usage
/// ```dart
/// class CounterPage extends LScopedView<CounterController> {
///   const CounterPage({super.key});
///
///   @override
///   CounterController createController() => CounterController();
///
///   @override
///   Widget buildContent(BuildContext context, CounterController controller) {
///     return Text('Count: ${controller.count.value}');
///   }
/// }
/// ```
abstract class LScopedView<T> extends StatefulWidget {
  /// Creates a scoped view.
  const LScopedView({super.key});

  /// Optional tag for the controller registration.
  String? get tag => null;

  /// Whether the controller should be permanent (defaults to false).
  bool get permanent => false;

  /// Whether to wrap [buildContent] in [LWatch] for automatic rebuilding.
  /// Defaults to `true`.
  bool get autoWatch => true;

  /// Factory method to create the controller.
  ///
  /// This is called exactly once when the scope is initialized.
  T createController();

  /// Builds the UI for the view.
  ///
  /// The [controller] is passed as an argument, fully initialized and ready to use.
  Widget buildContent(BuildContext context, T controller);

  @override
  State<LScopedView<T>> createState() => _LScopedViewState<T>();
}

class _LScopedViewState<T> extends State<LScopedView<T>>
    with _ScopeMixin<LScopedView<T>> {
  late final T _controller;

  void _initScope(BuildContext context) {
    if (_scopeInitialized) return;
    final scopeName = 'LScopedView<${T.toString()}>';
    _scope = _createScope(context, scopeName);
    _controller = widget.createController();
    _scope.put<T>(_controller, tag: widget.tag, permanent: widget.permanent);
    _scopeInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _initScope(context);
    return wrapWithScope(
      widget.autoWatch
          ? LWatch(() => widget.buildContent(context, _controller))
          : widget.buildContent(context, _controller),
    );
  }

  @override
  void dispose() {
    disposeScope();
    super.dispose();
  }
}
