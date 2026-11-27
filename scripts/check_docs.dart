import 'dart:io';

Future<void> main(List<String> args) async {
  final rootDir = Directory.current;
  final targets = args.where((a) => !a.startsWith('--')).toList();
  final packages = targets.isEmpty
      ? _discoverDocPackages(rootDir)
      : targets.map((p) => Directory('${rootDir.path}/$p')).toList();

  if (packages.isEmpty) {
    stderr.writeln('No packages with dartdoc_options.yaml found.');
    exit(1);
  }

  final tempRoot = Directory.systemTemp.createTempSync('levit_dartdoc_');
  var failed = false;
  try {
    for (final dir in packages) {
      final label = dir.path.replaceFirst('${rootDir.path}/', '');
      if (!dir.existsSync()) {
        stderr.writeln('Package directory not found: $label');
        failed = true;
        continue;
      }

      final pkgName = dir.path.split(Platform.pathSeparator).last;
      stdout.writeln('[$label] Validating dartdoc...');
      final result = await Process.run(Platform.resolvedExecutable, [
        'doc',
        '--validate-links',
        '--output=${tempRoot.path}/$pkgName',
      ], workingDirectory: dir.path);

      final combined = '${result.stdout}\n${result.stderr}';
      final hasWarnings =
          result.exitCode != 0 ||
          RegExp(r'^\s*warning:', multiLine: true).hasMatch(combined);
      if (hasWarnings) {
        stderr.writeln('[$label] dart doc validation failed.');
        if (result.stdout.toString().trim().isNotEmpty) {
          stderr.writeln(result.stdout.toString().trimRight());
        }
        if (result.stderr.toString().trim().isNotEmpty) {
          stderr.writeln(result.stderr.toString().trimRight());
        }
        failed = true;
        continue;
      }

      stdout.writeln('[$label] dart doc passed.');
    }
  } finally {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  }

  if (failed) exit(1);
  stdout.writeln(
    'DartDoc validation passed for ${packages.length} package(s).',
  );
}

List<Directory> _discoverDocPackages(Directory rootDir) {
  final packagesRoot = Directory('${rootDir.path}/packages');
  if (!packagesRoot.existsSync()) return const [];
  final dirs =
      packagesRoot
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) {
            final parts = f.path.split(Platform.pathSeparator);
            return parts.last == 'dartdoc_options.yaml' &&
                !parts.contains('.dart_tool') &&
                !parts.contains('build') &&
                !parts.contains('example') &&
                !parts.contains('examples');
          })
          .map((f) => f.parent)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return dirs;
}
