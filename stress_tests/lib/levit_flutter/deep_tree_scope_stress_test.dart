import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class DeepController extends LevitDisposable {}

class DeepView extends LView<DeepController> {
  const DeepView({super.key});

  @override
  Widget buildContent(BuildContext context, DeepController controller) {
    return Text('Resolved: $controller');
  }
}

void main() {
  group('Stress Test: Deep Tree Scoping', () {
    testWidgets('Resolve controller through 1,000 layers', (tester) async {
      print(
          '[Description] Measures the time to resolve a controller from a deep widget tree, testing LScope traversal efficiency.');
      final levels = 1000;
      final controller = DeepController();

      Widget buildLayer(int remaining) {
        if (remaining == 0) return const DeepView();
        return Builder(builder: (_) => buildLayer(remaining - 1));
      }

      final sw = Stopwatch()..start();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope<DeepController>(
            init: () => controller,
            child: buildLayer(levels),
          ),
        ),
      );

      final resolutionTime = sw.elapsedMilliseconds;
      print(
          'Resolved deep scope through $levels layers in ${resolutionTime}ms');

      expect(find.textContaining('Resolved: Instance of \'DeepController\''),
          findsOneWidget);
    });
  });
}
