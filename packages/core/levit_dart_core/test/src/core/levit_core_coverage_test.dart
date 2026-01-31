import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Levit Core and Auto-Linking Coverage', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Levit.reset(force: true);
    });

    test('Levit Core methods fallback coverage', () async {
      final state = LevitStore((ref) => 'ok');

      // findOrNull success/fail
      expect(Levit.findOrNull<String>(key: state), 'ok');
      final throwingState =
          LevitStore<String>((ref) => throw Exception('error'));
      expect(Levit.findOrNull<String>(key: throwingState), isNull);

      // findAsync success
      final asyncState = LevitStore.async((ref) async => 'async');
      expect(await Levit.findAsync<String>(key: asyncState), 'async');

      // findOrNullAsync success
      expect(await Levit.findOrNullAsync<String>(key: asyncState), 'async');

      final unregisteredAsync =
          LevitStore.async((ref) async => throw Exception('error'));
      expect(
          await Levit.findOrNullAsync<String>(key: unregisteredAsync), isNull);

      // isRegistered/isInstantiated (Lines 172, 181)
      final provider = LevitStore((ref) => 'p');
      expect(Levit.isRegistered(key: provider), false);
      provider.find();
      expect(Levit.isRegistered(key: provider), true);
      expect(Levit.isInstantiated(key: provider), true);
    });

    test('Auto-linking coverage gaps', () {
      Levit.enableAutoLinking();

      // runCaptured without ownerId (auto_linking.dart line 60)
      runCapturedForTesting(() => 1);

      // Chained capture and Adoption in processInstance (auto_linking.dart 184-185)
      Levit.put(() {
        1.lx;
        2.lx;
        return 'test';
      }, tag: 'multi');

      Levit.disableAutoLinking();
    });
  });
}
