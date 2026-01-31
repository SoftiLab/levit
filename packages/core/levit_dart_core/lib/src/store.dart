part of '../levit_dart_core.dart';

/// A lightweight bridge passed to [LevitStore] builders.
///
/// [LevitRef] provides access to dependency injection and automated resource
/// management. It acts as a proxy to the [LevitScope] that owns the instance.
abstract class LevitRef {
  /// The [LevitScope] that currently owns this instance.
  LevitScope get scope;

  /// Resolves a dependency of type [S] from the current or parent scope.
  S find<S>({dynamic key, String? tag});

  /// Asynchronously resolves a dependency of type [S].
  Future<S> findAsync<S>({dynamic key, String? tag});

  /// Registers a [callback] to be executed when the instance is disposed.
  void onDispose(void Function() callback);

  /// Registers an [object] for automatic cleanup when the instance is disposed.
  T autoDispose<T>(T object);
}

/// A [LevitStore] is a static, initialization-once container for state and logic.
///
/// 1. Executes its builder when first accessed.
/// 2. Provides a stable, persistent object (like a Controller) that stays alive until the scope is disposed.
///
/// Reactivity should be handled by creating [LxReactive] variables *inside* the store.
///
/// Example:
/// ```dart
/// final counterStore = LevitStore((ref) {
///   final count = 0.lx; // Reactive variable
///   void increment() => count.value++;
///   return (count: count, increment: increment);
/// });
/// ```
class LevitStore<T> {
  final T Function(LevitRef ref) _builder;

  LevitStore(this._builder);

  late final String _defaultKey = 'ls_store_${_getStoreTag(this, null)}';

  /// Internal helper to resolve this store within a specific [scope].
  T findIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;

    var instance = scope.findOrNull<_LevitStoreInstance<T>>(tag: instanceKey);

    if (instance == null) {
      scope.put(() => _LevitStoreInstance<T>(this), tag: instanceKey);
      instance = scope.find<_LevitStoreInstance<T>>(tag: instanceKey);
    }

    return instance.value;
  }

  /// Internal helper to resolve this store asynchronously within a specific [scope].
  Future<T> findAsyncIn(LevitScope scope, {String? tag}) async {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;

    var instance =
        await scope.findOrNullAsync<_LevitStoreInstance<T>>(tag: instanceKey);

    if (instance == null) {
      scope.put(() => _LevitStoreInstance<T>(this), tag: instanceKey);
      instance =
          await scope.findAsync<_LevitStoreInstance<T>>(tag: instanceKey);
    }

    return instance.value;
  }

  /// Internal helper to delete this store from a specific [scope].
  bool deleteIn(LevitScope scope, {String? tag, bool force = false}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.delete<_LevitStoreInstance<T>>(tag: instanceKey, force: force);
  }

  /// Internal helper to check if this store is registered in a specific [scope].
  bool isRegisteredIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isRegistered<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Internal helper to check if this store is instantiated in a specific [scope].
  bool isInstantiatedIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isInstantiated<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Resolves the value of this store from the active [LevitScope].
  T find({String? tag}) => Levit.find<T>(key: this, tag: tag);

  /// Asynchronously resolves the value of this store.
  Future<T> findAsync({String? tag}) => Levit.findAsync<T>(key: this, tag: tag);

  /// Removes this store instance from the active [LevitScope].
  bool delete({String? tag, bool force = false}) =>
      Levit.delete(key: this, tag: tag, force: force);

  /// Creates an asynchronous [LevitStore] definition.
  static LevitAsyncStore<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncStore<T>(builder);
  }

  @override
  String toString() => 'LevitStore<$T>(id: $hashCode)';
}

/// A specialized [LevitStore] for asynchronous initialization.
class LevitAsyncStore<T> extends LevitStore<Future<T>> {
  LevitAsyncStore(super.builder);
}

/// The actual holder of a [LevitStore] instance within a [LevitScope].
class _LevitStoreInstance<T> extends LevitController implements LevitRef {
  final LevitStore<T> definition;

  T? _value;
  bool _builderRun = false;

  _LevitStoreInstance(this.definition);

  @override
  LevitScope get scope => super.scope!;

  T get value {
    if (!_builderRun) {
      // Use "Restored Zone Capture" for initialization.
      // This ensures that any `0.lx` created in the builder is captured
      // and disposed when the store closes, even if it's an orphan.
      _value = _AutoLinkScope.runCaptured(
        () => definition._builder(this),
        (captured, _) {
          for (final reactive in captured) {
            autoDispose(reactive);
          }
        },
        ownerId: ownerPath,
      );
      _builderRun = true;
    }
    return _value as T;
  }

  @override
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.findIn(scope, tag: tag) as S;
    }
    return scope.find<S>(tag: tag);
  }

  @override
  Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final result = await key.findAsyncIn(scope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    return await scope.findAsync<S>(tag: tag);
  }

  @override
  void onDispose(void Function() callback) {
    autoDispose(callback);
  }
}

/// Helper to tag stores.
String _getStoreTag(LevitStore provider, String? tag) {
  if (tag != null) return tag;
  return 'lxs_${provider.hashCode}';
}
