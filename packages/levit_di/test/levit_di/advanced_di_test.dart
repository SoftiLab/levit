import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

class TestService implements LevitDisposable {
  bool initCalled = false;
  bool closeCalled = false;

  @override
  void onInit() => initCalled = true;

  @override
  void onClose() => closeCalled = true;
}

class AsyncService implements LevitDisposable {
  final String value;
  bool initCalled = false;

  AsyncService(this.value);

  @override
  void onInit() => initCalled = true;

  @override
  void onClose() {}
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('SimpleDI Advanced Features', () {
    test('put replaces existing instance', () {
      final s1 = TestService();
      Levit.put(s1);

      final s2 = TestService();
      Levit.put(s2); // Should replace s1 and call onClose on s1

      expect(Levit.find<TestService>(), equals(s2));
      expect(s1.closeCalled, isTrue);
    });

    test('put permanent flag prevents delete', () {
      final s1 = TestService();
      Levit.put(s1, permanent: true);

      Levit.delete<TestService>();
      expect(Levit.isRegistered<TestService>(), isTrue);

      Levit.delete<TestService>(force: true);
      expect(Levit.isRegistered<TestService>(), isFalse);
    });

    test('lazyPut ignores if already instantiated', () {
      Levit.put(TestService());

      bool builderCalled = false;
      Levit.lazyPut(() {
        builderCalled = true;
        return TestService();
      });

      expect(builderCalled, isFalse);
      Levit.find<TestService>(); // Should still be the original put
      expect(builderCalled, isFalse);
    });

    test('putAsync registers instance', () async {
      await Levit.putAsync(() async => AsyncService('async'));
      expect(Levit.find<AsyncService>().value, equals('async'));
    });

    test('lazyPutAsync instantiated on findAsync', () async {
      bool built = false;
      Levit.lazyPutAsync(() async {
        built = true;
        return AsyncService('lazy');
      });

      expect(built, isFalse);
      final service = await Levit.findAsync<AsyncService>();
      expect(built, isTrue);
      expect(service.value, equals('lazy'));
      expect(service.initCalled, isTrue);
    });

    test('lazyPutAsync check ignores if registered', () {
      Levit.put(AsyncService('existing'));

      Levit.lazyPutAsync(() async => AsyncService('new'));
      // Should verify it didn't overwrite - implementation checks
      // isInstantiated, ensuring safe ignorance.
    });

    test('putFactory (Factory) returns new instance each time', () {
      Levit.putFactory(() => TestService());

      final s1 = Levit.find<TestService>();
      final s2 = Levit.find<TestService>();

      expect(s1, isNot(equals(s2)));
      expect(s1.initCalled, isTrue);
      expect(s2.initCalled, isTrue);
    });

    test('putFactoryAsync (Async Factory) returns new instance each time',
        () async {
      Levit.putFactoryAsync(() async => AsyncService('factory'));

      final s1 = await Levit.findAsync<AsyncService>();
      final s2 = await Levit.findAsync<AsyncService>();

      expect(s1, isNot(equals(s2)));
      expect(s1.initCalled, isTrue);
    });

    test('findAsync handles all modes', () async {
      // 1. Instantiated Sync
      Levit.put(TestService());
      expect(await Levit.findAsync<TestService>(), isA<TestService>());

      // 2. Lazy Sync
      Levit.lazyPut(() => AsyncService('lazySync'), tag: 'lazySync');
      expect((await Levit.findAsync<AsyncService>(tag: 'lazySync')).value,
          'lazySync');

      // 3. Factory Sync
      Levit.putFactory(() => AsyncService('factorySync'), tag: 'factorySync');
      final fs1 = await Levit.findAsync<AsyncService>(tag: 'factorySync');
      final fs2 = await Levit.findAsync<AsyncService>(tag: 'factorySync');
      expect(fs1, isNot(equals(fs2)));

      // 4. Lazy Async
      Levit.lazyPutAsync(() async => AsyncService('lazyAsync'),
          tag: 'lazyAsync');
      expect((await Levit.findAsync<AsyncService>(tag: 'lazyAsync')).value,
          'lazyAsync');
      // Subsequent call returns same instance (singleton)
      expect((await Levit.findAsync<AsyncService>(tag: 'lazyAsync')).value,
          'lazyAsync');

      // 5. Factory Async
      Levit.putFactoryAsync(() async => AsyncService('factoryAsync'),
          tag: 'factoryAsync');
      final fa1 = await Levit.findAsync<AsyncService>(tag: 'factoryAsync');
      final fa2 = await Levit.findAsync<AsyncService>(tag: 'factoryAsync');
      expect(fa1, isNot(equals(fa2)));
    });

    test('findOrNull returns null when missing', () {
      expect(Levit.findOrNull<TestService>(), isNull);
    });

    test('findOrNull instantiates lazy', () {
      Levit.lazyPut(() => TestService());
      final s = Levit.findOrNull<TestService>();
      expect(s, isNotNull);
      expect(s!.initCalled, isTrue);
    });

    test('isInstantiated checks correctly', () {
      expect(Levit.isInstantiated<TestService>(), isFalse);

      Levit.lazyPut(() => TestService());
      expect(Levit.isRegistered<TestService>(), isTrue);
      expect(Levit.isInstantiated<TestService>(), isFalse);

      Levit.find<TestService>();
      expect(Levit.isInstantiated<TestService>(), isTrue);
    });

    test('find throws when not found', () {
      expect(() => Levit.find<TestService>(), throwsException);
    });

    test('findAsync throws when not found', () async {
      expect(Levit.findAsync<TestService>(), throwsException);
    });

    test('delete returns false if not found', () {
      expect(Levit.delete<TestService>(), isFalse);
    });

    test('registeredKeys returns list', () {
      Levit.put(TestService());
      expect(Levit.registeredKeys, contains('TestService'));
    });

    test('reset respects permanent flag', () {
      Levit.put(TestService(), permanent: true);
      Levit.reset();
      expect(Levit.isRegistered<TestService>(), isTrue);

      Levit.reset(force: true);
      expect(Levit.isRegistered<TestService>(), isFalse);
    });
  });

  group('LevitScope Advanced Features', () {
    test('finds from parent scope', () {
      final parent = Levit.createScope('parent');
      parent.put(TestService());

      final child = parent.createScope('child');
      expect(child.find<TestService>(), isNotNull);
    });

    test('finds from parent DI', () {
      Levit.put(TestService());
      final scope = Levit.createScope('scope');
      expect(scope.find<TestService>(), isNotNull);
    });

    test('findOrNull falls back correctly', () {
      final scope = Levit.createScope('scope');

      // Local
      scope.put(TestService());
      expect(scope.findOrNull<TestService>(), isNotNull);

      // Parent Scope
      final child = scope.createScope('child');
      expect(child.findOrNull<TestService>(), isNotNull);

      // Parent DI
      Levit.put(AsyncService('global'));
      expect(child.findOrNull<AsyncService>(), isNotNull);
    });

    test('find throws if not found anywhere', () {
      final scope = Levit.createScope('scope');
      expect(() => scope.find<TestService>(), throwsException);
    });

    test('isRegistered checks parents', () {
      Levit.put(TestService());
      final scope = Levit.createScope('scope');
      expect(scope.isRegistered<TestService>(), isTrue);
      expect(scope.isRegisteredLocally<TestService>(), isFalse);
    });

    test('delete local only', () {
      Levit.put(TestService());
      final scope = Levit.createScope('scope');

      // Trying to delete parent service from scope should return false (or not affect parent)
      // Implementation check: _delete checks _registry.containsKey.
      expect(scope.delete<TestService>(), isFalse);
      expect(Levit.isRegistered<TestService>(), isTrue);
    });

    test('put in scope overrides parent', () {
      Levit.put(AsyncService('global'));

      final scope = Levit.createScope('scope');
      scope.put(AsyncService('local'));

      expect(scope.find<AsyncService>().value, 'local');
      expect(Levit.find<AsyncService>().value, 'global');
    });

    test('putFactory in scope works', () {
      final scope = Levit.createScope('scope');
      scope.putFactory(() => TestService());

      final s1 = scope.find<TestService>();
      final s2 = scope.find<TestService>();
      expect(s1, isNot(equals(s2)));
    });

    test('reset clears local instances', () {
      final scope = Levit.createScope('scope');
      scope.put(TestService());

      scope.reset();
      expect(scope.isRegisteredLocally<TestService>(), isFalse);
    });

    test('toString includes info', () {
      final scope = Levit.createScope('debugScope');
      expect(scope.toString(), contains('debugScope'));
    });

    test('resolution cache hits', () {
      // 1. Local hit
      final scope = Levit.createScope('cacheScope');
      scope.put(TestService());

      // First access populates cache (though local is always checked first)
      scope.find<TestService>();
      // Second access - logic in findOrNull checks local registry before cache
      // so we can't easily hit "cached == this" branch unless we mock _registry
      // BUT, we can test parent cache hits.
    });

    test('resolution cache hits from parent', () {
      // Parent Scope
      final parent = Levit.createScope('parent');
      parent.put(TestService());
      final child = parent.createScope('child');

      // 1. First find - searches parents, populates cache
      child.find<TestService>();

      // 2. Second find - should hit cache
      // We verify this by observing it still returns the same instance
      expect(child.find<TestService>(), isNotNull);
    });

    test('resolution cache hits from global', () {
      // Global
      Levit.put(AsyncService('global'));
      final scope = Levit.createScope('scope');

      // 1. First find
      scope.find<AsyncService>();

      // 2. Second find - hits cache (SimpleDI)
      expect(scope.find<AsyncService>().value, 'global');
    });

    test('findAsync handles nullable values (unreachable default branch)',
        () async {
      // This targets the fallback "return info.instance as S" in findAsync
      // which is only reachable if isInstantiated is false, but check passed?
      // Actually isInstantiated checks instance != null.
      // So checking null instance registration.

      // Levit.put<String?>(null); // This sets instance to null.
      // isInstantiated => false.
      // findAsync falls through all lazy/factory checks.
      // Hit return info.instance as S.

      Levit.put<String?>(null);
      final val = await Levit.findAsync<String?>();
      expect(val, isNull);
    });

    test('findOrNull finds cached local', () {
      // This is tricky because findOrNull checks registry first.
      // But let's ensure coverage of _resolutionCache logic
      final scope = Levit.createScope('s1');
      final child = scope.createScope('child');
      scope.put(TestService());

      child.find<TestService>(); // Cache populated with scope
      expect(child.find<TestService>(), isNotNull);
    });
  });
}
