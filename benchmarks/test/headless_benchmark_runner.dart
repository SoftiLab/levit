// ignore_for_file: avoid_print

import 'package:benchmarks/benchmark_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HeadlessBenchmarkRunner {
  final int iterations;

  HeadlessBenchmarkRunner({this.iterations = 50});

  /// Runs a logic benchmark without any UI.
  Future<BenchmarkResult> runLogicBenchmark(
    Benchmark benchmark,
    Framework framework,
  ) async {
    final impl = benchmark.createImplementation(framework);
    int totalDuration = 0;
    bool success = true;
    String? error;

    try {
      await impl.setup();

      // Warmup
      await impl.run();

      for (int i = 0; i < iterations; i++) {
        final duration = await impl.run();
        totalDuration += duration;
        // Small yield to avoid blocking everything
        await Future.delayed(Duration.zero);
      }
    } catch (e, stack) {
      success = false;
      error = '$e\n$stack';
      print('Error running ${benchmark.name} for ${framework.label}: $e');
    } finally {
      try {
        await impl.teardown();
      } catch (e) {
        print('Error tearing down ${benchmark.name}: $e');
      }
    }

    final avgDuration = success ? (totalDuration ~/ iterations) : 0;

    return BenchmarkResult(
      framework: framework,
      benchmarkName: benchmark.name,
      durationMicros: avgDuration,
      success: success,
      error: error,
    );
  }

  /// Runs a UI benchmark using WidgetTester.
  Future<BenchmarkResult> runUIBenchmark(
    WidgetTester tester,
    Benchmark benchmark,
    Framework framework,
  ) async {
    final impl = benchmark.createImplementation(framework);
    int totalDuration = 0;
    bool success = true;
    String? error;

    try {
      await impl.setup();

      // Mount the widget
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => impl.build(context)),
        ),
      ));

      // Allow layout/paint to settle
      await tester.pumpAndSettle();

      // Warmup
      await impl.run();
      await tester.pump();

      for (int i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        await impl.run(); // Triggers state change
        await tester.pump(); // Force rebuild/frame
        stopwatch.stop();

        totalDuration += stopwatch.elapsedMicroseconds;
      }

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
    } catch (e, stack) {
      success = false;
      error = '$e\n$stack';
      print('Error running ${benchmark.name} for ${framework.label}: $e');
    } finally {
      try {
        await impl.teardown();
      } catch (e) {
        print('Error tearing down ${benchmark.name}: $e');
      }
    }

    final avgDuration = success ? (totalDuration ~/ iterations) : 0;

    return BenchmarkResult(
      framework: framework,
      benchmarkName: benchmark.name,
      durationMicros: avgDuration,
      success: success,
      error: error,
    );
  }
}
