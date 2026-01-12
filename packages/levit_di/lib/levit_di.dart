/// Pure Dart dependency injection and service locator.
///
/// This library provides the core dependency injection mechanism used by Levit.
/// It supports:
///
/// *   Singleton and factory registrations.
/// *   Lazy and async initialization.
/// *   Hierarchical scoping ([LevitScope]).
/// *   Lifecycle management via [LevitDisposable].
library levit_di;

import 'dart:async';

// ============================================================================
// Lifecycle Interface
// ============================================================================

/// Interface for objects that require lifecycle management.
///
/// Implement this interface in your controllers or services to receive callbacks
/// when the object is initialized ([onInit]) or disposed ([onClose]).
abstract class LevitDisposable {
  /// Base constructor.
  const LevitDisposable();

  /// Called immediately after the instance is registered via [Levit.put] or
  /// instantiated via [Levit.lazyPut] or [Levit.find].
  ///
  /// Use this method for setup logic, such as initializing variables or
  /// starting listeners.
  void onInit() {}

  /// Called when the instance is removed from the container via [Levit.delete]
  /// or during a [Levit.reset] call.
  ///
  /// Use this method for cleanup logic, such as closing streams or disposing
  /// of other resources.
  void onClose() {}
}

// ============================================================================
// Instance Info
// ============================================================================

/// Holds metadata about a registered dependency instance.
///
/// This class tracks the lifecycle state, creation strategy (factory, lazy, etc.),
/// and the instance itself.
///
/// It exists to support the internal mechanisms of [LevitScope] and is typically
/// not used directly by application code.
class InstanceInfo<S> {
  /// The actual instance, or `null` if it is a lazy registration that has not
  /// yet been instantiated.
  S? instance;

  /// The builder function for lazy instantiation.
  final S Function()? builder;

  /// The async builder function for lazy asynchronous instantiation.
  final Future<S> Function()? asyncBuilder;

  /// Whether the instance should persist even when a reset is requested (unless forced).
  final bool permanent;

  /// Whether this registration was made via `lazyPut`.
  final bool isLazy;

  /// Whether this registration is a factory (creates a new instance every time).
  final bool isFactory;

  /// Returns `true` if the lazy instance has been created.
  bool get isInstantiated => instance != null;

  /// Returns `true` if this registration uses an asynchronous builder.
  bool get isAsync => asyncBuilder != null;

  /// Creates a new [InstanceInfo] with the specified configuration.
  InstanceInfo({
    this.instance,
    this.builder,
    this.asyncBuilder,
    this.permanent = false,
    this.isLazy = false,
    this.isFactory = false,
  });
}

// ============================================================================
// LevitScope - Scoped Container
// ============================================================================

/// A scoped dependency injection container.
///
/// [LevitScope] manages a registry of dependencies. Scopes can be nested;
/// child scopes can override parent dependencies locally and automatically
/// clean up their own resources when disposed. Dependency lookups fall back
/// to the parent scope if the key is not found locally.
///
/// Use this class to create isolated environments for tests or modular parts
/// of your application (e.g., authenticated vs. guest scope).
class LevitScope {
  /// The name of this scope, used for debugging purposes.
  final String name;

  /// The parent scope, or `null` if this is the root scope.
  final LevitScope? _parentScope;

  /// The local registry of dependencies for this scope.
  final Map<String, InstanceInfo> _registry = {};

  /// A cache for resolved keys to speed up lookups in parent scopes.
  final Map<String, LevitScope> _resolutionCache = {};

  /// Creates a new [LevitScope].
  ///
  /// This constructor is internal; use [Levit.createScope] or [LevitScope.createScope] instead.
  LevitScope.internal(this.name, {LevitScope? parentScope})
      : _parentScope = parentScope;

  // --------------------------------------------------------------------------
  // Registration
  // --------------------------------------------------------------------------

  /// Registers a dependency instance in this scope.
  ///
  /// If an instance with the same type and [tag] already exists, it is replaced.
  /// If the existing instance implements [LevitDisposable], its [LevitDisposable.onClose] method is called.
  ///
  /// If [dependency] implements [LevitDisposable], its [LevitDisposable.onInit] method is called immediately.
  ///
  /// *   [dependency]: The instance to register.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  S put<S>(S dependency, {String? tag, bool permanent = false}) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key)) {
      delete<S>(tag: tag, force: true);
    }

    _registry[key] = InstanceInfo<S>(
      instance: dependency,
      permanent: permanent,
    );

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }

    if (dependency is LevitDisposable) {
      dependency.onInit();
    }

    return dependency;
  }

  /// Registers a lazy builder in this scope.
  ///
  /// The [builder] is executed only when the dependency is first requested via [find].
  ///
  /// *   [builder]: The function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  void lazyPut<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key) && _registry[key]!.isInstantiated) {
      return;
    }

    _registry[key] = InstanceInfo<S>(
      builder: builder,
      permanent: permanent,
      isLazy: true,
    );

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
  }

  /// Registers a factory that creates a new instance each time it is requested.
  ///
  /// *   [builder]: The function that creates the new instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  void putFactory<S>(S Function() builder, {String? tag}) {
    final key = _getKey<S>(tag);

    _registry[key] = InstanceInfo<S>(
      builder: builder,
      permanent: true,
      isLazy: true,
      isFactory: true,
    );

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
  }

  /// Registers an instance created by an asynchronous builder.
  ///
  /// The [builder] is executed immediately, and the result is awaited before registration.
  ///
  /// *   [builder]: The async function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  Future<S> putAsync<S>(
    Future<S> Function() builder, {
    String? tag,
    bool permanent = false,
  }) async {
    final instance = await builder();
    return put<S>(instance, tag: tag, permanent: permanent);
  }

  /// Registers an asynchronous lazy builder in this scope.
  ///
  /// The [builder] is executed only when the dependency is first requested via [findAsync].
  ///
  /// *   [builder]: The async function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  void lazyPutAsync<S>(
    Future<S> Function() builder, {
    String? tag,
    bool permanent = false,
  }) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key) && _registry[key]!.isInstantiated) {
      return;
    }

    _registry[key] = InstanceInfo<S>(
      asyncBuilder: builder,
      permanent: permanent,
      isLazy: true,
    );
    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
  }

  /// Registers an asynchronous factory that creates a NEW instance each time it is requested.
  ///
  /// *   [builder]: The async function that creates the new instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  void putFactoryAsync<S>(Future<S> Function() builder, {String? tag}) {
    final key = _getKey<S>(tag);

    _registry[key] = InstanceInfo<S>(
      asyncBuilder: builder,
      permanent: true,
      isLazy: true,
      isFactory: true,
    );
    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
  }

  // --------------------------------------------------------------------------
  // Retrieval
  // --------------------------------------------------------------------------

  /// Finds and returns the registered instance of type [S].
  ///
  /// If the instance is not found in the current scope, the parent scope is checked.
  ///
  /// Throws an [Exception] if the dependency is not registered.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  S find<S>({String? tag}) {
    final instance = findOrNull<S>(tag: tag);
    if (instance != null) return instance;

    if (isRegistered<S>(tag: tag)) {
      return instance as S;
    }

    throw Exception(
      'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is not registered.\n'
      'Not found in scope or any parent.',
    );
  }

  /// Finds and returns the registered instance of type [S], or `null` if not found.
  ///
  /// If the instance is not found in the current scope, the parent scope is checked.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  S? findOrNull<S>({String? tag}) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key)) {
      return _findLocal<S>(tag: tag);
    }

    final cached = _resolutionCache[key];
    if (cached != null) {
      return cached.findOrNull<S>(tag: tag);
    }

    if (_parentScope != null) {
      final instance = _parentScope!.findOrNull<S>(tag: tag);
      if (instance != null) {
        final parentSource = _parentScope!._resolutionCache[key];
        if (parentSource != null) {
          _resolutionCache[key] = parentSource;
        } else {
          _resolutionCache[key] = _parentScope!;
        }
        return instance;
      }
    }

    return null;
  }

  /// Asynchronously finds and returns a registered instance of type [S].
  ///
  /// Use this for dependencies registered via [lazyPutAsync] or [createAsync].
  ///
  /// Throws an [Exception] if the dependency is not registered.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  Future<S> findAsync<S>({String? tag}) async {
    final instance = await findOrNullAsync<S>(tag: tag);
    if (instance != null) return instance;

    if (isRegistered<S>(tag: tag)) {
      return instance as S;
    }

    throw Exception(
      'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is not registered.\n'
      'Not found in scope or any parent.',
    );
  }

  /// Asynchronously finds an instance of type [S], returning `null` if not found.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  Future<S?> findOrNullAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key)) {
      return _findLocalAsync<S>(tag: tag);
    }

    final cached = _resolutionCache[key];
    if (cached != null) {
      return cached.findOrNullAsync<S>(tag: tag);
    }

    if (_parentScope != null) {
      final instance = await _parentScope!.findOrNullAsync<S>(tag: tag);
      if (instance != null) {
        final parentSource = _parentScope!._resolutionCache[key];
        if (parentSource != null) {
          _resolutionCache[key] = parentSource;
        } else {
          _resolutionCache[key] = _parentScope!;
        }
        return instance;
      }
    }

    return null;
  }

  // Cache for in-flight async initializations to prevent race conditions
  final Map<String, Future<dynamic>> _pendingInit = {};

  Future<S> _findLocalAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);
    final info = _registry[key] as InstanceInfo<S>;

    if (info.isInstantiated) {
      return info.instance as S;
    }

    if (info.isFactory && info.isAsync) {
      final instance = await info.asyncBuilder!();
      if (instance is LevitDisposable) {
        instance.onInit();
      }
      return instance;
    }

    if (info.isFactory && info.builder != null) {
      final instance = info.builder!();
      if (instance is LevitDisposable) {
        instance.onInit();
      }
      return instance;
    }

    if (info.isLazy && info.isAsync) {
      if (_pendingInit.containsKey(key)) {
        return await _pendingInit[key] as S;
      }

      final future = (() async {
        try {
          final instance = await info.asyncBuilder!();
          info.instance = instance;
          if (instance is LevitDisposable) {
            instance.onInit();
          }
          return instance;
        } finally {
          _pendingInit.remove(key);
        }
      })();

      _pendingInit[key] = future;
      return future;
    }

    return _findLocal<S>(tag: tag);
  }

  S _findLocal<S>({String? tag}) {
    final key = _getKey<S>(tag);
    final info = _registry[key] as InstanceInfo<S>;

    if (info.isFactory && info.builder != null) {
      final instance = info.builder!();
      if (instance is LevitDisposable) {
        instance.onInit();
      }
      return instance;
    }

    if (info.isLazy && !info.isInstantiated) {
      info.instance = info.builder!();
      if (info.instance is LevitDisposable) {
        (info.instance as LevitDisposable).onInit();
      }
    }

    return info.instance as S;
  }

  /// Returns `true` if type [S] is registered in this specific scope.
  bool isRegisteredLocally<S>({String? tag}) {
    return _registry.containsKey(_getKey<S>(tag));
  }

  /// Returns `true` if type [S] is registered in this scope or any parent scope.
  bool isRegistered<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) return true;
    if (_parentScope != null) return _parentScope!.isRegistered<S>(tag: tag);
    return false;
  }

  /// Returns `true` if type [S] is registered and has been instantiated.
  bool isInstantiated<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) {
      final key = _getKey<S>(tag);
      return _registry[key]!.isInstantiated;
    }
    if (_parentScope != null) return _parentScope!.isInstantiated<S>(tag: tag);
    return false;
  }

  // --------------------------------------------------------------------------
  // Deletion
  // --------------------------------------------------------------------------

  /// Deletes an instance of type [S] from this scope.
  ///
  /// Returns `true` if the instance was successfully deleted.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  /// *   [force]: If `true`, deletes the instance even if it was registered as `permanent`.
  bool delete<S>({String? tag, bool force = false}) {
    final key = _getKey<S>(tag);

    if (!_registry.containsKey(key)) return false;

    final info = _registry[key]!;

    if (info.permanent && !force) return false;

    if (info.isInstantiated && info.instance is LevitDisposable) {
      (info.instance as LevitDisposable).onClose();
    }

    _registry.remove(key);
    _pendingInit.remove(key); // Also clear any pending init
    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
    return true;
  }

  /// Clears all instances in this scope only (does not affect parent scopes).
  ///
  /// *   [force]: If `true`, deletes all instances even if they were registered as `permanent`.
  void reset({bool force = false}) {
    final keysToRemove = <String>[];

    for (final entry in _registry.entries) {
      final info = entry.value;

      if (info.permanent && !force) continue;

      if (info.isInstantiated && info.instance is LevitDisposable) {
        (info.instance as LevitDisposable).onClose();
      }

      keysToRemove.add(entry.key);
    }

    for (final key in keysToRemove) {
      _registry.remove(key);
      _pendingInit.remove(key);
      if (_resolutionCache.isNotEmpty) {
        _resolutionCache.remove(key);
      }
    }
  }

  // --------------------------------------------------------------------------
  // Nested Scopes
  // --------------------------------------------------------------------------

  /// Creates a new child scope that falls back to this scope for dependency resolution.
  ///
  /// *   [name]: The name of the new scope.
  LevitScope createScope(String name) {
    return LevitScope.internal(name, parentScope: this);
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  static final Map<Type, String> _typeCache = {};

  String _getKey<S>(String? tag) {
    final typeString = _typeCache[S] ??= S.toString();
    return tag != null ? '${typeString}_$tag' : typeString;
  }

  /// The number of dependencies registered locally in this scope.
  int get registeredCount => _registry.length;

  /// A list of keys for all locally registered dependencies (for debugging).
  List<String> get registeredKeys => _registry.keys.toList();

  @override
  String toString() =>
      'LevitScope($name, ${_registry.length} local registrations)';

  // --------------------------------------------------------------------------
  // Implicit Scoping
  // --------------------------------------------------------------------------

  /// Internal zone key used for implicit scope propagation.
  static final Object zoneScopeKey = Object();

  /// Executes [callback] within a [Zone] where this scope is implicitly active.
  ///
  /// Any calls to [Levit.find] or [Levit.put] within the callback will target this scope.
  R run<R>(R Function() callback) {
    return runZoned(
      callback,
      zoneValues: {zoneScopeKey: this},
    );
  }
}

// ============================================================================
// Levit - Static Accessor
// ============================================================================

/// Global static accessor for the dependency injection system.
///
/// Use [Levit] to access methods like [put], [find], and [createScope].
/// It automatically resolves the current scope (if inside [LevitScope.run]) or uses the root scope.
class Levit {
  Levit._(); // coverage:ignore-line

  static final LevitScope _root = LevitScope.internal('root');

  static LevitScope get _currentScope {
    final implicit = Zone.current[LevitScope.zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Registers a dependency.
  static S put<S>(S dependency, {String? tag, bool permanent = false}) {
    return _currentScope.put<S>(dependency, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false}) {
    _currentScope.lazyPut<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a factory (created each time).
  static void putFactory<S>(S Function() builder, {String? tag}) {
    _currentScope.putFactory<S>(builder, tag: tag);
  }

  /// Registers an async dependency.
  static Future<S> putAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false}) {
    return _currentScope.putAsync<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy async dependency.
  static void lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false}) {
    _currentScope.lazyPutAsync<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers an async factory.
  static void putFactoryAsync<S>(Future<S> Function() builder, {String? tag}) {
    _currentScope.putFactoryAsync<S>(builder, tag: tag);
  }

  /// Finds a registered dependency.
  static S find<S>({String? tag}) {
    return _currentScope.find<S>(tag: tag);
  }

  /// Finds a registered dependency or returns null.
  static S? findOrNull<S>({String? tag}) {
    return _currentScope.findOrNull<S>(tag: tag);
  }

  /// Finds an async dependency.
  static Future<S> findAsync<S>({String? tag}) {
    return _currentScope.findAsync<S>(tag: tag);
  }

  /// Finds an async dependency or returns null.
  static Future<S?> findOrNullAsync<S>({String? tag}) {
    return _currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Checks if a type is registered.
  static bool isRegistered<S>({String? tag}) {
    return _currentScope.isRegistered<S>(tag: tag);
  }

  /// Checks if a type is instantiated.
  static bool isInstantiated<S>({String? tag}) {
    return _currentScope.isInstantiated<S>(tag: tag);
  }

  /// Deletes a registered dependency.
  static bool delete<S>({String? tag, bool force = false}) {
    return _currentScope.delete<S>(tag: tag, force: force);
  }

  /// Resets the current scope.
  static void reset({bool force = false}) {
    _currentScope.reset(force: force);
  }

  /// Creates a new scope.
  static LevitScope createScope(String name) {
    return _currentScope.createScope(name);
  }

  /// The number of dependencies registered in the current scope.
  static int get registeredCount => _currentScope.registeredCount;

  /// A list of keys for all registered dependencies in the current scope.
  static List<String> get registeredKeys => _currentScope.registeredKeys;
}
