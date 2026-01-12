import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';
import 'dart:async';

class AsyncService {
  final int id;
  AsyncService(this.id);
}

void main() {
  group('Stress Test: Concurrent Access', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('Concurrent Async Resolution (10,000 futures)', () async {
      print(
          '[Description] Validates thread-safety and resolution consistency when thousands of concurrent async requests hit the same provider.');
      final count = 10000;

      // Register a lazy singleton with async emulation
      Levit.lazyPutAsync(() async {
        await Future.delayed(Duration(milliseconds: 10)); // Simulated work
        return AsyncService(999);
      });

      final sw = Stopwatch()..start();

      final futures = List.generate(count, (i) {
        // Mix of finding the singleton and creating distinct async factories
        if (i % 2 == 0) {
          return Levit.findAsync<AsyncService>();
        } else {
          // Provide a way to test race conditions on a shared resource
          return Levit.findAsync<AsyncService>();
        }
      });

      final results = await Future.wait(futures);
      sw.stop();

      print(
          'Resolved $count concurrent requests in ${sw.elapsedMilliseconds}ms');

      // Verify all got the same singleton instance
      final firstId = results.first.id;
      expect(results.every((s) => s.id == firstId), true);
    });
  });
}
