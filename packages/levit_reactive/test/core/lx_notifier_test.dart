import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxNotifier', () {
    test('notify calls all listeners', () {
      final notifier = LxNotifier();
      var count = 0;
      notifier.addListener(() => count++);
      notifier.addListener(() => count++);

      notifier.notify();
      expect(count, equals(2));
    });

    test('removeListener works', () {
      final notifier = LxNotifier();
      var count = 0;
      void listener() => count++;

      notifier.addListener(listener);
      notifier.notify();
      expect(count, equals(1));

      notifier.removeListener(listener);
      notifier.notify();
      expect(count, equals(1)); // No change
    });

    test('dispose clears listeners', () {
      final notifier = LxNotifier();
      var count = 0;
      notifier.addListener(() => count++);

      notifier.dispose();
      notifier.notify();
      expect(count, equals(0));
    });

    test('isDisposed returns correct value', () {
      final notifier = LxNotifier();
      expect(notifier.isDisposed, isFalse);

      notifier.dispose();
      expect(notifier.isDisposed, isTrue);
    });

    test('addListener ignored after dispose', () {
      final notifier = LxNotifier();
      notifier.dispose();

      var called = false;
      notifier.addListener(() => called = true);
      notifier.notify();

      expect(called, isFalse);
    });
  });
}
