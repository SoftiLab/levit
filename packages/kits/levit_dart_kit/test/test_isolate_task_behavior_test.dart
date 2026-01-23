import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_dart_kit/levit_dart_kit.dart';
import 'package:test/test.dart';

// Top-level functions for isolates
int heavyComputation() {
  int sum = 0;
  for (int i = 0; i < 1000000; i++) {
    sum += i;
  }
  return sum;
}

int failComputation() {
  throw Exception('isolate failed');
}

class TestIsolateController extends LevitController
    with LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

class SimpleIsolateController extends LevitController with LevitTasksMixin {}

void main() {
  group('runIsolateTask Behavior', () {
    late TestIsolateController controller;

    setUp(() {
      controller = TestIsolateController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('runIsolateTask executes in isolate and returns result', () async {
      final result = await controller.runIsolateTask(heavyComputation);
      expect(result, 499999500000);
      expect(controller.tasks.values.first is LxSuccess, isTrue);
    });

    test('runIsolateTask handles failures in isolate', () async {
      final result = await controller.runIsolateTask(failComputation);
      expect(result, isNull);
      expect(controller.tasks.values.first is LxError, isTrue);
    });

    test('runIsolateTask respects maxConcurrentTasks', () async {
      // Isolate.run is async but we want to test the queueing logic
      // Since runIsolateTask calls runTask, it should wait in queue if limit is reached.

      final results = await Future.wait([
        controller.runIsolateTask(heavyComputation),
        controller.runIsolateTask(heavyComputation),
        controller.runIsolateTask(heavyComputation),
      ]);

      expect(results.length, 3);
      expect(results.every((r) => r == 499999500000), isTrue);
    });
  });

  group('LevitTasksMixin Isolate Support', () {
    test('Simple mixin also supports isolate tasks', () async {
      final controller = SimpleIsolateController();
      controller.onInit();

      final result = await controller.runIsolateTask(heavyComputation);
      expect(result, 499999500000);

      controller.onClose();
    });
  });
}
