import 'dart:async';
import 'package:levit_dart_kit/levit_dart_kit.dart';
import 'package:test/test.dart';
import 'package:levit_dart/levit_dart.dart';

class PeriodicController extends LevitController with LevitPeriodicMixin {}

class DebounceController extends LevitController with LevitDebounceMixin {}

void main() {
  group('LevitPeriodicMixin', () {
    test('startPeriodic runs callback repeatedly', () async {
      final controller = PeriodicController();
      controller.onInit();
      int count = 0;

      controller.startPeriodic(const Duration(milliseconds: 10), (timer) {
        count++;
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, greaterThanOrEqualTo(3));

      controller.onClose();
    });

    test('onClose cancels timer', () async {
      final controller = PeriodicController();
      controller.onInit();
      int count = 0;

      controller.startPeriodic(const Duration(milliseconds: 10), (timer) {
        count++;
      });

      await Future.delayed(const Duration(milliseconds: 20));
      final countBefore = count;

      controller.onClose();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, countBefore); // Should not increment after close
    });
  });

  group('LevitDebounceMixin', () {
    test('debounce limits execution', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      void trigger() =>
          controller.debounce('id', const Duration(milliseconds: 20), () {
            runs++;
          });

      trigger();
      trigger();
      trigger();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(runs, 1);

      controller.onClose();
    });

    test('cancelDebounce prevents execution', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      controller.debounce('id', const Duration(milliseconds: 20), () {
        runs++;
      });

      controller.cancelDebounce('id');

      await Future.delayed(const Duration(milliseconds: 50));
      expect(runs, 0);

      controller.onClose();
    });

    test('onClose cancels pending debounce', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      controller.debounce('id', const Duration(milliseconds: 50), () {
        runs++;
      });

      controller.onClose();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(runs, 0);
    });
  });
}
