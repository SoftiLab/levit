import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

class ScopedService {
  final int level;
  ScopedService(this.level);
}

void main() {
  group('Stress Test: Deep Scoping', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('Deeply Nested Scopes (1,000 levels)', () {
      print(
          '[Description] Measures the manual setup cost and memory overhead of creating a massive scope hierarchy.');
      LevitScope currentScope = Levit.createScope('root');

      Levit.put(ScopedService(0)); // Root dependency

      final depth = 1000;
      final swSetup = Stopwatch()..start();

      for (var i = 1; i < depth; i++) {
        currentScope = currentScope.createScope('scope_$i');
        currentScope.put(ScopedService(i));
      }
      swSetup.stop();
      print('Created $depth nested scopes in ${swSetup.elapsedMilliseconds}ms');

      final swResolve = Stopwatch()..start();
      // Find from deepest scope
      // 1. Find local (depth - 1)
      expect(currentScope.find<ScopedService>().level, depth - 1);

      // 2. Find root from deepest (should traverse up)
      // Note: ScopedService is registered in every scope, so finding <ScopedService>
      // returns the local one. To text traversal, we need a unique type or tag.
      swResolve.stop();
      print(
          'Resolved local in deep scope in ${swResolve.elapsedMilliseconds}ms');
    });

    test('Deep Traversal Resolution', () {
      print(
          '[Description] Benchmarks the resolution speed when a dependency must be found by traversing multiple levels of parent scopes.');
      final depth = 1000;
      LevitScope currentScope = Levit.createScope('root');

      // Register distinct tags at intervals
      Levit.put(ScopedService(0), tag: 'root');

      for (var i = 1; i < depth; i++) {
        currentScope = currentScope.createScope('scope_$i');
      }

      final swTraversal = Stopwatch()..start();
      final rootService = currentScope.find<ScopedService>(tag: 'root');
      swTraversal.stop();

      expect(rootService.level, 0);
      print(
          'Resolved root dependency through $depth layers in ${swTraversal.elapsedMilliseconds}ms');
    });
  });
}
