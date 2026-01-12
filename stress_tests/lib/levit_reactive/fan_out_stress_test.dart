import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Massive Fan-Out', () {
    test('100,000 observers on a single Lx source', () {
      print(
          '[Description] Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source.');
      final source = 0.lx;
      const observerCount = 100000;
      int totalNotifications = 0;

      final stopWatch = Stopwatch()..start();

      final disposers = List.generate(observerCount, (i) {
        return watch(source, (v) {
          totalNotifications++;
        });
      });

      final setupTime = stopWatch.elapsedMilliseconds;
      print('Setup time for $observerCount observers: ${setupTime}ms');

      // Trigger change
      stopWatch.reset();
      source.value = 1;

      final notificationTime = stopWatch.elapsedMilliseconds;
      print(
          'Notification time for $observerCount observers: ${notificationTime}ms');

      expect(totalNotifications, observerCount);

      // Verify second update
      stopWatch.reset();
      source.value = 2;
      expect(totalNotifications, observerCount * 2);
      print('Second notification time: ${stopWatch.elapsedMilliseconds}ms');

      // Cleanup
      stopWatch.reset();
      for (final dispose in disposers) {
        dispose();
      }
      print('Cleanup time: ${stopWatch.elapsedMilliseconds}ms');

      // Verify no more notifications
      source.value = 3;
      expect(totalNotifications, observerCount * 2);
    });

    test('Massive Fan-Out with LxComputed', () {
      print(
          '[Description] Benchmarks the resolution and memory overhead of thousands of computed nodes depending on the same source.');
      final source = 0.lx;
      const count = 10000; // 10k computed for quicker test

      final computeds = List.generate(count, (i) {
        return LxComputed(() => source.value + i);
      });

      // Initial access
      for (final c in computeds) {
        c.value;
      }

      source.value = 10;

      for (int i = 0; i < count; i++) {
        expect(computeds[i].value, 10 + i);
      }

      for (final c in computeds) {
        c.close();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
