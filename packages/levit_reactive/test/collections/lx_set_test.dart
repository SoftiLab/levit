import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxSet', () {
    test('extension creates LxSet', () {
      final set = <String>{}.lx;
      expect(set, isA<LxSet<String>>());
      expect(set.isEmpty, isTrue);
    });

    test('add notifies observers', () async {
      final set = <String>{}.lx;

      var callCount = 0;
      set.stream.listen((_) => callCount++);

      set.add('test');
      await Future.delayed(Duration.zero);
      expect(callCount, 1);
      expect(set.contains('test'), isTrue);
    });

    test('remove notifies observers', () async {
      final set = {'a', 'b'}.lx;

      var callCount = 0;
      set.stream.listen((_) => callCount++);

      set.remove('a');
      await Future.delayed(Duration.zero);
      expect(callCount, 1);
      expect(set.contains('a'), isFalse);
    });

    test('clear notifies observers', () async {
      final set = {'a', 'b'}.lx;

      var callCount = 0;
      set.stream.listen((_) => callCount++);

      set.clear();
      await Future.delayed(Duration.zero);
      expect(callCount, 1);
      expect(set.isEmpty, isTrue);
    });

    test('addAll notifies observers', () async {
      final set = <int>{}.lx;

      var callCount = 0;
      set.stream.listen((_) => callCount++);

      set.addAll([1, 2]);
      await Future.delayed(Duration.zero);
      expect(callCount, 1);
      expect(set.length, 2);
    });

    test('removeAll notifies observers', () async {
      final set = {1, 2, 3}.lx;

      var callCount = 0;
      set.stream.listen((_) => callCount++);

      set.removeAll([1, 2]);
      await Future.delayed(Duration.zero);
      expect(callCount, 1);
      expect(set, equals({3}));
    });

    test('retainAll notifies observers', () {
      final set = {1, 2, 3, 4, 5}.lx;
      set.retainAll([2, 4]);
      expect(set.value, equals({2, 4}));
    });

    test('removeWhere notifies observers', () {
      final set = {1, 2, 3, 4, 5}.lx;
      set.removeWhere((e) => e.isOdd);
      expect(set.value, equals({2, 4}));
    });

    test('retainWhere notifies observers', () {
      final set = {1, 2, 3, 4, 5}.lx;
      set.retainWhere((e) => e.isEven);
      expect(set.value, equals({2, 4}));
    });

    test('containsAll works', () {
      final set = {1, 2, 3}.lx;
      expect(set.containsAll([1, 2]), isTrue);
      expect(set.containsAll([1, 4]), isFalse);
    });

    test('intersection works', () {
      final set = {1, 2, 3}.lx;
      final result = set.intersection({2, 3, 4});
      expect(result, equals({2, 3}));
    });

    test('union works', () {
      final set = {1, 2}.lx;
      final result = set.union({2, 3});
      expect(result, equals({1, 2, 3}));
    });

    test('difference works', () {
      final set = {1, 2, 3}.lx;
      final result = set.difference({2, 3});
      expect(result, equals({1}));
    });

    test('lookup works', () {
      final set = {'a', 'b', 'c'}.lx;
      expect(set.lookup('b'), equals('b'));
      expect(set.lookup('z'), isNull);
    });

    test('read-only methods work', () {
      final set = {1, 2, 3, 4, 5}.lx;

      // Properties
      expect(set.length, equals(5));
      expect(set.isEmpty, isFalse);
      expect(set.isNotEmpty, isTrue);
      expect(set.first, equals(1));
      expect(set.last, equals(5));
      expect(() => {1}.lx.single, returnsNormally);

      // Iteration methods
      expect(set.iterator, isNotNull);
      expect(set.where((e) => e > 3).toList(), equals([4, 5]));
      expect(set.whereType<int>().length, equals(5));
      expect(set.map((e) => e * 2).toList(), equals([2, 4, 6, 8, 10]));
      expect(set.expand((e) => [e, e]).length, equals(10));

      // forEach
      final collected = <int>[];
      set.forEach((e) => collected.add(e));
      expect(collected, equals([1, 2, 3, 4, 5]));

      // String
      expect(set.join(','), equals('1,2,3,4,5'));

      // Skip/Take
      expect(set.skip(2).toList(), equals([3, 4, 5]));
      expect(set.skipWhile((e) => e < 3).toList(), equals([3, 4, 5]));
      expect(set.take(2).toList(), equals([1, 2]));
      expect(set.takeWhile((e) => e < 3).toList(), equals([1, 2]));

      // Conversions
      expect(set.toList(), equals([1, 2, 3, 4, 5]));
      expect(set.toSet(), equals({1, 2, 3, 4, 5}));

      // Predicates
      expect(set.any((e) => e > 3), isTrue);
      expect(set.every((e) => e > 0), isTrue);

      // Fold/Reduce
      expect(set.fold<int>(0, (acc, e) => acc + e), equals(15));
      expect(set.reduce((a, b) => a + b), equals(15));

      // Element access
      expect(set.elementAt(2), equals(3));
      expect(set.firstWhere((e) => e > 2), equals(3));
      expect(set.lastWhere((e) => e < 4), equals(3));
      expect(set.singleWhere((e) => e == 3), equals(3));

      // Followed by
      expect(set.followedBy({6, 7}).toList(), equals([1, 2, 3, 4, 5, 6, 7]));

      // Cast
      expect(set.cast<num>().length, equals(5));
    });
  });
}
