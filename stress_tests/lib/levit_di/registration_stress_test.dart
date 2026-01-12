import 'package:test/test.dart';
import 'package:levit_di/levit_di.dart';

class TestService {
  final int id;
  TestService(this.id);
}

void main() {
  group('Stress Test: DI Registration', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('Massive Registration & Resolution (100,000 services)', () {
      print(
          '[Description] Measures basic registration and resolution speed for a massive number of unique services in the root container.');
      final count = 100000;
      final services = List.generate(count, (i) => TestService(i));

      final swRegister = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.put(services[i], tag: '$i');
      }
      swRegister.stop();
      print(
          'Registered $count services in ${swRegister.elapsedMilliseconds}ms');

      // Verify a random sample
      expect(Levit.find<TestService>(tag: '0').id, 0);
      expect(Levit.find<TestService>(tag: '${count ~/ 2}').id, count ~/ 2);
      expect(Levit.find<TestService>(tag: '${count - 1}').id, count - 1);

      final swResolve = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.find<TestService>(tag: '$i');
      }
      swResolve.stop();
      print('Resolved $count services in ${swResolve.elapsedMilliseconds}ms');
    });
  });
}
