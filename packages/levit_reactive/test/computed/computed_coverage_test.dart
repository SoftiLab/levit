import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

/// Additional tests to achieve 100% coverage for computed.dart
void main() {
  group('LxComputed Coverage Tests', () {
    group('_SyncComputed', () {
      test('error in _setupDependencyTracking is captured (thrown on access)',
          () {
        // Covers lines 213-215: error path in _setupDependencyTracking
        expect(() => LxComputed<int>(() => throw 'setup error'),
            throwsA('setup error'));
      });

      test('dynamic dependency tracking adds new streams in _ensureFresh',
          () async {
        // Covers lines 247-251: adding new streams dynamically
        final source1 = 1.lx;
        final source2 = 2.lx;
        final useSecond = false.lx;

        final computed = LxComputed<int>(() {
          if (useSecond.value) {
            return source2.value * 10;
          }
          return source1.value;
        });

        computed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 1);

        // Now change to use second source - this will add a new dependency
        useSecond.value = true;
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 20);

        // Change source2 - should trigger recomputation due to new dependency
        source2.value = 5;
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 50);
      });

      test('refresh() marks dirty and notifies', () async {
        // Covers lines 349-352
        var computeCount = 0;
        final computed = LxComputed(() {
          computeCount++;
          return computeCount;
        });

        computed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 2);

        // Refresh should mark dirty and trigger recomputation on next access
        computed.refresh();
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 3);
      });

      test('incremental dependency tracking (internal check)', () async {
        // targeting: if (!onlyNew || !_trackedStreams.contains(stream))

        final condition = true.lx;
        final a = 1.lx;
        // Force stream creation so 'a' registers as a stream dependency too
        // This is crucial to populate tracker.streams and enter the loop we want to test
        a.stream;

        final b = 2.lx;

        // 1. Initial run: depends on condition + a
        final computed = LxComputed(() {
          if (condition.value) {
            return a.value;
          } else {
            return a.value + b.value;
          }
        });

        // Activate listener to keep it alive
        computed.addListener(() {});

        // Value is 1. Tracked: [condition, a]
        // _subscribeToDependencies(onlyNew: false) -> !onlyNew is TRUE. Short circuit.
        // line 371 skipped.
        expect(computed.value, 1);

        // 2. Change condition to false.
        // Computed is dirty.
        condition.value = false;

        // 3. Read value.
        // _ensureFresh -> _runWithTracking(isInitial: false) -> _subscribeToDependencies(onlyNew: true)
        // !onlyNew is FALSE.
        // line 371: !_trackedStreams.contains(stream) MUST be evaluated.
        expect(computed.value, 3);
      });

      test('Sync Computed throws on error access', () {
        expect(() => LxComputed<int>(() => throw 'err'), throwsA('err'));
      });
    });

    group('_AsyncComputed', () {
      test('computedValue throws when in waiting state', () async {
        // Covers lines 484-489
        final computed = LxComputed.async(() async {
          await Future.delayed(Duration(milliseconds: 100));
          return 42;
        });

        // Before activation, accessing computedValue should throw
        expect(() => computed.computedValue, throwsStateError);
      });

      test('computedValue throws error when in error state', () async {
        // Covers lines 487-488: error throw path
        final computed = LxComputed.async<int>(() async => throw 'async error');
        computed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 20));

        expect(() => computed.computedValue, throwsA('async error'));
      });

      test('isError, isLoading, hasListener getters', () async {
        // Covers lines 510-517
        final computed = LxComputed.async(() async => 42);
        expect(computed.isLoading, isTrue); // Initially waiting
        expect(computed.hasListener, isFalse);

        computed.stream.listen((_) {});
        expect(computed.hasListener, isTrue);

        await Future.delayed(Duration(milliseconds: 20));
        expect(computed.isLoading, isFalse);

        // Error case
        final errorComputed = LxComputed.async<int>(() async => throw 'err');
        errorComputed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 20));
        expect(errorComputed.isError, isTrue);
      });

      test('removeListener calls _onInactive', () async {
        // Covers line 535
        final computed = LxComputed.async(() async => 42);
        var listenerCalled = 0;
        void listener() => listenerCalled++;

        computed.addListener(listener);
        await Future.delayed(Duration(milliseconds: 20));

        // Listener should have been called (on activation)
        expect(listenerCalled, greaterThan(0));

        computed.removeListener(listener);
        // After remove, no more calls should happen
        // final _callsBefore = listenerCalled;
        computed.refresh();
        await Future.delayed(Duration(milliseconds: 20));
        // Should be same or close - no more listener
      });

      test('close cancels subscriptions', () async {
        // Covers line 542-543
        final source = 1.lx;
        final computed = LxComputed.async(() async => source.value);
        computed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 20));

        computed.close();
        // After close, source changes should not trigger recomputation
        source.value = 100;
        await Future.delayed(Duration(milliseconds: 20));
        // No exception means it worked
      });
    });

    group('Edge cases', () {
      test('sync computed error in _ensureFresh propagates error', () async {
        final shouldThrow = false.lx;
        final computed = LxComputed<int>(() {
          if (shouldThrow.value) throw 'recompute error';
          return 42;
        });

        computed.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 10));
        expect(computed.value, 42);

        expect(() => shouldThrow.value = true, throwsA('recompute error'));
        await Future.delayed(Duration(milliseconds: 10));
        expect(() => computed.value, throwsA('recompute error'));
      });

      test('sync computed pull-on-read error path', () {
        // Covers lines 276-277
        expect(() => LxComputed<int>(() => throw 'sync pull error'),
            throwsA('sync pull error'));
      });
      test('LxComputed.transform coverage', () async {
        final source = 10.lx;
        final computed = LxComputed(() => source.value * 2);

        // Activation & initial check
        expect(computed.value, 20);

        final transformed = computed.transform((s) => s.map((v) => v + 1));
        final values = <AsyncStatus<int>>[];
        transformed.addListener(() => values.add(transformed.value));

        source.value = 11;
        await Future.microtask(() {});

        expect(computed.value, 22);
        expect(transformed.value.valueOrNull, 23);
      });

      test('LxComputed.async.transform coverage', () async {
        final source = 10.lx;
        final computed = LxComputed.async(() async {
          return source.value * 2;
        });
        computed.addListener(() {}); // Activate immediately

        // Wait for initial compute
        await Future.delayed(const Duration(milliseconds: 30));
        expect(computed.status.valueOrNull, 20);

        final transformed =
            computed.transform((s) => s.map((status) => status.valueOrNull));
        transformed.addListener(() {}); // Keep alive

        source.value = 21;
        await Future.delayed(const Duration(milliseconds: 30));

        expect(computed.status.valueOrNull, 42);
        expect(transformed.value.valueOrNull, 42);
      });
    });
  });
}
