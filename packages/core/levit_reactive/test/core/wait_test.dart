import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxFuture.wait', () {
    test('returns active future when running', () async {
      final completer = Completer<int>();
      final lx = LxFuture(completer.future);

      final future = lx.wait;
      completer.complete(42);

      expect(await future, 42);
    });

    test('returns active future if running (even with initial)', () async {
      final lx = LxFuture(Future.value(42), initial: 10);
      expect(await lx.wait, 42); // Waits for the active future
    });

    test('returns immediate future if already successful (idle)', () async {
      final lx = LxFuture<int>.idle(initial: 10);
      expect(await lx.wait, 10);
    });

    test('throws if idle and no value', () {
      final lx = LxFuture<int>.idle();
      expect(() => lx.wait, throwsStateError);
    });
  });

  group('LxStream.wait', () {
    test('waits for next value if pending', () async {
      final controller = StreamController<int>();
      final lx = LxStream(controller.stream);

      final future = lx.wait;
      controller.add(42);

      expect(await future, 42);
    });

    test('returns immediate future if already successful', () async {
      final controller = StreamController<int>();
      final lx = LxStream(controller.stream, initial: 10);

      expect(await lx.wait, 10);
    });
  });
}
