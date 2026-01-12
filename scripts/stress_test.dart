import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  print('Running stress tests and generating report...');

  final process = await Process.start(
      'flutter',
      [
        'test',
        'lib/',
        '-r',
        'json',
      ],
      workingDirectory: 'stress_tests');

  final metrics = <Map<String, String>>[];
  final tests = <int, Map<String, dynamic>>{};
  final suites = <int, String>{};
  final descriptions = <int, String>{};

  // Transform stdout to lines
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      if (line.trim().isEmpty) return;
      try {
        final event = jsonDecode(line);
        final type = event['type'];

        if (type == 'suite') {
          final suite = event['suite'];
          // Normalize path to be relative to lib/ if possible
          String path = suite['path'] as String;
          if (path.contains('lib/')) {
            path = 'lib/${path.split('lib/').last}';
          }
          suites[suite['id']] = path;
        } else if (type == 'testStart') {
          final test = event['test'];
          tests[test['id']] = test;
        } else if (type == 'print') {
          final int? testId = event['testID'];
          final message = event['message'].toString();

          if (message.startsWith('[Description]')) {
            if (testId != null) {
              descriptions[testId] =
                  message.replaceFirst('[Description]', '').trim();
            }
          } else if (message.contains('took') ||
              message.contains(' in ') ||
              (message.contains(':') && message.contains('ms')) ||
              message.contains('Completed') ||
              message.contains('Captured') ||
              message.contains('time:')) {
            final test = tests[testId];
            final testName = test?['name'] ?? 'Setup/Global';
            final suiteId = test?['suiteID'];
            final suitePath = suites[suiteId] ?? 'Unknown';

            metrics.add({
              'test': testName,
              'message': message,
              'suite': suitePath,
              'description': testId != null ? (descriptions[testId] ?? '') : '',
            });
            print('[Metric] [$suitePath] $message');
          }
        }
      } catch (e) {
        // Ignore non-json lines or parse errors
      }
    },
  );

  // Ensure we wait for the process to fully exit
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    print(
      'Warning: Tests failed with exit code $exitCode. Report might be incomplete.',
    );
  } else {
    print('Tests finished successfully.');
  }

  _generateMarkdownReport(metrics);
}

Future<void> _generateMarkdownReport(List<Map<String, String>> metrics) async {
  final buffer = StringBuffer();
  buffer.writeln('# 🚀 Levit Framework Stress Test Report');
  buffer.writeln();
  buffer.writeln(
    '> **Generated on:** ${DateTime.now().toIso8601String().split('T')[0]}',
  );
  buffer.writeln();

  // Group metrics by package
  final reactiveMetrics =
      metrics.where((m) => m['suite']!.contains('levit_reactive')).toList();
  final diMetrics =
      metrics.where((m) => m['suite']!.contains('levit_di')).toList();
  final flutterMetrics =
      metrics.where((m) => m['suite']!.contains('levit_flutter')).toList();

  buffer.writeln('## 📊 Performance Summary');
  buffer.writeln();

  _writeMetricsTable(buffer, '🟦 Levit Reactive (Core)', reactiveMetrics);
  buffer.writeln();
  _writeMetricsTable(buffer, '🟨 Levit DI (Dependency Injection)', diMetrics);
  buffer.writeln();
  _writeMetricsTable(buffer, '🟪 Levit Flutter (UI Binding)', flutterMetrics);

  buffer.writeln();
  buffer.writeln('## 📜 Raw Execution Logs');
  buffer.writeln('<details>');
  buffer.writeln('<summary>Click to view full logs</summary>');
  buffer.writeln();
  buffer.writeln('```text');
  for (final item in metrics) {
    buffer.writeln('[${item['suite']}] [${item['test']}] ${item['message']}');
  }
  buffer.writeln('```');
  buffer.writeln('</details>');

  final reportDir = Directory('assets/reports');
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }

  final file = File('assets/reports/stress_test_report.md');
  await file.writeAsString(buffer.toString());
  print('Report generated: ${file.absolute.path}');
}

void _writeMetricsTable(
  StringBuffer buffer,
  String title,
  List<Map<String, String>> metrics,
) {
  buffer.writeln('### $title');
  buffer.writeln();
  if (metrics.isEmpty) {
    buffer.writeln('_No metrics captured for this category._');
    return;
  }

  buffer.writeln('| Scenario | Description | Measured Action | Result |');
  buffer.writeln('| :--- | :--- | :--- | :--- |');

  final timeRegExp = RegExp(r'(\d+(?:ms|us))');

  for (final item in metrics) {
    final testName = item['test']!;
    final message = item['message']!;

    // Extract Result (Time or Count)
    String result = '-';
    String action = message;

    final timeMatch = timeRegExp.firstMatch(message);
    if (timeMatch != null) {
      result = timeMatch.group(1)!;
    } else if (message.startsWith('Completed')) {
      final parts = message.split(' ');
      if (parts.length > 1) result = parts[1];
    } else if (message.startsWith('Captured')) {
      final parts = message.split(' ');
      if (parts.length > 1) result = parts[1];
    }

    // formatting action
    if (message.contains(' took ')) {
      action = message.split(' took ')[0].trim();
    } else if (message.contains(' in ')) {
      action = message.split(' in ')[0].trim();
    } else if (message.contains(':')) {
      final parts = message.split(':');
      if (parts.length > 1) action = parts[0].trim();
    }

    // Clean up test name (remove common prefixes if redundant)
    final displayTestName = testName.replaceAll('Stress Test: ', '');
    final description = item['description'] ?? '';

    buffer
        .writeln('| $displayTestName | $description | $action | **$result** |');
  }
}
