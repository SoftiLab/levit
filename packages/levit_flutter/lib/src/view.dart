import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';
import 'package:levit_flutter/src/watch.dart';
import 'package:levit_flutter/src/scope.dart';

/// A base [StatelessWidget] for UI components that depend on a controller.
///
/// [LView] simplifies the access to business logic by automatically finding
/// a controller of type [T] from the dependency injection system (nearest
/// [LScope] or global [Levit]).
///
/// ### Usage
/// ```dart
/// class MyPage extends LView<MyController> {
///   @override
///   Widget buildContent(BuildContext context, MyController controller) {
///     return Text(controller.title.value);
///   }
/// }
/// ```
///
/// ### Important Considerations
/// By default, [LView] wraps its [buildContent] in an [LWatch]. This means
/// any reactive variables accessed during build will trigger a rebuild.
/// Set [autoWatch] to `false` to disable this behavior.
///
/// [LView] does **not** manage the lifecycle of the controller. For transient
/// controllers that should be disposed with the view, use [LScopedView].
abstract class LView<T> extends StatelessWidget {
  /// Optional key to use for resolving the controller.
  String? get tag => null;

  /// Optional factory to create the controller if it's not found in DI.
  T? createController() => null;

  /// If `true`, the controller created via [createController] persists resets.
  bool get permanent => false;

  /// If `true`, wraps [buildContent] in an [LWatch]. Defaults to `true`.
  bool get autoWatch => true;

  /// Creates a view with automatic controller resolution.
  const LView({super.key});

  /// Override this method to build your widget tree.
  ///
  /// The [controller] is automatically injected.
  Widget buildContent(BuildContext context, T controller);

  @override
  Widget build(BuildContext context) {
    final T controller;
    final scope = LScope.of(context);
    if (scope != null) {
      final instance = scope.findOrNull<T>(tag: tag);
      if (instance != null) {
        controller = instance;
      } else {
        controller = scope.put<T>(() {
          final created = createController();
          if (created == null) {
            throw StateError(
                'LView: Controller $T not found and createController() returned null.');
          }
          return created;
        }, tag: tag, permanent: permanent);
      }
    } else {
      final instance = Levit.findOrNull<T>(tag: tag);
      if (instance != null) {
        controller = instance;
      } else {
        controller = Levit.put<T>(() {
          final created = createController();
          if (created == null) {
            throw StateError(
                'LView: Controller $T not found and createController() returned null.');
          }
          return created;
        }, tag: tag, permanent: permanent);
      }
    }

    if (autoWatch) {
      return LWatch(() => buildContent(context, controller));
    }
    return buildContent(context, controller);
  }
}

/// A base [StatefulWidget] that integrates with the Levit controller system.
///
/// Use [LStatefulView] when you need the full lifecycle of a [StatefulWidget]
/// (e.g., `initState`, `dispose`) in addition to accessing a controller.
abstract class LStatefulView<T> extends StatefulWidget {
  /// Optional tag to use when finding the controller.
  String? get tag => null;

  /// Optional factory to create the controller if it's not found.
  T? createController() => null;

  /// Whether the controller created via [createController] should be permanent.
  bool get permanent => false;

  /// Whether to wrap `buildContent` in [LWatch] for automatic rebuilding.
  bool get autoWatch => true;

  /// Creates a stateful view.
  const LStatefulView({super.key});
}

/// The base [State] class for [LStatefulView].
abstract class LState<W extends LStatefulView<T>, T> extends State<W> {
  LState();

  /// The controller instance resolved from the dependency injection system.
  T get controller {
    if (context.levit.isRegistered<T>(tag: widget.tag)) {
      return context.levit.find<T>(tag: widget.tag);
    }

    return context.levit.put<T>(() {
      final created = widget.createController();
      if (created == null) {
        throw StateError(
            'LStatefulView: Controller $T not found and createController() returned null.');
      }
      return created;
    }, tag: widget.tag, permanent: widget.permanent);
  }

  /// Called immediately after [initState].
  void onInit() {}

  /// Called immediately before `dispose`.
  void onClose() {}

  @override
  void initState() {
    super.initState();
    onInit();
  }

  @override
  void dispose() {
    onClose();
    super.dispose();
  }

  /// Override this method to build your widget tree.
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (widget.autoWatch) {
      return LWatch(() => buildContent(context));
    }
    return buildContent(context);
  }
}
