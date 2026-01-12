import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class TestController extends LevitDisposable {}

class TestView extends LView<TestController> {
  const TestView({super.key});

  @override
  TestController createController() => TestController();

  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return const SizedBox.shrink();
  }
}

void main() {
  group('Stress Test: LView Churn', () {
    testWidgets('Rapidly mount and unmount LViews', (tester) async {
      print(
          '[Description] Tests the lifecycle efficiency of LView and its controllers by rapidly mounting and unmounting 50,000 instances.');
      final iterations = 500;
      final viewCount = 100;

      final sw = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: List.generate(
                  viewCount, (j) => TestView(key: ValueKey('view-$i-$j'))),
            ),
          ),
        );

        // Clean up DI if they are permanent, but LView by default doesn't make them permanent
        // unless specified. Here they are created per view.

        // Pump an empty widget to trigger unmount
        await tester.pumpWidget(const SizedBox.shrink());

        // Reset Levit to avoid memory growth in tests
        Levit.reset(force: true);
      }

      final totalTime = sw.elapsedMilliseconds;
      print(
          'Performed $iterations view churn cycles (100 views each) in ${totalTime}ms');
    });
  });
}
