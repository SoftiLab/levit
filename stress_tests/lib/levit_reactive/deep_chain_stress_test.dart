import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Deep Dependency Chain', () {
    test('10,000 nodes deep chain propagates changes correctly', () {
      print(
          '[Description] Stresses the notification system by propagating a single change through a 10,000-node deep synchronous dependency chain.');
      const depth = 10000;
      final root = 0.lx;

      final stopwatch = Stopwatch()..start();

      LxComputed<int> current = LxComputed(() => root.value + 1);

      final disposers = <Function>[];

      // Activate root-dependent
      disposers.add(watch(current, (_) {}));

      for (int i = 0; i < depth - 1; i++) {
        final last = current;
        current = LxComputed(() => last.value + 1);
        // Activate each node incrementally to avoid stack overflow during "pull" phase
        disposers.add(watch(current, (_) {}));
      }

      stopwatch.stop();
      print(
          'Deep Chain Setup: Created $depth computed nodes in ${stopwatch.elapsedMilliseconds}ms');

      // Initial state
      expect(current.value, depth);

      // Update root - THIS triggers the propagation stress test
      stopwatch.reset();
      stopwatch.start();

      root.value = 10;
      final result = current.value;

      stopwatch.stop();
      print(
          'Deep Chain Propagation: Propagated change through $depth nodes in ${stopwatch.elapsedMilliseconds}ms');

      // Verify propagation
      expect(result, 10 + depth);

      // Large update
      root.value = 1000;
      expect(current.value, 1000 + depth);

      for (final dispose in disposers) {
        dispose();
      }

      // Cleanup
      // In a real app we'd close them, but for stress test we want to see if GC handles it
      // or if we hit limits. However, LxComputed is lazy until listened to or accessed.
      // Here we access .computedValue which triggers computation.
    });

    test('Deeply nested batch updates with deep chains', () async {
      print(
          '[Description] Validates that nested batch updates correctly suppress notifications until the outermost batch completes, even with deep chains.');
      final a = 0.lx;
      final b = 0.lx;

      // Let's do a simpler deep chain for nesting test
      LxComputed<int> currentA = LxComputed(() => a.value + 1);
      LxComputed<int> currentB = LxComputed(() => b.value + 1);

      for (int i = 0; i < 500; i++) {
        final lastA = currentA;
        currentA = LxComputed(() => lastA.value + 1);
        final lastB = currentB;
        currentB = LxComputed(() => lastB.value + 1);
      }

      int notifyCount = 0;
      currentA.addListener(() => notifyCount++);
      currentB.addListener(() => notifyCount++);
      await Future.delayed(
          Duration(milliseconds: 10)); // Let initial notifications clear
      notifyCount = 0;

      Lx.batch(() {
        a.value = 100;
        Lx.batch(() {
          b.value = 200;
          a.value = 300;
        });
        expect(notifyCount, 0, reason: 'Actual: $notifyCount');
      });

      expect(notifyCount, 2);
      expect(currentA.value, 300 + 500 + 1);
      expect(currentB.value, 200 + 500 + 1);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
