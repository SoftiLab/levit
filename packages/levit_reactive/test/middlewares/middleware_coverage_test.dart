import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  group('Middleware Coverage', () {
    tearDown(() {
      Lx.middlewares.clear();
      Lx.captureStackTrace = false;
    });

    group('LxLoggerMiddleware', () {
      test('logs with default formatter', () {
        final logs = <String>[];
        final logger = LxLoggerMiddleware();

        // Mock print using runZoned
        runZoned(() {
          Lx.middlewares.add(logger);
          final count = 0.lx;
          count.value = 1;
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs, isNotEmpty);
        expect(logs.any((l) => l.contains('[Lx]')), isTrue);
        expect(logs.any((l) => l.contains('0 → 1')), isTrue);
      });

      test('filters logs based on name', () {
        final logs = <String>[];
        final logger = LxLoggerMiddleware(filter: (name) => name == 'keep');

        runZoned(() {
          Lx.middlewares.add(logger);
          final keep = Lx(0)..flags['name'] = 'keep';
          final skip = Lx(0)..flags['name'] = 'skip';

          keep.value = 1;
          skip.value = 1;
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs.any((l) => l.contains('keep')), isTrue);
        expect(logs.any((l) => l.contains('skip')), isFalse);
      });

      test('uses custom formatter', () {
        final logs = <String>[];
        final logger =
            LxLoggerMiddleware(formatter: (c) => 'CUSTOM: ${c.newValue}');

        runZoned(() {
          Lx.middlewares.add(logger);
          final count = 0.lx;
          count.value = 5;
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs, contains('CUSTOM: 5'));
      });

      test('includes stack trace when enabled', () {
        final logs = <String>[];
        // We need Lx.captureStackTrace to be true for the event to have stacks
        Lx.captureStackTrace = true;
        final logger = LxLoggerMiddleware(includeStackTrace: true);

        runZoned(() {
          Lx.middlewares.add(logger);
          final count = 0.lx;
          count.value = 1;
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        // It prints the stack trace object, which usually converts to string
        expect(logs.length, greaterThan(1));
      });

      test('logs batch events', () {
        final logs = <String>[];
        final logger = LxLoggerMiddleware();

        runZoned(() {
          Lx.middlewares.add(logger);
          Lx.batch(() {});
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs, contains('[Lx] Batch started'));
        expect(logs, contains('[Lx] Batch ended'));
      });
    });

    group('LxHistoryMiddleware', () {
      test('undo/redo return false when empty', () {
        final history = LxHistoryMiddleware();
        expect(history.undo(), isFalse);
        expect(history.redo(), isFalse);
      });

      test('toJson serialization', () {
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);
        final count = 0.lx;
        count.value = 1;
        history.undo();

        final json = history.toJson();
        expect(json['canUndo'], isFalse);
        expect(json['canRedo'], isTrue);
        expect(json['undoStack'], isEmpty);
        expect(json['redoStack'], isNotEmpty);
      });

      test('changesFor filters correctly', () {
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);

        final a = Lx(0)..flags['name'] = 'A';
        final b = Lx(0)..flags['name'] = 'B';

        a.value = 1;
        b.value = 1;
        a.value = 2;

        expect(history.changesFor('A').length, equals(2));
        expect(history.changesFor('B').length, equals(1));
      });

      test('printHistory output', () {
        final logs = <String>[];
        final history = LxHistoryMiddleware();

        runZoned(() {
          Lx.middlewares.add(history);
          final count = 0.lx;
          count.value = 1;
          history.undo();
          history.printHistory();
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs, contains('--- Undo Stack ---')); // even if empty
        expect(logs, contains('--- Redo Stack ---'));
        expect(logs.any((l) => l.contains('0 → 1')), isTrue);
      });

      test('handles composite change in undo/redo', () {
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);

        final a = 0.lx;
        final b = 0.lx;

        Lx.batch(() {
          a.value = 1;
          b.value = 1;
        });

        expect(history.length, equals(1)); // 1 composite change

        history.undo();
        expect(a.value, equals(0));
        expect(b.value, equals(0));

        history.redo();
        expect(a.value, equals(1));
        expect(b.value, equals(1));
      });
    });

    group('Lx Core Coverage', () {
      test('onListen and onCancel callbacks', () async {
        bool listened = false;
        bool cancelled = false;

        final count = Lx(
          0,
          onListen: () => listened = true,
          onCancel: () => cancelled = true,
        );

        final sub = count.stream.listen((_) {});
        await Future.delayed(Duration.zero);
        expect(listened, isTrue);

        await sub.cancel();
        await Future.delayed(Duration.zero);
        expect(cancelled, isTrue);
      });

      test('bind handles errors', () async {
        final controller = StreamController<int>();
        final count = 0.lx;
        count.bind(controller.stream);

        // We expect the error to be propagated
        final future = expectLater(count.stream, emitsError('Stream Error'));

        controller.addError('Stream Error');

        await future;
        await controller.close();
      });

      test('equality checks', () {
        final count = 1.lx;
        final count2 = 1.lx;
        final diff = 2.lx;

        expect(count == count, isTrue);
        expect(count == count2, isTrue);
        expect(count == 1, isTrue);
        expect(count == diff, isFalse);
        expect(count == 2, isFalse);
        expect(count == Object(), isFalse);

        expect(count.toString(), equals('1'));
      });

      test('toJson includes stack trace', () {
        Lx.captureStackTrace = true;
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);
        final count = 0.lx;
        count.value = 1;

        final json = history.changes.first.toJson();
        expect(json.containsKey('stackTrace'), isTrue);
      });

      test('CompositeStateChange properties', () {
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);

        Lx.batch(() {
          0.lx.value = 1;
        });

        // Verify CompositeStateChange specific getters
        final composite = history.changes.first as CompositeStateChange;

        // Access via dynamic to handle 'void' return type in tests
        expect((composite as dynamic).oldValue, isNull);
        expect((composite as dynamic).newValue, isNull);

        expect(composite.stackTrace, isNull);
        expect(composite.restore, isNull);
        expect(composite.name, contains('Batch'));
        expect(composite.toString(), contains('Batch'));
      });

      test('CompositeStateChange stopPropagation', () {
        final history = LxHistoryMiddleware();
        Lx.middlewares.add(history);
        Lx.batch(() {
          0.lx.value = 1;
        });

        final composite = history.changes.first as CompositeStateChange;
        expect(composite.isPropagationStopped, isFalse);

        composite.stopPropagation();
        expect(composite.isPropagationStopped, isTrue);
      });
    });
  });
}
