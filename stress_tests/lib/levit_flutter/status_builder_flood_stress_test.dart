import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('Stress Test: LStatusBuilder Flood', () {
    testWidgets('Switching 10,000 status builders in a single frame',
        (tester) async {
      print(
          '[Description] Measures the UI overhead of switching 10,000 LStatusBuilder widgets between states simultaneously.');
      // Use AsyncIdle directly
      final statuses = List.generate(
          10000, (_) => Lx<AsyncStatus<int>>(const AsyncIdle<int>()));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                return LStatusBuilder<int>(
                  source: statuses[index],
                  onIdle: () => const Text('Idle'),
                  onWaiting: () => const Text('Waiting'),
                  onSuccess: (val) => Text('Success $val'),
                  onError: (err, stack) => Text('Error $err'),
                );
              },
            ),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Flood ALL statuses with success
      Lx.batch(() {
        for (int i = 0; i < statuses.length; i++) {
          statuses[i].value = AsyncSuccess<int>(i);
        }
      });

      await tester.pump();

      stopwatch.stop();
      print(
          'LStatusBuilder Flood (Success): 10,000 widgets switched in ${stopwatch.elapsedMilliseconds}ms');

      // Flood ALL statuses with error
      stopwatch.reset();
      stopwatch.start();

      Lx.batch(() {
        for (int i = 0; i < statuses.length; i++) {
          statuses[i].value = AsyncError<int>('Error $i');
        }
      });

      await tester.pump();

      stopwatch.stop();
      print(
          'LStatusBuilder Flood (Error): 10,000 widgets switched in ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
