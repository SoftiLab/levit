import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LWatch Cleanup Strategies', () {
    testWidgets('switching dependencies removes obsolete listeners',
        (tester) async {
      final s1 = 0.lx;
      final s2 = 0.lx;

      await tester.pumpWidget(
        LWatch(() => SizedBox(width: s1.value.toDouble())),
      );
      expect(s1.hasListener, isTrue);
      expect(s2.hasListener, isFalse);

      await tester.pumpWidget(
        LWatch(() =>
            SizedBox(width: s1.value.toDouble(), height: s2.value.toDouble())),
      );
      expect(s1.hasListener, isTrue);
      expect(s2.hasListener, isTrue);

      await tester.pumpWidget(LWatch(() => const SizedBox.shrink()));
      expect(s1.hasListener, isFalse);
      expect(s2.hasListener, isFalse);

      await tester.pumpWidget(
        LWatch(() => SizedBox(width: s1.value.toDouble())),
      );
      expect(s1.hasListener, isTrue);

      await tester.pumpWidget(LWatch(() => const SizedBox.shrink()));
      expect(s1.hasListener, isFalse);
    });
  });
}
