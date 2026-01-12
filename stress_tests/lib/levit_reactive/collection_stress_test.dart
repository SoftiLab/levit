import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:math';

void main() {
  group('Stress Test: Collection Bulk Operations', () {
    test('LxList with 1,000,000 items and bulk mutations', () {
      print(
          '[Description] Measures performance of bulk assignments and rapid random mutations on very large reactive lists.');
      final list = List.generate(1000000, (i) => i).lx;

      int notifyCount = 0;
      list.addListener(() => notifyCount++);

      final sw = Stopwatch()..start();

      // Bulk update
      list.assign(List.generate(1000000, (i) => i * 2));
      print('Large list assign (1M items) took ${sw.elapsedMilliseconds}ms');

      expect(notifyCount, 1);
      expect(list[500000], 1000000);

      // Rapid small mutations
      sw.reset();
      final random = Random();
      for (int i = 0; i < 1000; i++) {
        list[random.nextInt(1000000)] = i;
      }
      print(
          '1,000 random mutations on 1M list took ${sw.elapsedMilliseconds}ms');
      expect(notifyCount, 1001);
    });

    test('LxMap with 100,000 unique keys', () {
      print(
          '[Description] Benchmarks insertion and clearing speed for reactive maps with a large number of unique entries.');
      final map = <String, int>{}.lx;
      int notifyCount = 0;
      map.addListener(() => notifyCount++);

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100000; i++) {
        map['key_$i'] = i;
      }
      print('100,000 map insertions took ${sw.elapsedMilliseconds}ms');
      expect(notifyCount, 100000);
      expect(map.length, 100000);

      sw.reset();
      map.clear();
      sw.stop();
      print('100,000 map clear took ${sw.elapsedMicroseconds}us');
      expect(notifyCount, 100001);
    });

    test('Collection change propagation to computed', () {
      print(
          '[Description] Validates that bulk mutations in reactive collections correctly and efficiently propagate to dependent computed values.');
      final list = <int>[].lx;
      final sum = LxComputed(() => list.fold(0, (acc, e) => acc + e));

      // Initialize
      expect(sum.value, 0);

      final sw = Stopwatch()..start();
      Lx.batch(() {
        for (int i = 0; i < 10000; i++) {
          list.add(i);
        }
      });
      // Trigger lazy computation within the stopwatch
      sum.value;
      sw.stop();

      print(
          'Batch add 10,000 items + computed sum took ${sw.elapsedMilliseconds}ms');

      expect(sum.value, 49995000); // sum(0..9999)

      list.close();
      sum.close();
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
