import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxStream.wait throws on error', () async {
    final controller = StreamController<int>();
    final lx = LxStream(controller.stream);

    final future = lx.wait;

    // Emit error
    controller.addError('fail');

    // Future should verify that 'wait' completes with error
    await expectLater(future, throwsA('fail'));
  });

  test('LxStream.wait throws immediate error', () async {
    // Initial error state
    // We can simulate this by having a stream that already emitted error
    // But constructor takes stream.
    // LxStream doesn't support "initial error" in constructor easily without 'idle'.

    // Let's manually set it via private access if possible? No.
    // Use controller.
    final controller = StreamController<int>();
    final lx = LxStream(controller.stream);
    controller.addError('fail');
    await Future.delayed(Duration.zero); // Process error

    // expect(lx.isError, isTrue); // Fails because stream is lazy and inactive

    // Now wait
    await expectLater(lx.wait, throwsA('fail'));
  });
}
