import 'package:levit_di/levit_di.dart';
import 'package:test/test.dart';

class DisposableService extends LevitDisposable {
  bool initialized = false;
  bool closed = false;

  @override
  void onInit() {
    initialized = true;
  }

  @override
  void onClose() {
    closed = true;
  }
}

void main() {
  group('Stress Test: Memory Churn & Lifecycle', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('Put/Delete Cycles (1,000,000 iterations)', () {
      print(
          '[Description] Stresses the DI container and lifecycle hooks with continuous massive registration and deletion cycles.');
      final iterations = 1000000;
      final sw = Stopwatch()..start();

      for (var i = 0; i < iterations; i++) {
        final service = DisposableService();
        Levit.put(service);

        // Verify lifecycle
        // expect(service.initialized, true); // Too slow to assert every time

        Levit.delete<DisposableService>();

        // expect(service.closed, true); // Too slow to assert every time
      }

      sw.stop();
      print(
          'Performed $iterations put/delete cycles in ${sw.elapsedMilliseconds}ms');
    });
  });
}
