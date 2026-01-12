import 'package:levit_di/levit_di.dart';
import 'package:test/test.dart';

class TestService implements LevitDisposable {
  bool closed = false;
  bool inited = false;
  @override
  void onInit() => inited = true;
  @override
  void onClose() => closed = true;
}

void main() {
  setUp(() => Levit.reset(force: true));
  tearDown(() => Levit.reset(force: true));

  group('DI Error Handling & Scope Edge Cases', () {
    test('LevitScope.put deletes existing instance if present', () {
      final scope = Levit.createScope('test');
      final s1 = TestService();
      scope.put(s1, tag: 't1');

      final s2 = TestService();
      scope.put(s2, tag: 't1'); // Should replace and close s1

      expect(s1.closed, true);
      expect(scope.find<TestService>(tag: 't1'), s2);
    });

    test('LevitScope.find throws if not found anywhere', () {
      final scope = Levit.createScope('test');
      expect(() => scope.find<TestService>(), throwsA(isA<Exception>()));
    });

    test('LevitScope.findOrNull recursion fallbacks', () {
      final parent = Levit.createScope('parent');
      final child = parent.createScope('child');

      // Should return null if nowhere
      expect(child.findOrNull<TestService>(), isNull);

      // Should find in parent DI if nowhere else
      Levit.put(TestService());
      expect(child.findOrNull<TestService>(), isNotNull);
    });

    test('SimpleDI.findAsync throws proper error message', () async {
      expect(
        () async => await Levit.findAsync<TestService>(tag: 'missing'),
        throwsA(isA<Exception>()),
      );
    });

    test('Levit.findAsync works with sync factory', () async {
      Levit.putFactory(() => TestService());
      final s1 = await Levit.findAsync<TestService>();
      expect(s1.inited, true);
    });

    test('LevitScope.find handles sync factory', () {
      final scope = Levit.createScope('test');
      scope.putFactory(() => TestService());
      final s1 = scope.find<TestService>();
      expect(s1.inited, true);
    });
  });
}
