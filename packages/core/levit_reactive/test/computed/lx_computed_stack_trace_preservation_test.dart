import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

Never _throwFromComputedHelper() => throw StateError('boom');

void _expectOriginalStackTrace(void Function() trigger) {
  try {
    trigger();
    fail('Expected StateError');
  } on StateError catch (error, stackTrace) {
    expect(error.message, 'boom');
    expect(stackTrace.toString(), contains('_throwFromComputedHelper'));
  }
}

class _GraphChangeMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => (_, __) {};
}

void main() {
  test('active recompute preserves original stack trace', () {
    final source = 0.lx;
    final computed = LxComputed<int>(() {
      if (source() == 1) _throwFromComputedHelper();
      return source();
    });
    final worker = LxWorker(computed, (_) {});
    addTearDown(worker.close);

    _expectOriginalStackTrace(() => source.value = 1);
  });

  test('staticDeps recompute preserves original stack trace', () {
    final source = 0.lx;
    final computed = LxComputed<int>(() {
      if (source() == 1) _throwFromComputedHelper();
      return source();
    }, staticDeps: true);
    final worker = LxWorker(computed, (_) {});
    addTearDown(worker.close);

    _expectOriginalStackTrace(() => source.value = 1);
  });

  test('inactive pull read preserves original stack trace', () {
    final shouldThrow = false.lx;
    final computed = LxComputed<int>(() {
      if (shouldThrow()) _throwFromComputedHelper();
      return 1;
    });

    shouldThrow.value = true;

    _expectOriginalStackTrace(() => computed.value);
  });

  test('graph-captured pull read preserves original stack trace', () {
    final middleware = _GraphChangeMiddleware();
    Lx.addMiddleware(middleware);
    addTearDown(() => Lx.removeMiddleware(middleware));

    final shouldThrow = false.lx;
    final computed = LxComputed<int>(() {
      if (shouldThrow()) _throwFromComputedHelper();
      return 1;
    });

    shouldThrow.value = true;

    _expectOriginalStackTrace(() => computed.value);
  });

  test(
    'nested computed read with active proxy preserves original stack trace',
    () {
      final middleware = _GraphChangeMiddleware();
      Lx.addMiddleware(middleware);
      addTearDown(() => Lx.removeMiddleware(middleware));

      final shouldThrow = false.lx;
      final inner = LxComputed<int>(() {
        if (shouldThrow()) _throwFromComputedHelper();
        return 1;
      });
      final outer = LxComputed<int>(() => inner.value);

      shouldThrow.value = true;

      _expectOriginalStackTrace(() => outer.value);
    },
  );
}
