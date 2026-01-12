import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  testWidgets('LScope warns on tag update', (tester) async {
    // We capture printed logs to verify the warning
    final logs = <String>[];

    // Override debugPrint to capture output
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    try {
      await tester.pumpWidget(
        LScope<String>(
          init: () => 'A',
          tag: 'tag1',
          child: const SizedBox(),
        ),
      );

      // Rebuild with different tag to trigger didUpdateWidget
      await tester.pumpWidget(
        LScope<String>(
          init: () => 'A',
          tag: 'tag2',
          child: const SizedBox(),
        ),
      );

      // Check if code path reached
      // The exact assertion behavior depends on flutter test mode, but
      // pumping the widget update forces the didUpdateWidget call.
      // If asserts are enabled (default in tests), verify log.
      expect(logs.any((l) => l.contains('LScope tag/name changed')), isTrue);
    } finally {
      debugPrint = originalDebugPrint;
    }
  });
}
