import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxMap<K, V>', () {
    test('initial map is accessible', () {
      final settings = <String, int>{}.lx;
      expect(settings.value, isEmpty);
    });

    test('operator []= triggers stream event', () async {
      final settings = <String, int>{}.lx;
      final triggered = <bool>[];
      settings.stream.listen((_) => triggered.add(true));

      settings['volume'] = 50;

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(settings['volume'], equals(50));
    });

    test('addAll triggers stream event', () {
      final settings = <String, int>{}.lx;
      settings.addAll({'a': 1, 'b': 2});
      expect(settings.length, equals(2));
    });

    test('addEntries triggers stream event', () {
      final settings = <String, int>{}.lx;
      settings.addEntries([MapEntry('a', 1), MapEntry('b', 2)]);
      expect(settings.length, equals(2));
    });

    test('remove triggers stream event', () async {
      final settings = {'a': 1, 'b': 2}.lx;
      final triggered = <bool>[];
      settings.stream.listen((_) => triggered.add(true));

      settings.remove('a');

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(settings.containsKey('a'), isFalse);
    });

    test('removeWhere triggers stream event', () {
      final settings = {'a': 1, 'b': 2, 'c': 3}.lx;
      settings.removeWhere((k, v) => v.isOdd);
      expect(settings.value, equals({'b': 2}));
    });

    test('clear triggers stream event', () async {
      final settings = {'a': 1, 'b': 2}.lx;
      final triggered = <bool>[];
      settings.stream.listen((_) => triggered.add(true));

      settings.clear();

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(settings, isEmpty);
    });

    test('update triggers stream event', () {
      final settings = {'a': 1}.lx;
      settings.update('a', (v) => v * 2);
      expect(settings['a'], equals(2));
    });

    test('update with ifAbsent triggers stream event', () {
      final settings = <String, int>{}.lx;
      settings.update('a', (v) => v * 2, ifAbsent: () => 5);
      expect(settings['a'], equals(5));
    });

    test('updateAll triggers stream event', () {
      final settings = {'a': 1, 'b': 2}.lx;
      settings.updateAll((k, v) => v * 10);
      expect(settings.value, equals({'a': 10, 'b': 20}));
    });

    test('putIfAbsent triggers if absent', () {
      final settings = {'a': 1}.lx;
      settings.putIfAbsent('b', () => 2);
      expect(settings['b'], equals(2));
    });

    test('putIfAbsent does not trigger if present', () async {
      final settings = {'a': 1}.lx;
      final triggered = <bool>[];
      settings.stream.listen((_) => triggered.add(true));

      settings.putIfAbsent('a', () => 99);

      await Future.delayed(Duration.zero);
      expect(triggered, isEmpty);
      expect(settings['a'], equals(1));
    });

    test('map read-only methods work', () {
      final settings = {'a': 1, 'b': 2}.lx;
      expect(settings.length, equals(2));
      expect(settings.containsKey('a'), isTrue);
      expect(settings.containsValue(1), isTrue);
      expect(settings.isEmpty, isFalse);
      expect(settings.isNotEmpty, isTrue);
      expect(settings.keys, containsAll(['a', 'b']));
      expect(settings.values, containsAll([1, 2]));
      expect(settings.entries.length, equals(2));
    });

    test('forEach works', () {
      final settings = {'a': 1, 'b': 2}.lx;
      final result = <String>[];
      settings.forEach((k, v) => result.add('$k:$v'));
      expect(result, containsAll(['a:1', 'b:2']));
    });

    test('map transform works', () {
      final settings = {'a': 1, 'b': 2}.lx;
      final mapped = settings.map((k, v) => MapEntry(k.toUpperCase(), v * 10));
      expect(mapped, equals({'A': 10, 'B': 20}));
    });

    test('cast works', () {
      final settings = {'a': 1, 'b': 2}.lx;
      final casted = settings.cast<String, num>();
      expect(casted.keys, containsAll(['a', 'b']));
    });
  });
}
