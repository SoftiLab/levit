import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Dynamic Graph Churn', () {
    test('Subscription graph changes rapidly under load', () {
      final selector = 0.lx;
      final source1 = 0.lx;
      final source2 = 0.lx;

      const nodeCount = 1000;
      final nodes = List.generate(nodeCount, (i) {
        return LxComputed(() {
          // Dynamic dependency switch based on selector.value
          if (selector.value % 2 == 0) {
            return source1.value + i;
          } else {
            return source2.value + i;
          }
        });
      });

      final disposers = <Function>[];
      for (final node in nodes) {
        disposers.add(watch(node, (_) {}));
      }

      final stopwatch = Stopwatch()..start();
      print(
          '[Description] Stresses subscriber management by rapidly reconfiguring the dependency graph under load.');
      const iterations = 10000;

      for (int i = 0; i < iterations; i++) {
        Lx.batch(() {
          selector.value = i;
          source1.value = i * 2;
          source2.value = i * 3;
        });
      }

      stopwatch.stop();
      print(
          'Dynamic Graph Churn: $iterations iterations with $nodeCount nodes in ${stopwatch.elapsedMilliseconds}ms');

      // Verify final state
      if (iterations % 2 == 0) {
        // selector.value = iterations - 1 (odd) -> uses source2
        final lastI = iterations - 1;
        expect(nodes[0].value, (lastI * 3) + 0);
      }

      for (final dispose in disposers) {
        dispose();
      }
    });
  });
}
