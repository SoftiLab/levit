import '../benchmark_engine.dart';

class BenchmarkReporter {
  /// Generates a Markdown report from a map of benchmark results.
  static String generateMarkdownReport({
    required Map<String, List<BenchmarkResult>> results,
    String? title,
  }) {
    final buffer = StringBuffer();
    if (title != null) {
      buffer.writeln('# $title');
    } else {
      buffer.writeln('# Benchmark Results');
    }
    buffer.writeln('Date: ${DateTime.now()}');
    buffer.writeln('');

    for (final benchName in results.keys) {
      buffer.writeln('## $benchName');
      buffer.writeln('| Framework | Time (µs) | Status |');
      buffer.writeln('|---|---|---|');

      final sortedResults = List<BenchmarkResult>.from(results[benchName]!)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status = res.success ? 'OK' : 'Error: ${res.error}';
        buffer.writeln(
            '| ${res.framework.label} | ${res.durationMicros} | $status |');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generates a console-friendly report with aligned columns.
  static String generateConsoleReport({
    required Map<String, List<BenchmarkResult>> results,
    String? title,
  }) {
    final buffer = StringBuffer();
    final line = '=' * 80;
    final thinLine = '-' * 80;

    buffer.writeln('\n$line');
    buffer.writeln(title?.toUpperCase() ?? 'BENCHMARK RESULTS');
    buffer.writeln('Date: ${DateTime.now()}');
    buffer.writeln('$line\n');

    for (final benchName in results.keys) {
      buffer.writeln('>>> $benchName');
      buffer.writeln(thinLine);
      buffer.writeln(
          '${'Framework'.padRight(15)} | ${'Time (µs)'.padRight(12)} | ${'Time (ms)'.padRight(12)} | Status');
      buffer.writeln(thinLine);

      final sortedResults = List<BenchmarkResult>.from(results[benchName]!)
        ..sort((a, b) => a.durationMicros.compareTo(b.durationMicros));

      for (final res in sortedResults) {
        final status =
            res.success ? 'OK' : 'ERROR: ${res.error?.split('\n').first}';
        buffer.writeln('${res.framework.label.padRight(15)} | '
            '${res.durationMicros.toString().padRight(12)} | '
            '${res.durationMs.toStringAsFixed(3).padRight(12)} | '
            '$status');
      }
      buffer.writeln('$line\n');
    }

    return buffer.toString();
  }
}
