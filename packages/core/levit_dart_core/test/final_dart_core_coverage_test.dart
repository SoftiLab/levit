import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('levit_dart_core Final Gaps', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Ls.reset(force: true);
    });

    test('auto_linking.dart:157-161 - Context-based owner linking', () {
      Levit.enableAutoLinking();
      Lx.runWithOwner('my-context-owner', () {
        runCapturedForTesting(() {
          final rx2 = 0.lx;
          expect(rx2.ownerId, 'my-context-owner');
        });
      });
    });

    test('core.dart:178 & 190 - Levit.delete and Levit.isInstantiated', () {
      Levit.lazyPut(() => 'hello', tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isFalse);

      Levit.find<String>(tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isTrue);
      expect(Levit.delete<String>(tag: 'my-tag'), isTrue);
    });
  });
}
