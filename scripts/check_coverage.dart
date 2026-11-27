import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final generateReportFile = args.contains('--generate-report');
  final quiet = args.contains('--quiet');
  final onlyPackages = _parseArg(
    args,
    '--only',
  )?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  final timeoutSeconds = int.tryParse(_parseArg(args, '--timeout') ?? '');
  final failUnder = double.tryParse(_parseArg(args, '--fail-under') ?? '');
  final targetPaths = args.where((arg) => !arg.startsWith('--')).toList();
  if (targetPaths.isEmpty) targetPaths.add('packages');

  void log(String message) {
    if (!quiet) print(message);
  }

  final packages = _discoverPackages(rootDir, targetPaths, onlyPackages);
  if (packages.isEmpty) {
    log('No packages found in target paths.');
    return;
  }

  log(
    'Found ${packages.length} package(s): '
    '${packages.map(_basename).join(', ')}\n',
  );

  final timeout = timeoutSeconds == null
      ? null
      : Duration(seconds: timeoutSeconds);
  final stats = <String, PackageStats>{};
  final globalStats = PackageStats('GLOBAL');
  var hasFailures = false;

  for (final package in packages) {
    final name = _basename(package);
    log('[$name] Running tests and collecting LCOV...');

    final ignoredFiles = findCoverageIgnoreFiles(package);
    if (ignoredFiles.isNotEmpty) {
      print('[$name] Remove coverage ignore directives from:');
      for (final path in ignoredFiles) {
        print('  $path');
      }
      hasFailures = true;
      continue;
    }

    final testDir = Directory('${package.path}/test');
    if (!testDir.existsSync() ||
        !testDir
            .listSync(recursive: true)
            .any((f) => f is File && f.path.endsWith('_test.dart'))) {
      log('[$name] No test files found. Skipping.');
      continue;
    }

    final coverageDir = Directory('${package.path}/coverage');
    if (coverageDir.existsSync()) await coverageDir.delete(recursive: true);

    final useDartTest =
        !_isFlutterPackage(package) || _usesDartMirrors(testDir);
    final result = await _runPackageTests(
      package,
      useDartTest: useDartTest,
      timeout: timeout,
    );
    if (result != null) {
      print('[$name] $result');
      hasFailures = true;
      continue;
    }

    final lcovFile = File('${package.path}/coverage/lcov.info');
    if (!lcovFile.existsSync()) {
      print('[$name] No coverage/lcov.info file generated.');
      hasFailures = true;
      continue;
    }

    _normalizeLcovPaths(lcovFile, package.path, rootDir.path);
    final packageStats = parseLcov(lcovFile, name);
    stats[name] = packageStats;
    globalStats.merge(packageStats);
    log('[$name] Done (${packageStats.coveragePercent.toStringAsFixed(1)}%).');
  }

  await _emitReport(
    stats,
    globalStats,
    writeFile: generateReportFile,
    quiet: quiet,
  );

  if (failUnder != null) {
    final failing =
        stats.values.where((s) => s.coveragePercent < failUnder).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (globalStats.coveragePercent < failUnder || failing.isNotEmpty) {
      print(
        'Coverage threshold failed: expected >= ${failUnder.toStringAsFixed(2)}% '
        '(global: ${globalStats.coveragePercent.toStringAsFixed(2)}%).',
      );
      for (final pkg in failing) {
        print('  ${pkg.name}: ${pkg.coveragePercent.toStringAsFixed(2)}%');
      }
      hasFailures = true;
    }
  }

  if (quiet && !hasFailures) {
    print(
      'Coverage: ${globalStats.coveragePercent.toStringAsFixed(2)}% '
      'across ${stats.length} package(s).',
    );
  }

  if (hasFailures) exit(1);
}

class PackageStats {
  final String name;
  int totalLines = 0;
  int coveredLines = 0;
  final Map<String, List<int>> uncoveredFiles = {};

  PackageStats(this.name);

  double get coveragePercent =>
      totalLines == 0 ? 100.0 : (coveredLines / totalLines * 100);

  void merge(PackageStats other) {
    totalLines += other.totalLines;
    coveredLines += other.coveredLines;
  }
}

PackageStats parseLcov(File file, String packageName) {
  final stats = PackageStats(packageName);
  final fileHits = <String, Map<int, int>>{};
  String? currentFile;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3);
      currentFile = path.replaceAll('\\', '/').split('/').contains('lib')
          ? path
          : null;
    } else if (currentFile != null && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineMap = fileHits.putIfAbsent(currentFile, () => {});
        final lineNum = int.parse(parts[0]);
        lineMap[lineNum] = (lineMap[lineNum] ?? 0) + int.parse(parts[1]);
      }
    }
  }

  for (final entry in fileHits.entries) {
    for (final lineEntry in entry.value.entries) {
      stats.totalLines++;
      if (lineEntry.value > 0) {
        stats.coveredLines++;
      } else {
        stats.uncoveredFiles
            .putIfAbsent(entry.key, () => [])
            .add(lineEntry.key);
      }
    }
  }
  return stats;
}

List<String> findCoverageIgnoreFiles(Directory package) {
  final lib = Directory('${package.path}/lib');
  if (!lib.existsSync()) return [];
  final directive = RegExp(r'//\s*coverage:ignore-(?:file|start|end|line)\b');
  return lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => directive.hasMatch(f.readAsStringSync()))
      .map((f) => f.path)
      .toList();
}

Future<String?> _runPackageTests(
  Directory package, {
  required bool useDartTest,
  required Duration? timeout,
}) async {
  final command = useDartTest
      ? ['dart', 'test', '--coverage=coverage']
      : ['flutter', 'test', '--coverage', '--concurrency=1'];
  final result = await _runProcess(
    command,
    workingDirectory: package.path,
    timeout: timeout,
  );
  if (result.timedOut) return 'Timed out.';
  if (result.exitCode != 0) {
    return 'Tests failed.\n${result.stdout}\n${result.stderr}'.trim();
  }

  if (!useDartTest) return null;
  final formatted = await _runProcess(
    [
      'dart',
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--in=coverage',
      '--out=coverage/lcov.info',
      '--packages=.dart_tool/package_config.json',
      '--report-on=lib',
    ],
    workingDirectory: package.path,
    timeout: timeout,
  );
  if (formatted.timedOut) return 'LCOV formatting timed out.';
  if (formatted.exitCode != 0) {
    return 'LCOV formatting failed.\n${formatted.stdout}\n${formatted.stderr}'
        .trim();
  }
  return null;
}

Future<({int exitCode, String stdout, String stderr, bool timedOut})>
_runProcess(
  List<String> command, {
  required String workingDirectory,
  Duration? timeout,
}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );
  final outFuture = process.stdout.transform(utf8.decoder).join();
  final errFuture = process.stderr.transform(utf8.decoder).join();
  var timedOut = false;
  int code;
  try {
    code = timeout == null
        ? await process.exitCode
        : await process.exitCode.timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    code = -1;
  }
  return (
    exitCode: code,
    stdout: await outFuture,
    stderr: await errFuture,
    timedOut: timedOut,
  );
}

List<Directory> _discoverPackages(
  Directory rootDir,
  List<String> targetPaths,
  Set<String>? onlyPackages,
) {
  bool isSkipped(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.contains('.dart_tool') ||
        parts.contains('example') ||
        parts.contains('examples');
  }

  final found = <String, Directory>{};
  for (final target in targetPaths) {
    final dir = Directory('${rootDir.path}/$target');
    if (!dir.existsSync()) continue;
    final candidates = [
      dir,
      ...dir.listSync(recursive: true).whereType<Directory>(),
    ];
    for (final candidate in candidates) {
      if (isSkipped(candidate.path)) continue;
      if (!File('${candidate.path}/pubspec.yaml').existsSync()) continue;
      final name = _basename(candidate);
      if (onlyPackages != null &&
          !onlyPackages.contains(name) &&
          !onlyPackages.contains(candidate.path)) {
        continue;
      }
      found[candidate.path] = candidate;
    }
  }
  return found.values.toList()..sort((a, b) => a.path.compareTo(b.path));
}

Future<void> _emitReport(
  Map<String, PackageStats> stats,
  PackageStats globalStats, {
  required bool writeFile,
  required bool quiet,
}) async {
  final names = stats.keys.toList()..sort();
  final md = StringBuffer()
    ..writeln('# Levit Coverage Report')
    ..writeln()
    ..writeln(
      '> Generated on: ${DateTime.now().toIso8601String().split('T')[0]}',
    )
    ..writeln()
    ..writeln('| Package | Covered | Total | Coverage |')
    ..writeln('| :--- | ---: | ---: | ---: |');
  for (final name in names) {
    final s = stats[name]!;
    md.writeln(
      '| $name | ${s.coveredLines} | ${s.totalLines} | '
      '${s.coveragePercent.toStringAsFixed(2)}% |',
    );
  }
  md.writeln(
    '| **GLOBAL** | **${globalStats.coveredLines}** | '
    '**${globalStats.totalLines}** | '
    '**${globalStats.coveragePercent.toStringAsFixed(2)}%** |',
  );

  final uncovered = names.where((n) => stats[n]!.coveragePercent < 100);
  if (uncovered.isNotEmpty) {
    md
      ..writeln()
      ..writeln('## Uncovered Lines');
    for (final name in uncovered) {
      md.writeln('\n### $name');
      stats[name]!.uncoveredFiles.forEach((file, lines) {
        md.writeln('- `$file`: ${_formatRanges(lines)}');
      });
    }
  }

  if (!quiet) print('\n${md.toString().trimRight()}');
  if (writeFile) {
    final out = File('coverage/packages_test_coverage.md');
    out.parent.createSync(recursive: true);
    await out.writeAsString(md.toString());
    if (!quiet) print('\nReport written to ${out.path}');
  }
}

String _formatRanges(List<int> lines) {
  if (lines.isEmpty) return '';
  final sorted = [...lines]..sort();
  final ranges = <String>[];
  var start = sorted.first;
  var end = sorted.first;
  for (final line in sorted.skip(1)) {
    if (line == end + 1) {
      end = line;
    } else {
      ranges.add(start == end ? '$start' : '$start-$end');
      start = end = line;
    }
  }
  ranges.add(start == end ? '$start' : '$start-$end');
  return ranges.join(', ');
}

void _normalizeLcovPaths(File lcovFile, String packagePath, String rootPath) {
  final content = lcovFile.readAsStringSync();
  var relativePkg = packagePath.replaceFirst(rootPath, '');
  if (relativePkg.startsWith(Platform.pathSeparator)) {
    relativePkg = relativePkg.substring(1);
  }
  final normalizedPkg = packagePath.replaceAll('\\', '/');
  final updated = content
      .replaceAll('SF:lib/', 'SF:$relativePkg/lib/')
      .replaceAll('SF:$normalizedPkg/lib/', 'SF:$relativePkg/lib/');
  if (updated != content) lcovFile.writeAsStringSync(updated);
}

bool _usesDartMirrors(Directory testDir) => testDir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .any((f) {
      final text = f.readAsStringSync();
      return text.contains("import 'dart:mirrors'") ||
          text.contains('import "dart:mirrors"');
    });

bool _isFlutterPackage(Directory packageDir) {
  final pubspec = File('${packageDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return true;
  final text = pubspec.readAsStringSync();
  return RegExp(r'^\s*sdk:\s*flutter\s*$', multiLine: true).hasMatch(text) ||
      RegExp(r'^\s*flutter:\s*$', multiLine: true).hasMatch(text);
}

String? _parseArg(List<String> args, String key) {
  final prefix = '$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length).trim();
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

String _basename(Directory dir) => dir.path.split(Platform.pathSeparator).last;
