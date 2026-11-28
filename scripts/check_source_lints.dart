import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Keep the packages used by analyzer presets, including transitive includes.
/// Application imports stay unresolved in this supplementary analysis.
Future<String> _presetConfig(ContextRoot context, String target) async {
  final configFile = context.packagesFile;
  final config = configFile == null
      ? PackageConfig.empty
      : await loadPackageConfig(File(configFile.path));
  final presets = <String, Package>{};
  final visited = <Uri>{};

  void readOptions(Uri file) {
    if (!visited.add(file)) return;
    final options = loadYaml(File.fromUri(file).readAsStringSync()) as YamlMap?;
    final includes = options?['include'];
    if (includes == null) return;
    for (final name in includes is String ? [includes] : includes as List) {
      final uri = file.resolve(name as String);
      if (uri.isScheme('package')) {
        final package = config[uri.pathSegments.first];
        final resolved = config.resolve(uri);
        if (package == null || resolved == null) {
          throw StateError('Cannot resolve $uri in $file');
        }
        presets[package.name] = package;
        readOptions(resolved);
      } else {
        readOptions(uri);
      }
    }
  }

  final options = context.optionsFile;
  if (options != null) readOptions(File(options.path).uri);
  // A nested options file can share its parent package's analysis context.
  for (final path in context.analyzedFiles()) {
    if (p.basename(path) == 'analysis_options.yaml') {
      readOptions(File(path).uri);
    }
  }
  var dir = Directory(
    FileSystemEntity.isDirectorySync(target) ? target : p.dirname(target),
  );
  while (p.isWithin(context.root.path, dir.path)) {
    final local = File(p.join(dir.path, 'analysis_options.yaml'));
    if (local.existsSync()) {
      readOptions(local.uri);
      break;
    }
    dir = dir.parent;
  }

  final packages = presets.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return jsonEncode(PackageConfig.toJson(PackageConfig(packages)));
}

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run scripts/check_source_lints.dart [file or directory]',
    );
    exitCode = 64;
    return;
  }
  // The analyzer reports canonical paths, including for files opened through a symlink.
  final target = File(
    args.isEmpty ? '.' : args.single,
  ).resolveSymbolicLinksSync();
  final repo = Directory.fromUri(
    Platform.script.resolve('../'),
  ).resolveSymbolicLinksSync();
  final baseline = File.fromUri(
    Platform.script.resolve('reviewed_source_lints.txt'),
  );
  final remaining = baseline
      .readAsLinesSync()
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
  final collection = AnalysisContextCollection(includedPaths: [target]);
  final temp = await Directory.systemTemp.createTemp('levit-source-lints-');
  var reviewed = 0;
  var findings = 0;
  try {
    // Most packages share a preset. Analyze once per distinct configuration and
    // accept each diagnostic only from its file's own configuration.
    final groups = <String, Set<ContextRoot>>{};
    for (final context in collection.contexts) {
      final config = await _presetConfig(context.contextRoot, target);
      groups.putIfAbsent(config, () => {}).add(context.contextRoot);
    }
    final sourceLines = <String, List<String>>{};
    for (final group in groups.entries) {
      final config = File.fromUri(temp.uri.resolve('package_config.json'));
      await config.writeAsString(group.key);
      final result = await Process.run(Platform.resolvedExecutable, [
        '--suppress-analytics',
        'analyze',
        '--format=json',
        '--packages=${config.path}',
        target,
      ]);
      // Unresolved application imports normally produce exit code 3.
      if (result.exitCode < 0 || result.exitCode > 3) {
        throw StateError(
          'Dart analyzer failed (${result.exitCode}): ${result.stderr}\n${result.stdout}',
        );
      }
      final report =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      for (final issue in report['diagnostics'] as List) {
        if (issue['type'] != 'LINT') continue;
        final location = issue['location'];
        final file = location['file'] as String;
        if (!group.value.any((context) => context.isAnalyzed(file))) {
          continue;
        }
        final start = location['range']['start'];
        final line = start['line'] as int;
        final code = issue['code'];
        final lines = sourceLines.putIfAbsent(
          file,
          () => File(file).readAsStringSync().split(RegExp(r'\r\n?|\n')),
        );
        final relative = p.split(p.relative(file, from: repo)).join('/');
        final key = '$relative|$code|${lines[line - 1].trim()}';
        if (remaining.remove(key)) {
          reviewed++;
        } else {
          stdout.writeln(
            "$file:$line:${start['column']}: [$code] ${issue['problemMessage']}",
          );
          findings++;
        }
      }
    }
    if (p.equals(target, repo) && remaining.isNotEmpty) {
      stderr.writeln(
        'Remove obsolete entries from ${baseline.path}:\n${remaining.join('\n')}',
      );
      exitCode = 1;
    }
    stdout.writeln(
      'Source-only Dart lints: $findings new, $reviewed reviewed.',
    );
    if (findings > 0) exitCode = 1;
  } finally {
    await collection.dispose();
    await temp.delete(recursive: true);
  }
}
