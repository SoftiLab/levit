import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
// verify import path

void main() {
  group('FilteredMiddleware', () {
    late LxHistoryMiddleware history;

    setUp(() {
      history = LxHistoryMiddleware();
      // Ensure clean state
      Lx.middlewares.clear();
    });

    tearDown(() {
      Lx.middlewares.clear();
    });

    test('should only record changes that pass the filter', () {
      Lx.addMiddleware(
        history,
        filter: (change) => change.name == 'record_me',
      );

      final ignoreObj = Lx(0)..flags['name'] = 'ignore_me';
      final recordObj = Lx(0)..flags['name'] = 'record_me';

      // Should be ignored
      ignoreObj.value = 1;

      // Should be recorded
      recordObj.value = 10;

      expect(history.changes.length, 1);
      expect(history.changes.first.name, 'record_me');
      expect(history.changes.first.newValue, 10);

      // Verify undo works on the valid history
      history.undo();
      expect(recordObj.value, 0);
      expect(ignoreObj.value, 1); // ignored obj should not revert
    });

    test('should allow removing filtered middleware', () {
      final mw = Lx.addMiddleware(
        history,
        filter: (change) => true,
      );

      expect(Lx.middlewares.contains(mw), true);

      Lx.middlewares.remove(mw);
      expect(Lx.middlewares.contains(mw), false);
    });
  });
}
