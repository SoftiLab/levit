import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../helpers.dart';

void main() {
  group('LxMiddleware', () {
    setUp(() {
      Lx.middlewares.clear();
      Lx.captureStackTrace = false;
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    test('middleware receives state changes', () async {
      final changes = <StateChange>[];
      Lx.middlewares.add(TestMiddleware(onAfter: changes.add));

      final count = Lx<int>(0)..flags['name'] = 'counter';
      count.value = 1;
      count.value = 2;

      expect(changes, hasLength(2));
      expect(changes[0].oldValue, equals(0));
      expect(changes[0].newValue, equals(1));
      expect(changes[1].oldValue, equals(1));
      expect(changes[1].newValue, equals(2));
    });

    test('flags name is included in StateChange', () {
      final changes = <StateChange>[];
      Lx.middlewares.add(TestMiddleware(onAfter: changes.add));

      final count = Lx<int>(0)..flags['name'] = 'myCounter';
      count.value = 5;

      expect(changes.first.name, equals('myCounter'));
    });

    test('onBeforeChange can prevent state change', () {
      Lx.middlewares.add(TestMiddleware(allowChange: false));

      final count = Lx<int>(0);
      count.value = 100;

      expect(count.value, equals(0)); // Change was prevented
    });

    test('captureStackTrace captures stack when enabled', () {
      final changes = <StateChange>[];
      Lx.captureStackTrace = true;
      Lx.middlewares.add(TestMiddleware(onAfter: changes.add));

      final count = Lx<int>(0);
      count.value = 1;

      expect(changes.first.stackTrace, isNotNull);
    });

    test('default onBeforeChange allows changes', () {
      final minimal = MinimalMiddleware();
      Lx.middlewares.add(minimal);

      final count = Lx<int>(0);
      count.value = 5;

      expect(count.value, equals(5)); // Change was allowed
      expect(minimal.changes, hasLength(1));
    });

    test('StateChange toString includes relevant info', () {
      final change = StateChange<int>(
        timestamp: DateTime(2024, 1, 1),
        name: 'test',
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );

      final str = change.toString();
      expect(str, contains('test'));
      expect(str, contains('0'));
      expect(str, contains('1'));
    });

    test('LxMiddleware default onBeforeChange returns true', () {
      final middleware = DefaultMiddleware();
      final change = StateChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );

      expect(middleware.onBeforeChange(change), isTrue);
    });
  });

  group('LxHistoryMiddleware (Basic)', () {
    late LxHistoryMiddleware history;

    setUp(() {
      history = LxHistoryMiddleware();
      Lx.middlewares.add(history);
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    test('records state changes', () {
      final count = Lx<int>(0)..flags['name'] = 'count';
      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(history.length, equals(3));
      expect(history.changes[0].newValue, equals(1));
      expect(history.changes[1].newValue, equals(2));
      expect(history.changes[2].newValue, equals(3));
    });

    test('respects maxHistorySize', () {
      Lx.maxHistorySize = 2;

      final count = 0.lx;
      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(history.length, equals(2)); // Only last 2
      expect(history.changes[0].newValue, equals(2));
      expect(history.changes[1].newValue, equals(3));

      Lx.maxHistorySize = 100; // Reset
    });

    test('changesFor filters by name', () {
      final a = Lx<int>(0)..flags['name'] = 'a';
      final b = Lx<int>(0)..flags['name'] = 'b';

      a.value = 1;
      b.value = 2;
      a.value = 3;

      expect(history.changesFor('a'), hasLength(2));
      expect(history.changesFor('b'), hasLength(1));
    });

    test('clear removes all history', () {
      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      expect(history.length, equals(2));
      history.clear();
      expect(history.length, equals(0));
    });

    test('canUndo returns correct state', () {
      expect(history.canUndo, isFalse);

      final count = 0.lx;
      count.value = 1;

      expect(history.canUndo, isTrue);
    });

    test('changes list returns all changes', () {
      final count = Lx<int>(0)..flags['name'] = 'count';
      count.value = 1;
      count.value = 2;

      expect(history.changes.last.newValue, equals(2));
    });

    test('undo works automatically', () {
      final count = Lx<int>(0)..flags['name'] = 'counter';

      count.value = 5;
      count.value = 10;

      expect(history.canUndo, isTrue);

      history.undo();
      expect(count.value, equals(5));

      history.undo();
      expect(count.value, equals(0));
    });

    test('undo returns false when no changes', () {
      expect(history.undo(), isFalse);
    });

    test('undo returns true by default (Auto-Undo)', () {
      final count = 0.lx;
      count.value = 1;

      // Even without manual registration, undo works via Auto-Undo
      final undone = history.undo();
      expect(undone, isTrue);
      expect(count.value, equals(0));
    });

    test('printHistory prints all changes', () {
      final count = Lx<int>(0)..flags['name'] = 'test';
      count.value = 1;

      // Just verify it doesn't throw
      history.printHistory();
    });
  });
}
