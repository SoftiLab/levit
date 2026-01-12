import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  testWidgets('Stress Test: LStatusBuilder State Switching', (tester) async {
    print(
        '[Description] Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states.');
    const count = 2000;
    // Use Lx<AsyncStatus> directly for manual control
    final statuses = List.generate(
        count, (_) => Lx<AsyncStatus<int>>(const AsyncIdle<int>()));

    // Initial Build (Idle)
    final setupStopwatch = Stopwatch()..start();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (final s in statuses)
              LStatusBuilder<int>(
                source: s,
                onIdle: () =>
                    const Text('Idle', textDirection: TextDirection.ltr),
                onWaiting: () =>
                    const Text('Waiting', textDirection: TextDirection.ltr),
                onSuccess: (v) =>
                    Text('Success $v', textDirection: TextDirection.ltr),
                onError: (e, s) =>
                    const Text('Error', textDirection: TextDirection.ltr),
              )
          ],
        ),
      ),
    ));
    setupStopwatch.stop();
    print(
        'LStatusBuilder Setup: Built $count widgets (Idle) in ${setupStopwatch.elapsedMilliseconds}ms');

    // Measure switching from Idle to Waiting
    final waitStopwatch = Stopwatch()..start();
    // Batch update to trigger them all
    for (final s in statuses) s.value = const AsyncWaiting<int>();
    await tester.pump();
    waitStopwatch.stop();
    print(
        'LStatusBuilder Switch: Switched $count widgets to Waiting in ${waitStopwatch.elapsedMilliseconds}ms');

    // Measure switching to Success
    final successStopwatch = Stopwatch()..start();
    // Resolve all
    for (int i = 0; i < statuses.length; i++) {
      statuses[i].value = AsyncSuccess<int>(i);
    }
    await tester.pump();
    successStopwatch.stop();
    print(
        'LStatusBuilder Switch: Switched $count widgets to Success in ${successStopwatch.elapsedMilliseconds}ms');

    // Measure switching to Error
    final errorStopwatch = Stopwatch()..start();
    for (final s in statuses)
      s.value = AsyncError<int>('Stress Test Error', StackTrace.empty);
    await tester.pump();
    errorStopwatch.stop();
    print(
        'LStatusBuilder Switch: Switched $count widgets to Error in ${errorStopwatch.elapsedMilliseconds}ms');
  });
}
