import 'dart:io';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

// Helper to get current RSS usage in MB
int get currentRss => ProcessInfo.currentRss ~/ (1024 * 1024);

void main() {
  group('Stress Test: Memory Growth', () {
    test('RSS stays bounded during repetitive creates/disposes', () async {
      print(
          '[Description] Long-running test to ensure Resident Set Size (RSS) remains bounded, indicating no major memory leaks in core reactive types.');
      final initialRss = currentRss;
      print('Initial RSS: ${initialRss}MB');

      final rssSamples = <int>[];

      // 100 iterations of creating/disposing 10,000 objects
      const iterations = 100;
      const objectsPerBatch = 10000;

      for (int i = 0; i < iterations; i++) {
        // 1. Create a large batch of reactive objects
        final objects = List.generate(objectsPerBatch, (_) => 0.lx);

        // 2. Do some work (add listeners, update)
        for (final obj in objects) {
          obj.addListener(() {});
          obj.value++;
        }

        // 3. Dispose all
        for (final obj in objects) {
          obj.close();
        }

        // 4. Force GC suggestion (Dart GC is not manual, but we can allow time)
        // In a real stress test, we just check trend.
        if (i % 10 == 0) {
          final current = currentRss;
          rssSamples.add(current);
          print('Iteration $i RSS: ${current}MB');
        }
      }

      final finalRss = currentRss;
      print('Final RSS: ${finalRss}MB');
      print('Samples: $rssSamples');

      // Acceptance Criteria:
      // Memory should not grow effectively unbounded.
      // We allow some growth due to JIT compilation/internal VM caching,
      // but it shouldn't be linear with iterations (e.g. 10x growth).
      // A conservative check: Final RSS should be < 2x Initial + Buffer
      // (Buffer for test runner overhead)

      const bufferMB = 50;
      expect(finalRss, lessThan((initialRss * 2) + bufferMB),
          reason: 'Memory grew significantly, potential leak detected.');
    });
  });
}
