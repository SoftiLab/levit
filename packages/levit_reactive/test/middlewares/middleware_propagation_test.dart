import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class _TrackingMiddleware extends LxMiddleware {
  final String id;
  int beforeCount = 0;
  int afterCount = 0;
  bool shouldStopBefore = false;
  bool shouldStopAfter = false;

  _TrackingMiddleware(this.id);

  @override
  bool onBeforeChange<T>(StateChange<T> change) {
    beforeCount++;
    if (shouldStopBefore) change.stopPropagation();
    return true;
  }

  @override
  void onAfterChange<T>(StateChange<T> change) {
    afterCount++;
    if (shouldStopAfter) change.stopPropagation();
  }

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}

  void reset() {
    beforeCount = 0;
    afterCount = 0;
    shouldStopBefore = false;
    shouldStopAfter = false;
  }
}

void main() {
  group('Middleware Propagation', () {
    late _TrackingMiddleware mw1;
    late _TrackingMiddleware mw2;

    setUp(() {
      mw1 = _TrackingMiddleware('1');
      mw2 = _TrackingMiddleware('2');
      Lx.middlewares.clear();
      Lx.middlewares.add(mw1);
      Lx.middlewares.add(mw2);
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    test('Normal flow notifies all middlewares', () {
      final count = 0.lx;
      count.value = 1;

      expect(mw1.beforeCount, equals(1));
      expect(mw2.beforeCount, equals(1));
      expect(mw1.afterCount, equals(1));
      expect(mw2.afterCount, equals(1));
    });

    test('stopPropagation in onBeforeChange stops subsequent middlewares', () {
      mw1.shouldStopBefore = true;
      final count = 0.lx;
      count.value = 1;

      // MW1 runs
      expect(mw1.beforeCount, equals(1));
      // MW2 should NOT run
      expect(mw2.beforeCount, equals(0),
          reason: 'MW2 before should be skipped');

      // Value still updates
      expect(count.value, equals(1));

      // After hooks: MW1 runs (since it successfully processed before),
      // but logic dictates the change happened.
      // Does stopPropagation apply to the entire event lifecycle or just the loop?
      // Implementation: It's per-loop check. If stopped in Before loop,
      // the flag persists to After loop?
      // Let's check logic: _propagationStopped is on the change object.
      // So if set to true in Before loop, it is true when After loop starts.

      expect(mw1.afterCount, equals(1),
          reason: 'MW1 after should run since it processed');
      expect(mw2.afterCount, equals(0),
          reason: 'MW2 after should be skipped because flag persists');
    });

    test('stopPropagation in onAfterChange stops subsequent middlewares', () {
      mw1.shouldStopAfter = true;
      final count = 0.lx;
      count.value = 1;

      // Both run Before
      expect(mw1.beforeCount, equals(1));
      expect(mw2.beforeCount, equals(1));

      // MW1 runs After and stops
      expect(mw1.afterCount, equals(1));
      // MW2 After blocked
      expect(mw2.afterCount, equals(0));
    });
  });
}
