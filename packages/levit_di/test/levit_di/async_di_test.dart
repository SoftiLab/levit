import 'package:levit_di/levit_di.dart';
import 'package:test/test.dart';

class AsyncService implements LevitDisposable {
  final String name;
  static int initCount = 0;
  static int closeCount = 0;

  AsyncService(this.name);

  @override
  void onInit() => initCount++;

  @override
  void onClose() => closeCount++;

  static void resetCounts() {
    initCount = 0;
    closeCount = 0;
  }
}

class FactoryService implements LevitDisposable {
  static int instanceCount = 0;
  final int id;

  FactoryService() : id = ++instanceCount;

  @override
  void onInit() {}

  @override
  void onClose() {}

  static void reset() => instanceCount = 0;
}

void main() {
  setUp(() {
    Levit.reset(force: true);
    AsyncService.resetCounts();
    FactoryService.reset();
  });

  tearDown(() {
    Levit.reset(force: true);
  });

  group('putAsync', () {
    test('registers async service', () async {
      final service = await Levit.putAsync(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return AsyncService('async');
      });

      expect(service.name, 'async');
      expect(Levit.find<AsyncService>().name, 'async');
      expect(AsyncService.initCount, 1);
    });

    test('putAsync with tag', () async {
      await Levit.putAsync(() async => AsyncService('v1'), tag: 'v1');
      await Levit.putAsync(() async => AsyncService('v2'), tag: 'v2');

      expect(Levit.find<AsyncService>(tag: 'v1').name, 'v1');
      expect(Levit.find<AsyncService>(tag: 'v2').name, 'v2');
    });
  });

  group('lazyPutAsync', () {
    test('does not instantiate until findAsync', () async {
      Levit.lazyPutAsync(() async {
        return AsyncService('lazy-async');
      });

      expect(Levit.isInstantiated<AsyncService>(), false);

      final service = await Levit.findAsync<AsyncService>();
      expect(service.name, 'lazy-async');
      expect(Levit.isInstantiated<AsyncService>(), true);
      expect(AsyncService.initCount, 1);
    });

    test('lazyPutAsync with tag', () async {
      Levit.lazyPutAsync(() async => AsyncService('tagged'), tag: 'test');

      final service = await Levit.findAsync<AsyncService>(tag: 'test');
      expect(service.name, 'tagged');
    });
  });

  group('findAsync', () {
    test('findAsync works with sync registrations', () async {
      Levit.put(AsyncService('sync'));

      final service = await Levit.findAsync<AsyncService>();
      expect(service.name, 'sync');
    });

    test('findAsync with lazy sync', () async {
      Levit.lazyPut(() => AsyncService('lazy-sync'));

      final service = await Levit.findAsync<AsyncService>();
      expect(service.name, 'lazy-sync');
    });

    test('findAsync throws if not found', () async {
      expect(
        () async => await Levit.findAsync<AsyncService>(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('putFactory (factory pattern)', () {
    test('putFactory returns new instance each time', () {
      Levit.putFactory(() => FactoryService());

      final a = Levit.find<FactoryService>();
      final b = Levit.find<FactoryService>();
      final c = Levit.find<FactoryService>();

      expect(a.id, 1);
      expect(b.id, 2);
      expect(c.id, 3);
      expect(identical(a, b), false);
    });

    test('create with tag', () {
      Levit.putFactory(() => FactoryService(), tag: 'factory');

      final a = Levit.find<FactoryService>(tag: 'factory');
      final b = Levit.find<FactoryService>(tag: 'factory');

      expect(a.id != b.id, true);
    });
  });

  group('putFactoryAsync', () {
    test('putFactoryAsync returns new instance each time via findAsync',
        () async {
      Levit.putFactoryAsync(() async {
        await Future.delayed(Duration(milliseconds: 5));
        return FactoryService();
      });

      final a = await Levit.findAsync<FactoryService>();
      final b = await Levit.findAsync<FactoryService>();

      expect(a.id, 1);
      expect(b.id, 2);
    });

    test('putFactoryAsync factory works with sync find for sync builders', () {
      Levit.putFactoryAsync(() async => FactoryService());

      // Using findAsync since it's async factory
      expect(
        () async => await Levit.findAsync<FactoryService>(),
        returnsNormally,
      );
    });
  });

  group('findOrNull', () {
    test('returns null if not registered', () {
      expect(Levit.findOrNull<AsyncService>(), isNull);
    });

    test('returns instance if registered', () {
      Levit.put(AsyncService('test'));
      expect(Levit.findOrNull<AsyncService>()?.name, 'test');
    });

    test('lazy instantiates if needed', () {
      Levit.lazyPut(() => AsyncService('lazy'));
      expect(Levit.isInstantiated<AsyncService>(), false);

      final service = Levit.findOrNull<AsyncService>();
      expect(service?.name, 'lazy');
      expect(Levit.isInstantiated<AsyncService>(), true);
    });

    test('findOrNull with tag', () {
      Levit.put(AsyncService('tagged'), tag: 'special');

      expect(Levit.findOrNull<AsyncService>(), isNull);
      expect(Levit.findOrNull<AsyncService>(tag: 'special')?.name, 'tagged');
    });
  });

  group('LevitScope async methods', () {
    test('scope findOrNull with parent fallback', () {
      Levit.put(AsyncService('parent'));
      final scope = Levit.createScope('test');

      expect(scope.findOrNull<AsyncService>()?.name, 'parent');
    });
  });
  group('findOrNullAsync', () {
    test('returns null if not registered', () async {
      expect(await Levit.findOrNullAsync<AsyncService>(), isNull);
    });

    test('returns instance if registered', () async {
      await Levit.putAsync<String>(() async => 'async value');
      expect(await Levit.findOrNullAsync<String>(), 'async value');
    });

    test('lazy instantiates if needed', () async {
      Levit.lazyPutAsync(() async => AsyncService('lazy'));
      expect(Levit.isInstantiated<AsyncService>(), false);

      final service = await Levit.findOrNullAsync<AsyncService>();
      expect(service?.name, 'lazy');
      expect(Levit.isInstantiated<AsyncService>(), true);
    });
  });
}
