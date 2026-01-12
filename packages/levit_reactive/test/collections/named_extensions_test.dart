import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Named Collections Extensions', () {
    test('List.lx creates LxList with flags', () {
      final list = <int>[1, 2, 3].lx..flags['name'] = 'myList';
      expect(list, isA<LxList<int>>());
      expect(list.flags['name'], equals('myList'));
      expect(list, equals([1, 2, 3]));
    });

    test('Map.lx creates LxMap with flags', () {
      final map = {'a': 1}.lx..flags['name'] = 'myMap';
      expect(map, isA<LxMap<String, int>>());
      expect(map.flags['name'], equals('myMap'));
      expect(map['a'], equals(1));
    });

    test('Set.lx creates LxSet with flags', () {
      final set = <int>{1, 2}.lx..flags['name'] = 'mySet';
      expect(set, isA<LxSet<int>>());
      expect(set.flags['name'], equals('mySet'));
      expect(set.contains(1), isTrue);
    });
  });
}
