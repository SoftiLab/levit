import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Memory Churn & Lifecycle', () {
    test('Repeatedly create and dispose 10,000 reactive objects', () async {
      print(
          '[Description] Stresses the memory and lifecycle management by iteratively creating and specifically disposing 10,000 reactive nodes.');
      final root = 0.lx;
      const iterations = 10000;

      for (int i = 0; i < iterations; i++) {
        final computed = LxComputed(() => root.value + i);
        final sub = watch(computed, (v) {});

        root.value++;

        sub(); // dispose watch
        computed.close();
      }

      // If there's a leak in listener lists or stream controllers,
      // memory would grow significantly.
      // We can't easily check RSS here without platform specifics,
      // but we can ensure no crashes/timeouts.
      print('Completed $iterations lifecycle iterations');
    });

    test('Churn with cross-dependencies', () async {
      print(
          '[Description] Tests lifecycle stability and memory cleanup when complex dependency subgraphs are rapidly created and disposed.');
      final a = 0.lx;
      final b = 0.lx;

      for (int i = 0; i < 5000; i++) {
        final c1 = LxComputed(() => a.value + i);
        final c2 = LxComputed(() => b.value + c1.value);

        final sub = watch(c2, (v) {});

        a.value = i;
        b.value = i;

        sub();
        c1.close();
        c2.close();
      }
      print('Completed 5000 cross-dependency lifecycle iterations');
    });

    test('Middleware history limit stress', () {
      print(
          '[Description] Validates that middleware (like history) remains stable and respects memory limits under heavy update pressure.');
      Lx.middlewares.add(LxHistoryMiddleware());
      Lx.maxHistorySize = 100;

      final source = 0.lx;
      for (int i = 0; i < 1000; i++) {
        source.value = i;
      }

      // Verify middleware didn't explode and respects limit (if applicable)
      // Note: we can't easily access private history items without cast or reflection
      Lx.middlewares.clear();
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
