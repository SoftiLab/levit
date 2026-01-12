import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';

class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

class MockObserver implements LxObserver {
  final List<Stream> streams = [];
  final List<LxNotifier> notifiers = [];

  @override
  void addStream<T>(Stream<T> stream) {
    streams.add(stream);
  }

  @override
  void addNotifier(LxNotifier notifier) {
    notifiers.add(notifier);
  }
}

class TestMiddleware extends LxMiddleware {
  final void Function(StateChange)? onAfter;
  final bool allowChange;

  TestMiddleware({this.onAfter, this.allowChange = true});

  @override
  bool onBeforeChange<T>(StateChange<T> change) => allowChange;

  @override
  void onAfterChange<T>(StateChange<T> change) {
    onAfter?.call(change);
  }

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}
}

/// Middleware that uses the default onBeforeChange implementation
class MinimalMiddleware extends LxMiddleware {
  final List<StateChange> changes = [];

  @override
  void onAfterChange<T>(StateChange<T> change) {
    changes.add(change);
  }

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}
}

/// Default Middleware for testing
class DefaultMiddleware extends LxMiddleware {
  @override
  void onAfterChange<T>(StateChange<T> change) {}

  @override
  void onBatchStart() {}

  @override
  void onBatchEnd() {}
}

/// Mutable user class for testing mutate()
class MutableUser {
  String name;
  int age;
  MutableUser(this.name, this.age);
}
