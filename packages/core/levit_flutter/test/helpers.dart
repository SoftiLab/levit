import 'dart:async';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Test controller for widget tests.
class TestController extends LevitController {
  bool closeCalled = false;
  int count = 0;
  final reactiveCount = 0.lx;

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
  }
}

/// Another test controller for multi-scope tests.
class AnotherController extends LevitController {
  String name = '';
}

/// Simple LView for testing.
class TestLView extends LView<TestController> {
  @override
  bool get autoWatch => false;

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Count: ${controller.count}');
  }
}

/// Tagged LView for testing.
class TaggedLView extends LView<TestController> {
  @override
  String? get tag => 'special';

  @override
  bool get autoWatch => false;

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Count: ${controller.count}');
  }
}

/// LView with createController for testing.
class TestLWidget extends LView<TestController> {
  @override
  TestController? createController() => TestController();

  @override
  bool get autoWatch => false;

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Count: ${controller.count}');
  }
}

/// LView with autoWatch for testing reactivity.
class AutoWatchLView extends LView<TestController> {
  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Reactive: ${controller.reactiveCount.value}');
  }
}

/// Permanent LView for testing.
class PermanentLView extends LView<TestController> {
  @override
  TestController? createController() => TestController();

  @override
  bool get permanent => true;

  @override
  bool get autoWatch => false;

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Text('Permanent: ${controller.count}');
  }
}

/// Stateful widget for testing LStatefulView.
class TestLStatefulWidget extends LStatefulView<TestController> {
  @override
  State<TestLStatefulWidget> createState() => TestLStatefulWidgetState();
}

class TestLStatefulWidgetState
    extends LState<TestLStatefulWidget, TestController> {
  @override
  Widget buildContent(BuildContext context) {
    return Text('Stateful: ${controller.count}');
  }
}

/// Stateful widget with createController for testing.
class StatefulWidgetWithCreate extends LStatefulView<TestController> {
  @override
  TestController? createController() => TestController();

  @override
  State<StatefulWidgetWithCreate> createState() =>
      StatefulWidgetWithCreateState();
}

class StatefulWidgetWithCreateState
    extends LState<StatefulWidgetWithCreate, TestController> {
  @override
  Widget buildContent(BuildContext context) {
    return Text('Created: ${controller.count}');
  }
}

/// Lifecycle stateful widget for testing onInit/onClose.
class LifecycleStatefulWidget extends LStatefulView<TestController> {
  final VoidCallback onInitCallback;
  final VoidCallback onCloseCallback;

  const LifecycleStatefulWidget({
    required this.onInitCallback,
    required this.onCloseCallback,
  });

  @override
  bool get autoWatch => false;

  @override
  State<LifecycleStatefulWidget> createState() =>
      LifecycleStatefulWidgetState();
}

class LifecycleStatefulWidgetState
    extends LState<LifecycleStatefulWidget, TestController> {
  @override
  void onInit() {
    super.onInit();
    widget.onInitCallback();
  }

  @override
  void onClose() {
    widget.onCloseCallback();
    super.onClose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Text('Lifecycle: ${controller.count}');
  }
}

/// AutoWatch stateful widget for testing.
class AutoWatchStatefulWidget extends LStatefulView<TestController> {
  @override
  State<AutoWatchStatefulWidget> createState() =>
      AutoWatchStatefulWidgetState();
}

class AutoWatchStatefulWidgetState
    extends LState<AutoWatchStatefulWidget, TestController> {
  @override
  Widget buildContent(BuildContext context) {
    return Text('Stateful Reactive: ${controller.reactiveCount.value}');
  }
}

/// Test ChangeNotifier for disposal tests.
class TestNotifier extends ChangeNotifier {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

/// Tracking subscription for disposal tests.
class TrackingSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final VoidCallback? _onCancel;
  bool cancelCalled = false;

  TrackingSubscription(this._inner, [this._onCancel]);

  @override
  Future<void> cancel() {
    cancelCalled = true;
    _onCancel?.call();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
