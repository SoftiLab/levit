import 'package:levit/levit.dart';

void main() {
  // Levit kit re-exports levit_dart, levit_scope, and levit_reactive.

  // Example of using Lx (Reactive)
  final count = 0.lx;
  count.addListener(() {
    print('Count changed: ${count.value}');
  });

  count.value++;
}
