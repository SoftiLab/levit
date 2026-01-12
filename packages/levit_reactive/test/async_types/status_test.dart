import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('AsyncStatus/LxFuture', () {
    test('LxFuture.idle starts with idle status', () {
      final future = LxFuture<int>.idle(initial: 0);
      expect(future.valueOrNull, equals(0));
    });
  });
  group('progress getter coverage', () {
    test('AsyncWaiting returns progress', () {
      final status = AsyncWaiting<int>(null, 0.5);
      final lx = Lx<AsyncStatus<int>>(status);
      expect(lx.progress, 0.5);
    });

    test('AsyncSuccess returns 1.0', () {
      final status = AsyncSuccess<int>(10);
      final lx = Lx<AsyncStatus<int>>(status);
      expect(lx.progress, 1.0);
    });

    test('AsyncIdle returns null', () {
      final status = const AsyncIdle<int>();
      final lx = Lx<AsyncStatus<int>>(status);
      expect(lx.progress, isNull);
    });

    test('AsyncError returns null', () {
      final status = AsyncError<int>("error");
      final lx = Lx<AsyncStatus<int>>(status);
      expect(lx.progress, isNull);
    });
  });
}
