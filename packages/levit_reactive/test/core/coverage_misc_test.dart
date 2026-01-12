import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class RejectMiddleware extends LxMiddleware {
  @override
  bool onBeforeChange<T>(StateChange<T> change) => false;

  @override
  void onAfterChange<T>(StateChange<T> change) {}

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}
}

class SimpleMiddleware extends LxMiddleware {
  final List<StateChange> changes = [];

  @override
  void onAfterChange<T>(StateChange<T> change) {
    changes.add(change);
  }
}

void main() {
  group('Coverage Gaps - Core', () {
    tearDown(() {
      Lx.middlewares.clear();
      Lx.captureStackTrace = false;
    });

    test('Lx.runBatch resets isBatching on exception', () {
      expect(Lx.isBatching, isFalse);
      try {
        Lx.batch(() {
          expect(Lx.isBatching, isTrue);
          throw Exception('Batch failure');
        });
      } catch (_) {}
      expect(Lx.isBatching, isFalse);
    });

    test('LxNotifier ignores operations after disposal', () {
      final notifier = LxNotifier();
      var called = false;
      notifier.addListener(() => called = true);

      notifier.dispose();
      expect(notifier.isDisposed, isTrue);

      // Should result in no-op, no error
      notifier.notify();
      expect(called, isFalse);

      // Add listener after dispose should be ignored
      notifier.addListener(() => called = true);
    });

    test('LxNotifier removeListener works', () {
      final notifier = LxNotifier();
      var count = 0;
      void listener() => count++;

      notifier.addListener(listener);
      notifier.notify();
      expect(count, equals(1));

      notifier.removeListener(listener);
      notifier.notify();
      expect(count, equals(1)); // No increase
    });

    test('StateChange produces json with stack trace', () {
      Lx.captureStackTrace = true;
      final change = StateChange(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
        stackTrace: StackTrace.current,
        restore: (_) {},
      );
      final json = change.toJson();
      expect(json['stackTrace'], isNotNull);
    });

    test('CompositeChange getters return correct metadata', () {
      final change1 = StateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final composite = CompositeStateChange([change1]);

      // Force access invalid getters for coverage
      try {
        composite.oldValue;
      } catch (_) {}
      try {
        composite.newValue;
      } catch (_) {}

      expect(composite.stackTrace, isNull);
      expect(composite.toJson()['type'], equals('CompositeChange'));
      expect(composite.toString(), contains('Batch'));

      // Cover name, valueType, restore getters
      expect(composite.name, equals('Batch(1)'));
      expect(composite.valueType, equals(CompositeStateChange));
      expect(composite.restore, isNull);
    });

    test('Lx bind handles stream errors', () async {
      final controller = StreamController<int>();
      final count = 0.lx;

      // Bind (lazy)
      count.bind(controller.stream);

      // Must listen to activate the binding
      final events = <dynamic>[];
      final sub = count.stream.listen(
        (v) => events.add(v),
        onError: (e) => events.add('Error: $e'),
      );

      controller.addError('Stream Error');
      controller.add(5);

      await Future.delayed(Duration.zero);
      // Wait a bit more for async propagation if needed
      await Future.delayed(Duration(milliseconds: 10));

      expect(events, contains(5));
      expect(count.value, equals(5));

      await sub.cancel();
      await controller.close();
    });

    test('Middleware cancellation prevents updates', () {
      Lx.middlewares.add(RejectMiddleware());

      // Test Lx
      final count = 0.lx;
      count.value = 1;
      expect(count.value, equals(0)); // Rejected

      // Test Lxn
      final name = 'a'.lxNullable;
      name.value = 'b';
      expect(name.value, equals('a')); // Rejected
    });

    test('LxMiddleware default implementations', () {
      // Create a specific class that extends (not implements) to use default methods
      final simpleMiddleware = SimpleMiddleware();
      Lx.middlewares.add(simpleMiddleware);

      // Trigger default onBeforeChange (should return true)
      final count = 0.lx;
      count.value = 1;
      expect(count.value, equals(1));
      expect(simpleMiddleware.changes, hasLength(1));

      // Trigger default onBatchStart / onBatchEnd (empty bodies)
      Lx.batch(() {
        count.value = 2;
      });
      expect(count.value, equals(2));
      // No crash means defaults worked
    });
  });

  group('LxHistoryMiddleware Extra Coverage', () {
    test('LxHistoryMiddleware handles missing name/callback gracefully', () {
      final history = LxHistoryMiddleware();
      // Manually add a change with NO restore callback and NO name
      final brokenChange = StateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
        // name: null, // default
        // restore: null // default
      );

      history.onAfterChange(brokenChange);

      // Undo should hit the "Warning" print path but not crash
      // Since it returns true (change popped), we verify that.
      expect(history.undo(), isTrue);
    });

    test('LxHistoryMiddleware clear works', () {
      final history = LxHistoryMiddleware();
      final count = 0.lx;
      Lx.middlewares.add(history); // Activate

      count.value = 1;
      expect(history.changes, isNotEmpty);

      history.clear();
      expect(history.changes, isEmpty); // access changes getter
      expect(history.length, equals(0)); // access length getter
    });

    test('LxHistoryMiddleware printHistory with redo stack', () {
      final history = LxHistoryMiddleware();
      Lx.middlewares.add(history);

      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      // Undo to populate redo stack
      history.undo();
      expect(history.canRedo, isTrue);

      // This should print both undo and redo stacks
      history.printHistory();
      // No assertion needed - just coverage
    });
  });

  group('Types Extra Coverage', () {
    test('Lx convenience methods (mutate, refresh, call, updateValue)', () {
      final count = 0.lx;

      // .call()
      expect(count(), equals(0));
      expect(count(5), equals(5));
      expect(count.value, equals(5));

      // updateValue
      count.updateValue((v) => v * 2);
      expect(count.value, equals(10));

      // refresh / notify
      // We need a listener to verify notification
      var notifications = 0;
      count.addListener(() => notifications++);

      count.refresh();
      expect(notifications, equals(1));

      count.notify();
      expect(notifications, equals(2));

      // mutate
      final list = <int>[].lx;
      list.addListener(() => notifications++);
      list.mutate((l) => l.add(1));
      expect(notifications, equals(3)); // list added
      expect(list.value, equals([1]));
    });

    test('LxNullable setNull', () {
      final name = 'test'.lxNullable;
      expect(name.value, equals('test'));
      name.value = null;
      expect(name.value, isNull);
    });

    test('Future.lx extension creates LxFuture', () async {
      final future = Future.value(42);
      final lxFuture = future.lx;

      expect(lxFuture, isA<LxFuture<int>>());

      // Wait for completion
      await Future.delayed(Duration(milliseconds: 10));
      expect(lxFuture.status, isA<AsyncSuccess<int>>());
      expect(lxFuture.valueOrNull, equals(42));
    });
  });
}
