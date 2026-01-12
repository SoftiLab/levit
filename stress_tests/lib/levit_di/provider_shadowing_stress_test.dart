import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

abstract class BaseService {
  int get id;
}

class ServiceImpl implements BaseService {
  @override
  final int id;
  ServiceImpl(this.id);
}

class UniqueRootService {}

void main() {
  group('Stress Test: Provider Shadowing', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('Resolution remains efficient with deep shadowing', () {
      print(
          '[Description] Benchmarks resolution efficiency in deeply nested scopes with local overrides.');
      const depth = 1000;

      final stopwatch = Stopwatch()..start();

      Levit.put<BaseService>(ServiceImpl(0));

      LevitScope current = Levit.createScope('scope_1');
      current.put<BaseService>(ServiceImpl(1));

      for (int i = 2; i <= depth; i++) {
        current = current.createScope('scope_$i');
        current.put<BaseService>(ServiceImpl(i));
      }

      stopwatch.stop();
      print(
          'Deep Shadowing Setup: Created $depth nested scopes in ${stopwatch.elapsedMilliseconds}ms');

      stopwatch.reset();
      stopwatch.start();

      const resolutions = 10000;
      for (int i = 0; i < resolutions; i++) {
        final service = current.find<BaseService>();
        if (service.id != depth) {
          throw Exception('Wrong service resolved');
        }
      }

      stopwatch.stop();
      print(
          'Deep Shadowing Resolution: Performed $resolutions resolutions at depth $depth in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Resolving root dependency through many layers of shadowing', () {
      print(
          '[Description] Measures performance of root dependency lookups traversing many nested scope layers.');
      const depth = 1000;

      Levit.put(UniqueRootService());

      LevitScope leaf = Levit.createScope('scope_0');
      leaf.put<int>(0);

      for (int i = 1; i < depth; i++) {
        leaf = leaf.createScope('scope_$i');
        // Shadowing SOMETHING ELSE to create baggage
        leaf.put<int>(i);
      }

      final stopwatch = Stopwatch()..start();
      const resolutions = 10000;
      for (int i = 0; i < resolutions; i++) {
        leaf.find<UniqueRootService>();
      }
      stopwatch.stop();
      print(
          'Root Resolution: Resolved through $depth layers $resolutions times in ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
