import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class _TrackingMiddleware extends LxMiddleware {
  int beforeCount = 0;
  int afterCount = 0;

  @override
  bool onBeforeChange<T>(StateChange<T> change) {
    beforeCount++;
    return true;
  }

  @override
  void onAfterChange<T>(StateChange<T> change) {
    afterCount++;
  }

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}

  void reset() {
    beforeCount = 0;
    afterCount = 0;
  }
}

void main() {
  group('Middleware Bypass', () {
    late _TrackingMiddleware tracker;

    setUp(() {
      tracker = _TrackingMiddleware();
      Lx.middlewares.clear();
      Lx.middlewares.add(tracker);
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    test('runWithoutMiddleware prevents middleware execution', () {
      final count = 0.lx;

      // Normal update
      count.value = 1;
      expect(tracker.beforeCount, equals(1));
      expect(tracker.afterCount, equals(1));
      expect(count.value, equals(1));

      // Bypassed update
      Lx.runWithoutMiddleware(() {
        count.value = 2;
      });

      expect(tracker.beforeCount, equals(1),
          reason: 'Should not increment beforeCount');
      expect(tracker.afterCount, equals(1),
          reason: 'Should not increment afterCount');
      expect(count.value, equals(2), reason: 'Value should still update');
    });

    test('bypassed update correctly notifies listeners', () {
      final count = 0.lx;
      int listenerCount = 0;
      count.addListener(() => listenerCount++);

      Lx.runWithoutMiddleware(() {
        count.value = 5;
      });

      expect(count.value, equals(5));
      expect(listenerCount, equals(1));
    });

    test('Undo with LxHistoryMiddleware does not trigger other middlewares',
        () {
      final history = LxHistoryMiddleware();
      // Add tracker AFTER history to ensure it would normally catch events
      Lx.middlewares.add(history);

      final count = 0.lx;
      count.value = 1;

      expect(tracker.beforeCount, equals(1));
      expect(tracker.afterCount, equals(1));
      expect(history.length, equals(1));

      // Check Undo behavior
      tracker.reset();

      // Undo should bypass normal middleware recording loop because
      // LxHistoryMiddleware uses runWithoutMiddleware internally now
      history.undo();

      expect(count.value, equals(0));
      // These should remain 0 if bypass is working!
      expect(tracker.beforeCount, equals(0));
      expect(tracker.afterCount, equals(0));
    });
  });
}
