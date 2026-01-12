import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxHistoryMiddleware (DevTools)', () {
    late LxHistoryMiddleware history;

    setUp(() {
      history = LxHistoryMiddleware();
      Lx.middlewares.add(history);
      Lx.maxHistorySize = 100;
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    // ------------------------------------------------------------------------
    // Basic Undo / Auto-Undo
    // ------------------------------------------------------------------------

    test('Auto-Undo reverts state without manual registration', () {
      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      expect(history.canUndo, isTrue);
      expect(count.value, equals(2));

      history.undo();
      expect(count.value, equals(1));

      history.undo();
      expect(count.value, equals(0));

      expect(history.canUndo, isFalse);
    });

    test('Undo also pushes to Redo stack', () {
      final count = 0.lx;
      count.value = 1;

      expect(history.canRedo, isFalse);

      history.undo();
      expect(history.canRedo, isTrue);
      expect(count.value, equals(0));
    });

    // ------------------------------------------------------------------------
    // Redo
    // ------------------------------------------------------------------------

    test('Redo reapplies undone changes', () {
      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      // Undo twice
      history.undo(); // -> 1
      history.undo(); // -> 0
      expect(count.value, equals(0));

      // Redo once
      expect(history.canRedo, isTrue);
      history.redo();
      expect(count.value, equals(1));

      // Redo again
      history.redo();
      expect(count.value, equals(2));
      expect(history.canRedo, isFalse);
    });

    test('New changes clear Redo stack', () {
      final count = 0.lx;
      count.value = 1;
      history.undo(); // -> 0, Redo stack has [0->1]

      expect(history.canRedo, isTrue);

      count.value = 5; // New change creates branched timeline
      expect(history.canRedo, isFalse); // Redo stack should be cleared
    });

    // ------------------------------------------------------------------------
    // Atomic Batching
    // ------------------------------------------------------------------------

    test('Batch operations create single CompositeChange', () {
      final a = 0.lx;
      final b = 0.lx;

      Lx.batch(() {
        a.value = 1;
        b.value = 2;
      });

      expect(history.length, equals(1)); // Single composite change
      final change = history.changes.first;
      expect(change, isA<CompositeStateChange>());
      expect((change as CompositeStateChange).changes, hasLength(2));
    });

    test('Undo reverts entire batch atomically', () {
      final a = 0.lx;
      final b = 0.lx;

      Lx.batch(() {
        a.value = 1;
        b.value = 2;
      });

      expect(a.value, equals(1));
      expect(b.value, equals(2));

      history.undo();

      expect(a.value, equals(0));
      expect(b.value, equals(0));
    });

    test('Redo reapplies entire batch atomically', () {
      final a = 0.lx;
      final b = 0.lx;

      Lx.batch(() {
        a.value = 1;
        b.value = 2;
      });

      history.undo();
      expect(a.value, equals(0));

      history.redo();
      expect(a.value, equals(1));
      expect(b.value, equals(2));
    });

    test('Re-entrancy guard prevents recursive recording during undo/redo', () {
      final count = 0.lx;
      count.value = 1;

      // When we undo, count.value = 0 triggers a notification.
      // The middleware should NOT record this as a new change.
      history.undo();

      // Should have 0 items in undo stack (removed the change)
      // And 1 item in redo stack
      expect(history.changes, isEmpty);
      expect(history.canRedo, isTrue);
    });

    // ------------------------------------------------------------------------
    // Serialization (DevTools Protocol)
    // ------------------------------------------------------------------------

    test('toJson produces valid structure for DevTools', () {
      final count = Lx<int>(0)..flags['name'] = 'counter';
      count.value = 1;

      Lx.batch(() {
        count.value = 2;
        count.value = 3;
      });

      final json = history.toJson();

      expect(json['undoStack'], hasLength(2)); // 1 normal + 1 batch
      expect(json['canUndo'], isTrue);

      final change1 = (json['undoStack'] as List)[0];
      expect(change1['name'], equals('counter'));
      expect(change1['newValue'], equals('1'));

      final batch = (json['undoStack'] as List)[1];
      expect(batch['type'], equals('CompositeChange'));
      expect(batch['changes'], hasLength(2));
    });
  });
}
