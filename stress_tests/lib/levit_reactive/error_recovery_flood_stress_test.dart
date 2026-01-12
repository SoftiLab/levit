import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Error Recovery Flood', () {
    test('System remains stable under flood of errors', () {
      print(
          '[Description] Validates stability and recovery when thousands of synchronous errors are triggered simultaneously.');
      final source = 0.lx;

      const nodeCount = 5000;
      final nodes = List.generate(nodeCount, (i) {
        return LxComputed(() {
          if (source.value == 1) {
            throw Exception('Error from node $i');
          }
          return source.value + i;
        });
      });

      // ignore: unused_local_variable
      int errorCount = 0;
      int successCount = 0;
      final disposers = <Function>[];
      for (final node in nodes) {
        disposers.add(watch(node, (val) {
          successCount++;
        }, onProcessingError: (err, stack) {
          errorCount++;
        }));
      }

      // Initial computed values are already present, so the watchers might have fired
      // during watch() registration if they were considered "new"?
      // Actually watch() calls the listener once internally during registration for sync path?
      // No, let's check worker.dart. It does NOT call it initially.

      final stopwatch = Stopwatch()..start();

      // Stage 1: Success transition (0 -> 2)
      successCount = 0;
      source.value = 2;
      expect(successCount, nodeCount, reason: 'Initial success transition');

      // Stage 2: Error transition (2 -> 1)
      errorCount = 0;
      try {
        source.value = 1;
      } catch (_) {}

      stopwatch.stop();
      print(
          'Error Flood: $nodeCount errors triggered in ${stopwatch.elapsedMilliseconds}ms');

      // Stage 3: Recovery (1 -> 0)
      stopwatch.reset();
      stopwatch.start();

      successCount = 0;
      source.value = 0;

      stopwatch.stop();
      print(
          'Recovery Flood: $nodeCount nodes recovered in ${stopwatch.elapsedMilliseconds}ms');
      expect(successCount, nodeCount, reason: 'Recovery transition');

      for (final dispose in disposers) {
        dispose();
      }
    });

    test('Thundering error herd with deep chains', () {
      print(
          '[Description] Tests error propagation and recovery across deep dependency chains.');
      final root = 0.lx;

      // Deep chain of errors
      LxComputed<int> current = LxComputed(() {
        if (root.value == 1) throw Exception('Root error');
        return root.value;
      });

      const chainDepth = 500;
      for (int i = 0; i < chainDepth; i++) {
        final last = current;
        current = LxComputed(() => last.value + 1);
      }

      Object? capturedError;
      int? successValue;
      final dispose = watch(current, (v) {
        successValue = v;
      }, onProcessingError: (e, s) => capturedError = e);

      // 0 -> 2 (Setup)
      root.value = 2;
      expect(successValue, 2 + chainDepth);

      // 2 -> 1 (Error)
      try {
        root.value = 1;
      } catch (e) {
        capturedError ??= e;
      }
      expect(capturedError, isNotNull, reason: 'Should have captured error');

      // 1 -> 0 (Recovery)
      successValue = null;
      root.value = 0;
      expect(successValue, chainDepth,
          reason: 'Success value should be propagated');
      expect(current.value, chainDepth,
          reason: 'Current value should be recovered');

      dispose();
    });
  });
}
