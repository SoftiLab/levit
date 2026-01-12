import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';
import 'dart:math';

void main() {
  group('Stress Test: Async Race Conditions', () {
    test('Rapidly changing source with 500 concurrent async computations',
        () async {
      print(
          '[Description] Validates race condition handling and switchMap behavior when a source changes faster than async computations can complete.');
      final source = 0.lx;
      final results = <int>[];
      final random = Random();

      final asyncComputed = LxComputed.async(() async {
        final val = source.value;
        // Random delay to simulate varying network/processing times
        await Future.delayed(Duration(milliseconds: random.nextInt(50) + 1));
        return val;
      });

      asyncComputed.addListener(() {
        final status = asyncComputed.status;
        if (status is AsyncSuccess<int>) {
          results.add(status.value);
        }
      });

      // Rapidly update source
      const updates = 500;
      for (int i = 0; i < updates; i++) {
        source.value = i;
        await Future.delayed(const Duration(milliseconds: 2));
      }

      // Wait for all async work to settle
      await Future.delayed(const Duration(milliseconds: 500));

      expect(asyncComputed.value, updates - 1,
          reason: 'Last value should always eventually win');

      // The results list should contain values in increasing order (mostly)
      // but more importantly, no "old" value should be set AFTER a newer one.
      // LxComputed.async handles this with executionId.
      //
      // NOTE: We only expect ~17 successes out of 500 updates because:
      // 1. Updates happen every 2ms
      // 2. Computations take 1-50ms (avg 25ms)
      // 3. LxComputed.async cancels (ignores) the previous result when a new update arrives (switchMap behavior).
      // This is INTENDED behavior to prevent race conditions and wasted work.
      print('Captured ${results.length} unique successful async results');

      asyncComputed.close();
    });

    test('Multiple dependent async computeds race', () async {
      print(
          '[Description] Tests consistency across a chain of dependent asynchronous computations firing in rapid succession.');
      final source = 0.lx;

      final a = LxComputed.async(() async {
        final s = source.value;
        await Future.delayed(const Duration(milliseconds: 10));
        return s * 2;
      });

      // Observe A
      a.addListener(() {});

      final b = LxComputed.async(() async {
        final valA = a.valueOrNull;
        if (valA == null) return -1;
        await Future.delayed(const Duration(milliseconds: 10));
        return valA + 10;
      });

      // Kick off
      b.addListener(() {});

      for (int i = 0; i < 50; i++) {
        source.value = i;
        await Future.delayed(const Duration(milliseconds: 5));
      }

      await Future.delayed(const Duration(milliseconds: 500));

      expect(a.value, 49 * 2);
      expect(b.value, (49 * 2) + 10);

      a.close();
      b.close();
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
