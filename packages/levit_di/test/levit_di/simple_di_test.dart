import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

void main() {
  // Reset the DI container before each test
  setUp(() {
    Levit.reset(force: true);
  });

  group('Levit.put()', () {
    test('registers and returns instance', () {
      final service = Levit.put(_TestService('hello'));
      expect(service.value, equals('hello'));
    });

    test('instance is retrievable via find', () {
      Levit.put(_TestService('world'));
      final found = Levit.find<_TestService>();
      expect(found.value, equals('world'));
    });

    test('calls onInit on LevitDisposable', () {
      final service = _DisposableService();
      Levit.put(service);
      expect(service.initCalled, isTrue);
    });

    test('with tag registers separate instances', () {
      Levit.put(_TestService('default'));
      Levit.put(_TestService('tagged'), tag: 'v2');

      expect(Levit.find<_TestService>().value, equals('default'));
      expect(Levit.find<_TestService>(tag: 'v2').value, equals('tagged'));
    });

    test('replaces existing instance', () {
      Levit.put(_TestService('first'));
      Levit.put(_TestService('second'));
      expect(Levit.find<_TestService>().value, equals('second'));
    });
  });

  group('Levit.lazyPut()', () {
    test('does not instantiate immediately', () {
      var builderCalled = false;
      Levit.lazyPut(() {
        builderCalled = true;
        return _TestService('lazy');
      });

      expect(builderCalled, isFalse);
      expect(Levit.isRegistered<_TestService>(), isTrue);
      expect(Levit.isInstantiated<_TestService>(), isFalse);
    });

    test('instantiates on first find', () {
      var callCount = 0;
      Levit.lazyPut(() {
        callCount++;
        return _TestService('lazy');
      });

      final first = Levit.find<_TestService>();
      final second = Levit.find<_TestService>();

      expect(callCount, equals(1)); // Builder called only once
      expect(first.value, equals('lazy'));
      expect(identical(first, second), isTrue);
    });

    test('calls onInit on first find', () {
      Levit.lazyPut(() => _DisposableService());

      expect(Levit.isInstantiated<_DisposableService>(), isFalse);

      final service = Levit.find<_DisposableService>();
      expect(service.initCalled, isTrue);
    });

    test('does not overwrite instantiated instance', () {
      Levit.lazyPut(() => _TestService('first'));
      Levit.find<_TestService>(); // Instantiate

      Levit.lazyPut(() => _TestService('second')); // Should be ignored

      expect(Levit.find<_TestService>().value, equals('first'));
    });
  });

  group('Levit.find()', () {
    test('throws if not registered', () {
      expect(
        () => Levit.find<_TestService>(),
        throwsA(isA<Exception>()),
      );
    });

    test('throws with helpful message', () {
      expect(
        () => Levit.find<_TestService>(),
        throwsA(predicate((e) =>
            e.toString().contains('_TestService') &&
            e.toString().contains('not registered'))),
      );
    });

    test('throws with tag in message', () {
      expect(
        () => Levit.find<_TestService>(tag: 'special'),
        throwsA(predicate((e) => e.toString().contains('special'))),
      );
    });
  });

  group('Levit.delete()', () {
    test('removes instance', () {
      Levit.put(_TestService('test'));
      expect(Levit.isRegistered<_TestService>(), isTrue);

      Levit.delete<_TestService>();
      expect(Levit.isRegistered<_TestService>(), isFalse);
    });

    test('calls onClose on LevitDisposable', () {
      final service = _DisposableService();
      Levit.put(service);

      Levit.delete<_DisposableService>();
      expect(service.closeCalled, isTrue);
    });

    test('returns true if deleted', () {
      Levit.put(_TestService('test'));
      expect(Levit.delete<_TestService>(), isTrue);
    });

    test('returns false if not registered', () {
      expect(Levit.delete<_TestService>(), isFalse);
    });

    test('respects permanent flag', () {
      Levit.put(_TestService('permanent'), permanent: true);

      expect(Levit.delete<_TestService>(), isFalse);
      expect(Levit.isRegistered<_TestService>(), isTrue);
    });

    test('force overrides permanent flag', () {
      Levit.put(_TestService('permanent'), permanent: true);

      expect(Levit.delete<_TestService>(force: true), isTrue);
      expect(Levit.isRegistered<_TestService>(), isFalse);
    });

    test('deletes correct tagged instance', () {
      Levit.put(_TestService('default'));
      Levit.put(_TestService('tagged'), tag: 'v2');

      Levit.delete<_TestService>(tag: 'v2');

      expect(Levit.isRegistered<_TestService>(), isTrue);
      expect(Levit.isRegistered<_TestService>(tag: 'v2'), isFalse);
    });
  });

  group('Levit.reset()', () {
    test('clears all instances', () {
      Levit.put(_TestService('one'));
      Levit.put(_DisposableService());

      Levit.reset();

      expect(Levit.registeredCount, equals(0));
    });

    test('calls onClose on all LevitDisposables', () {
      final services = [
        _DisposableService(),
        _DisposableService(),
        _DisposableService(),
      ];
      for (var i = 0; i < services.length; i++) {
        Levit.put(services[i], tag: 'tag$i');
      }

      Levit.reset();

      for (final service in services) {
        expect(service.closeCalled, isTrue);
      }
    });

    test('respects permanent flag', () {
      Levit.put(_TestService('permanent'), permanent: true);
      Levit.put(_DisposableService());

      Levit.reset();

      expect(Levit.isRegistered<_TestService>(), isTrue);
      expect(Levit.isRegistered<_DisposableService>(), isFalse);
    });

    test('force clears permanent instances', () {
      Levit.put(_TestService('permanent'), permanent: true);

      Levit.reset(force: true);

      expect(Levit.isRegistered<_TestService>(), isFalse);
    });
  });

  group('Registration status', () {
    test('isRegistered returns true for put', () {
      Levit.put(_TestService('test'));
      expect(Levit.isRegistered<_TestService>(), isTrue);
    });

    test('isRegistered returns true for lazyPut before find', () {
      Levit.lazyPut(() => _TestService('lazy'));
      expect(Levit.isRegistered<_TestService>(), isTrue);
    });

    test('isInstantiated returns false for lazyPut before find', () {
      Levit.lazyPut(() => _TestService('lazy'));
      expect(Levit.isInstantiated<_TestService>(), isFalse);
    });

    test('isInstantiated returns true after find', () {
      Levit.lazyPut(() => _TestService('lazy'));
      Levit.find<_TestService>();
      expect(Levit.isInstantiated<_TestService>(), isTrue);
    });
  });

  group('LevitDisposable', () {
    test('default onInit does nothing', () {
      final disposable = _MinimalDisposable();
      expect(() => disposable.onInit(), returnsNormally);
    });

    test('default onClose does nothing', () {
      final disposable = _MinimalDisposable();
      expect(() => disposable.onClose(), returnsNormally);
    });
  });

  group('Debugging helpers', () {
    test('registeredTypes returns list of type keys', () {
      Levit.put(_TestService('one'));
      Levit.put(_DisposableService());

      final types = Levit.registeredKeys;
      expect(types, contains('_TestService'));
      expect(types, contains('_DisposableService'));
      expect(types.length, equals(2));
    });
  });
}

// Test helpers

class _TestService {
  final String value;
  _TestService(this.value);
}

class _DisposableService implements LevitDisposable {
  bool initCalled = false;
  bool closeCalled = false;

  @override
  void onInit() {
    initCalled = true;
  }

  @override
  void onClose() {
    closeCalled = true;
  }
}

/// Minimal implementation that uses default methods (extends to get defaults)
class _MinimalDisposable extends LevitDisposable {}
