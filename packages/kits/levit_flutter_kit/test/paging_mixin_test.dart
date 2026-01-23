import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_kit/levit_flutter_kit.dart';

class PagingController extends LevitController with LevitPagingScrollMixin {
  int loadMoreCalls = 0;

  @override
  void onLoadNextPage() {
    loadMoreCalls++;
  }
}

void main() {
  testWidgets('LevitPagingScrollMixin triggers load when scrolled',
      (tester) async {
    final controller = PagingController();
    controller.onInit();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller.scrollController,
            itemCount: 50,
            itemExtent: 50.0, // Total height: 2500
            itemBuilder: (c, i) => Text('Item $i'),
          ),
        ),
      ),
    );

    // Initial state
    expect(controller.loadMoreCalls, 0);

    // Scroll to bottom (2500 - 600 viewport = 1900 max offset).
    // Threshold is 200.
    // If we scroll to 1800, remaining is 100 <= 200, so it should trigger.

    controller.scrollController.jumpTo(1800.0);
    await tester.pumpAndSettle();

    expect(controller.loadMoreCalls, 1);

    // Scroll up (away from bottom)
    controller.scrollController.jumpTo(100.0);
    await tester.pumpAndSettle();

    // Should not trigger again
    expect(controller.loadMoreCalls, 1);

    controller.onClose();
  });
}
