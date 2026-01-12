import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  group('Lx.batchAsync', () {
    test('suppresses notifications during async gaps', () async {
      final a = 0.lx;
      final b = 0.lx;
      int notifications = 0;

      // Listen to both
      a.addListener(() => notifications++);
      b.addListener(() => notifications++);

      await Lx.batchAsync(() async {
        a.value = 1;
        // Should be 0 here as we utilize Zone batching
        expect(notifications, 0, reason: 'Should not notify immediately');

        await Future.delayed(Duration.zero);

        b.value = 1;
        expect(notifications, 0, reason: 'Should not notify after async gap');
      });

      // Should happen after batch completes
      expect(notifications, 2, reason: 'Should flush all notifications');
    });

    test('flushes notifications even on error', () async {
      final a = 0.lx;
      int notifications = 0;
      a.addListener(() => notifications++);

      try {
        await Lx.batchAsync(() async {
          a.value = 1;
          await Future.delayed(Duration.zero);
          throw Exception('Test Error');
        });
      } catch (_) {
        // Expected
      }

      expect(notifications, 1,
          reason: 'Should flush notifications in finally block');
      expect(a.value, 1);
    });

    test('supports nested sync transactions', () async {
      final a = 0.lx;
      final b = 0.lx;
      int aNotifications = 0;
      int bNotifications = 0;
      a.addListener(() => aNotifications++);
      b.addListener(() => bNotifications++);

      await Lx.batchAsync(() async {
        a.value = 1;

        Lx.batch(() {
          b.value = 1;
          b.value = 2; // Should only notify once for 'b'
        });

        // Lx.batch (sync) uses the GLOBAL batch state, which currently pushes to _batchedNotifiers.
        // However, our LxNotifier.notify checks 'asyncBatch' (Zone) FIRST.
        // So even inside Lx.batch(), the Zone check wins if we prioritize it.
        //
        // Let's verify existing behavior:
        // LxNotifier.notify implementation puts Zone check (0) BEFORE Sync check (1).
        // So 'b' updates inside sync batch will ACTUALLY be captured by the ASYNC batch
        // because the Zone is still active!
        // This effectively "promotes" the sync batch content to the surrounding async batch.

        expect(aNotifications, 0);
        expect(bNotifications, 0,
            reason: 'Sync batch should merge into async batch context');
      });

      expect(aNotifications, 1);
      expect(bNotifications,
          1); // Only 1 notification for b (last valid value, deduped)
    });
    test('triggers middleware hooks', () async {
      int startCount = 0;
      int endCount = 0;

      final middleware = _TestMiddleware(
        onStart: () => startCount++,
        onEnd: () => endCount++,
      );

      Lx.addMiddleware(middleware);

      try {
        await Lx.batchAsync(() async {
          expect(startCount, 1,
              reason: 'onBatchStart should be called before execution');
          expect(endCount, 0,
              reason: 'onBatchEnd should NOT be called during execution');
          await Future.delayed(Duration.zero);
        });

        expect(startCount, 1);
        expect(endCount, 1,
            reason: 'onBatchEnd should be called after execution');
      } finally {
        Lx.middlewares.remove(middleware);
      }
    });
  });
}

class _TestMiddleware extends LxMiddleware {
  final void Function() onStart;
  final void Function() onEnd;

  _TestMiddleware({required this.onStart, required this.onEnd});

  @override
  void onBatchStart() => onStart();

  @override
  void onBatchEnd() => onEnd();

  @override
  void onAfterChange<T>(StateChange<T> change) {}
}
