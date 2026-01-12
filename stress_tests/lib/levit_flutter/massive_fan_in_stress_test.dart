import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('Stress Test: LWatch Fan-In', () {
    testWidgets('One LWatch observing 2,000 sources', (tester) async {
      print(
          '[Description] Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates.');
      final sources = List.generate(2000, (i) => i.lx);

      final sw = Stopwatch()..start();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            int sum = 0;
            for (final s in sources) {
              sum += s.value;
            }
            return Text('Sum: $sum');
          }),
        ),
      );

      final setupTime = sw.elapsedMilliseconds;
      print('Initial build with 2000 dependencies: ${setupTime}ms');

      sw.reset();
      sw.start();

      sources[0].value++;
      await tester.pump();

      final updateTime = sw.elapsedMilliseconds;
      print('Update time for 2000 dependencies: ${updateTime}ms');

      sw.reset();
      sw.start();

      // Change many sources at once
      for (var i = 0; i < 100; i++) {
        sources[i].value++;
      }
      await tester.pump();

      final batchUpdateTime = sw.elapsedMilliseconds;
      print('Batch update (100) time: ${batchUpdateTime}ms');
    });
  });
}
