import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'new rules from a package preset fail CI and local overrides take effect',
    () async {
      final dir = await Directory.systemTemp.createTemp('levit-lint-fixture-');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/.dart_tool').create();
      await Directory('${dir.path}/lib').create();
      await Directory('${dir.path}/preset/lib').create(recursive: true);
      await File('${dir.path}/.dart_tool/package_config.json').writeAsString('''
{"configVersion":2,"packages":[
  {"name":"fixture","rootUri":"../","packageUri":"lib/","languageVersion":"3.2"},
  {"name":"rules","rootUri":"../preset/","packageUri":"lib/","languageVersion":"3.2"}
]}
''');
      await File('${dir.path}/lib/counter.dart').writeAsString('''
class Counter {
  int reads = 0;
  int get value => ++reads;
}
''');
      final preset = File('${dir.path}/preset/lib/team.yaml');
      await preset.writeAsString(
        'linter:\n  rules:\n    unnecessary_statements: true\n',
      );
      final options = File('${dir.path}/analysis_options.yaml');
      await options.writeAsString('include: package:rules/team.yaml\n');
      final source = File('${dir.path}/main.dart');
      await source.writeAsString('''
import 'package:fixture/counter.dart';
void read(Counter counter) {
  counter.value;
  print("read");
}
''');

      Future<ProcessResult> scan() => Process.run(Platform.resolvedExecutable, [
        '--suppress-analytics',
        'run',
        'scripts/check_source_lints.dart',
        source.path,
      ]);

      final first = await scan();
      expect(first.exitCode, 1, reason: '${first.stderr}');
      expect(first.stdout, contains('main.dart:3:3: [unnecessary_statements]'));
      expect(first.stdout, isNot(contains('[avoid_print]')));

      await preset.writeAsString(
        '    avoid_print: true\n    prefer_single_quotes: true\n',
        mode: FileMode.append,
      );
      final expanded = await scan();
      expect(expanded.exitCode, 1, reason: '${expanded.stderr}');
      for (final code in [
        'unnecessary_statements',
        'avoid_print',
        'prefer_single_quotes',
      ]) {
        expect(expanded.stdout, contains('[$code]'));
      }

      await options.writeAsString(
        'linter:\n  rules:\n    avoid_print: false\n',
        mode: FileMode.append,
      );
      await source.writeAsString(
        "import 'package:fixture/counter.dart';\nvoid read(Counter counter) => print(counter.value);\n",
      );
      final clean = await scan();
      expect(clean.exitCode, 0, reason: '${clean.stdout}\n${clean.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
