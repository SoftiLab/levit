import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('Stress Test: LWatch Fan-Out', () {
    testWidgets('10,000 observers on a single Lx source', (tester) async {
      print(
          '[Description] Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change.');
      final source = 0.lx;
      final observers = 10000;

      final sw = Stopwatch()..start();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(
                observers,
                (i) => LWatch(() => Text('Obs $i: ${source.value}')),
              ),
            ),
          ),
        ),
      );

      final setupTime = sw.elapsedMilliseconds;
      print('Setup time for $observers LWatch widgets: ${setupTime}ms');

      sw.reset();
      sw.start();

      source.value++;
      await tester.pump();

      final notificationTime = sw.elapsedMilliseconds;
      print(
          'Notification time for $observers LWatch widgets: ${notificationTime}ms');

      sw.reset();
      sw.start();

      source.value++;
      await tester.pump();

      final secondNotificationTime = sw.elapsedMilliseconds;
      print('Second notification time: ${secondNotificationTime}ms');
    });
  });
}
