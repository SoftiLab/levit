import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Rapid Mutation', () {
    test('1,000 rapid updates across 100 sources', () async {
      print(
          '[Description] Measures propagation speed of a massive volume of individual updates across many parallel sources.');
      final sources = List.generate(100, (i) => i.lx);
      final sum = LxComputed(() => sources.fold(0, (acc, s) => acc + s.value));

      int notifyCount = 0;
      sum.addListener(() => notifyCount++);

      // Warm up
      expect(sum.value, 4950); // sum(0..99)

      final stopWatch = Stopwatch()..start();
      const updatesPerSource = 10;

      for (int i = 0; i < updatesPerSource; i++) {
        for (final s in sources) {
          s.value++;
        }
      }

      print(
          'Performed ${sources.length * updatesPerSource} updates in ${stopWatch.elapsedMilliseconds}ms');

      // Ensure consistency
      expect(sum.value, 4950 + (sources.length * updatesPerSource));
      // Since they are sync notifications, notifyCount should be equals to number of updates
      // unless batched.
      expect(notifyCount, greaterThan(0));

      sum.close();
    });

    test('Rapid mutation with batching', () async {
      print(
          '[Description] Benchmarks the efficiency gain and single-notification guarantee of using large batch updates.');
      final sources = List.generate(100, (i) => i.lx);
      final sum = LxComputed(() => sources.fold(0, (acc, s) => acc + s.value));

      int notifyCount = 0;
      sum.addListener(() => notifyCount++);

      // Warm up
      expect(sum.value, 4950);
      notifyCount = 0;

      Lx.batch(() {
        for (int i = 0; i < 100; i++) {
          for (final s in sources) {
            s.value++;
          }
        }
      });

      expect(notifyCount, 1, reason: 'Should only notify once after batch');
      expect(sum.value, 4950 + (100 * 100));

      sum.close();
    });

    test('Thundering Herd: many reactive nodes reacting to same sources',
        () async {
      print(
          '[Description] Tests the scalability of the notification system when a single update triggers thousands of dependent reactive nodes simultaneously.');
      final a = 0.lx;
      final b = 0.lx;

      const nodeCount = 1000;
      final nodes = List.generate(nodeCount, (i) {
        return LxComputed(() => a.value + b.value + i);
      });

      // Initialize
      for (final n in nodes) n.value;

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        Lx.batch(() {
          a.value++;
          b.value++;
        });
      }
      // Access values to trigger re-computation of lazy nodes within the stopwatch
      for (final n in nodes) {
        n.value;
      }
      sw.stop();

      print(
          'Thundering herd (100 batches, 1k nodes) took ${sw.elapsedMicroseconds}us');

      for (int i = 0; i < nodeCount; i++) {
        expect(nodes[i].value, 100 + 100 + i);
      }

      for (final n in nodes) n.close();
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
