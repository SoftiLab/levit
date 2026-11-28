import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _LifecycleProbeController extends LevitController
    with LevitAppLifecycleMixin {
  int resumedCalls = 0;

  @override
  void onAppResumed() {
    resumedCalls++;
  }
}

class _AppAndLoopController extends LevitController
    with LevitLoopMixin, LevitLoopLifecycleMixin, LevitAppLifecycleMixin {}

void main() {
  test('lifecycle mixins forward pending cleanup and its failure', () async {
    final controller = _AppAndLoopController();
    final release = Completer<void>();
    final error = StateError('resource cleanup failed');
    controller.own(() async {
      await release.future;
      throw error;
    });

    final closing = controller.onClose();
    expect(controller.onClose(), same(closing));
    final check = expectLater(
      closing,
      throwsA(isA<LevitDisposalException>().having(
        (e) => e.failures.single.error,
        'resource error',
        same(error),
      )),
    );
    release.complete();
    await check;
  });

  testWidgets(
    'showLevitDialog keeps captured scope after launching widget unmounts',
    (tester) async {
      final showLauncher = true.lx;
      final rebuildDialog = 0.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LScope(
            configure: (s) => s.put<String>(() => 'captured-value'),
            child: LWatch(() {
              if (!showLauncher.value) {
                return const Scaffold(body: Text('replaced'));
              }
              return Scaffold(
                body: Builder(
                  builder: (launcherContext) => ElevatedButton(
                    onPressed: () {
                      unawaited(
                        showLevitDialog<void>(
                          context: launcherContext,
                          builder: (dialogContext) => LWatch(() {
                            final tick = rebuildDialog.value;
                            final value = dialogContext.levit.find<String>();
                            return AlertDialog(
                              content: Text('$value:$tick'),
                            );
                          }),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('captured-value:0'), findsOneWidget);

      // Unmount the launcher widget while the dialog remains open, then rebuild dialog.
      showLauncher.value = false;
      await tester.pumpAndSettle();
      rebuildDialog.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('captured-value:1'), findsOneWidget);
      await showLauncher.close();
      await rebuildDialog.close();
    },
  );

  testWidgets(
    'LevitAppLifecycleMixin detaches on requestCancel and ignores double onInit leak',
    (tester) async {
      final controller = _LifecycleProbeController();
      controller.onInit();
      controller.onInit();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.resumedCalls, 1);

      controller.requestCancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.resumedCalls, 1);

      await controller.onClose();
    },
  );
}
