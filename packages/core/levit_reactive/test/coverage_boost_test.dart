import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('levit_reactive Coverage Boost', () {
    test('isSensitive getter and setter', () {
      final v = 0.lx;
      expect(v.isSensitive, false);

      v.isSensitive = true;
      expect(v.isSensitive, true);

      // Setting same value
      v.isSensitive = true;
      expect(v.isSensitive, true);
    });

    test('lxVar extension with config', () {
      final v = 'test'.lxVar(named: 'my_var', isSensitive: true);
      expect(v.value, 'test');
      expect(v.name, 'my_var');
      expect(v.isSensitive, true);

      final v2 = 123.lxVar();
      expect(v2.value, 123);
      expect(v2.name, isNull);
      expect(v2.isSensitive, false);
    });

    test('LxReactive 3+ listeners (L359-360)', () {
      final v = 0.lx;
      v.addListener(() {}); // 1
      v.addListener(() {}); // 2 -> _setListeners
      v.addListener(() {}); // 3 -> covers L359-360
    });

    test('LevitReactiveHistoryMiddleware redoChanges (L404-406)', () {
      final mw = LevitReactiveHistoryMiddleware();
      mw.redoChanges;
    });
  });
}
