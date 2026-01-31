import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void _noopLoopBody() {}

class TestLoopController extends LevitController with LevitLoopExecutionMixin {}

void main() {
  group('LevitLoopExecutionMixin Isolate Coverage', () {
    test('stop an isolate loop while it is paused', () async {
      final controller = TestLoopController();
      controller.onInit();

      // Start an isolate loop
      controller.loopEngine.startIsolateLoop('test_loop', _noopLoopBody,
          delay: const Duration(milliseconds: 10));

      // Wait for it to start
      await Future.delayed(const Duration(milliseconds: 50));

      // Pause it
      controller.loopEngine.pauseService('test_loop');
      await Future.delayed(const Duration(milliseconds: 20));

      // Stop it while paused (This should hit the cleanup path for pauseCompleter in isolate)
      controller.loopEngine.stopService('test_loop');

      expect(controller.loopEngine.getServiceStatus('test_loop'), isNull);

      controller.onClose();
    });
  });
}
