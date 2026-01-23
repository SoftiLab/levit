import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CounterPage(),
    );
  }
}

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() {
    count.value++;
  }
}

class CounterPage extends LScopedView<CounterController> {
  const CounterPage({super.key});

  @override
  CounterController createController() => CounterController();

  @override
  Widget buildContent(BuildContext context, CounterController controller) {
    return Scaffold(
      appBar: AppBar(title: const Text('Levit Flutter Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '${controller.count.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
