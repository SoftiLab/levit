import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

// Test interface
abstract class Service {
  String get name;
}

class RootService implements Service {
  @override
  String get name => 'Root';
}

class ScopeService implements Service {
  @override
  String get name => 'Scope';
}

class Counter implements LevitDisposable {
  final String id;
  bool closed = false;

  Counter(this.id);

  @override
  void onInit() {}

  @override
  void onClose() {
    closed = true;
  }
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Unified Scope Hierarchy', () {
    test('Root Scope Basic Operations', () {
      Levit.put<Service>(RootService());
      expect(Levit.find<Service>().name, 'Root');
      expect(Levit.isRegistered<Service>(), isTrue);

      Levit.delete<Service>();
      expect(Levit.isRegistered<Service>(), isFalse);
    });

    test('Scope Hierarchy Resolution', () {
      Levit.put<Service>(RootService());

      final scope = Levit.createScope('child');

      // Should find in parent (root)
      expect(scope.find<Service>().name, 'Root');

      // Override in scope
      scope.put<Service>(ScopeService());

      // Should find local
      expect(scope.find<Service>().name, 'Scope');

      // Root should still have original
      expect(Levit.find<Service>().name, 'Root');
    });

    test('Nested Scopes', () {
      final scope1 = Levit.createScope('scope1');
      scope1.put(Counter('c1'));

      final scope2 = scope1.createScope('scope2');

      // Should resolve from parent scope
      expect(scope2.find<Counter>().id, 'c1');
    });

    test('Async Methods in Scopes', () async {
      final scope = Levit.createScope('async_scope');

      // putAsync in scope
      await scope.putAsync<Service>(() async => ScopeService());
      expect(await scope.findAsync<Service>(), isA<ScopeService>());

      // lazyPutAsync in scope
      scope.lazyPutAsync<Counter>(() async => Counter('async_c'), tag: 'lazy');
      expect((await scope.findAsync<Counter>(tag: 'lazy')).id, 'async_c');
    });

    test('Scope Cleanup', () {
      final scope = Levit.createScope('cleanup');
      final c1 = Counter('c1');
      scope.put(c1);

      scope.reset();
      expect(c1.closed, isTrue);
      expect(scope.isRegistered<Counter>(), isFalse);
    });

    test('SimpleDI Delegation Check', () {
      // White-box test to ensure SimpleDI delegates correctly
      Levit.put(Counter('root'));
      expect(Levit.registeredCount, 1);
      expect(Levit.registeredKeys, contains(endsWith('Counter')));
    });

    test('Async Resolution Cache', () async {
      // Setup: Parent with async service, Child scope
      final parent = Levit.createScope('parent');
      await parent.putAsync<Service>(() async => ScopeService());

      final child = parent.createScope('child');

      // 1. Uncached lookup from child (hits parent fallback logic)
      final instance1 = await child.findOrNullAsync<Service>();
      expect(instance1, isNotNull);
      expect(instance1!.name, 'Scope');

      // 2. Cached lookup from child (hits resolution cache logic)
      // The first lookup should have cached the parent scope as the provider
      final instance2 = await child.findOrNullAsync<Service>();
      expect(instance2, same(instance1));

      // 3. Verify it used the cache (white-box assumption based on code path)
      // To strictly prove it HIT the cache lines, we rely on coverage report.
    });

    test('Deep Scope Cache Path Compression', () async {
      // Grandparent -> Parent -> Child
      // Service in Grandparent
      final gp = Levit.createScope('gp');
      await gp.putAsync<Service>(() async => RootService());

      final parent = gp.createScope('parent');
      final child = parent.createScope('child');

      // 1. Parent finds it, caching GP
      await parent.findAsync<Service>();

      // 2. Child finds it.
      // Should see Parent has it cached, and copy that reference (path compression).
      // This hits lines 407-409 in findOrNullAsync
      final instance = await child.findOrNullAsync<Service>();
      expect(instance!.name, 'Root');
    });
  });
}
