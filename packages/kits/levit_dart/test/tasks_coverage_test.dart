import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController with LevitTasksMixin {}

class TestReactiveController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('levit_dart Coverage Boost', () {
    test('LevitTasksMixin engine.config on double init', () {
      final controller = TestController();
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();

      // Re-initialize to trigger engine.config
      controller.onInit();
    });

    test('LevitReactiveTasksMixin onTaskError setter - Direct Engine Call',
        () async {
      final controller = TestReactiveController();
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();

      bool errorCalled = false;
      controller.onTaskError = (e, s) {
        errorCalled = true;
      };

      // We must call engine.schedule DIRECTLY to bypass runTask's internal onError
      // which would otherwise mask the engine's onTaskError handler.
      try {
        await controller.tasksEngine
            .schedule(() async => throw Exception('raw error'));
      } catch (_) {}

      expect(errorCalled, true,
          reason: "Engine global handler should have been called");

      controller.onTaskError = null;
    });

    test('LevitReactiveTasksMixin onTaskError setter - Via runTask branch',
        () async {
      final controller = TestReactiveController();
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();

      bool errorCalled = false;
      controller.onTaskError = (e, s) {
        errorCalled = true;
      };

      // This hits the onTaskError?.call(e, s) inside runTask's onError wrapper
      try {
        await controller.runTask(() async => throw Exception('runTask error'));
      } catch (_) {}
      expect(errorCalled, true);
    });

    test('LevitTaskEngine cancellation coverage (L221, 231, 262, 310-311)',
        () async {
      final controller = TestReactiveController();
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();

      final completer = Completer<void>();

      // Task that hangs until we complete it
      final taskFuture = controller.runTask(() async {
        await completer.future;
        return 'done';
      }, id: 'cancel_me');

      // Cancel immediately
      controller.cancelTask('cancel_me');
      completer.complete();

      await taskFuture;
    });

    test('LevitTaskEngine cancellation on failure branch (L262)', () async {
      final controller = TestReactiveController();
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();

      final completer = Completer<void>();

      final taskFuture = controller.runTask(() async {
        await completer.future;
        throw Exception('failed');
      }, id: 'fail_cancel');

      controller.cancelTask('fail_cancel');
      completer.complete();

      await taskFuture;
    });
  });
}
