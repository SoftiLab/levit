import 'package:levit_dart/levit_dart.dart';

/// The base class for all diagnostic events in the Levit ecosystem.
///
/// [MonitorEvent] provides a common schema for both state changes and
/// dependency injection events, ensuring they can be serialized and
/// correlated across distributed systems or DevTools.
sealed class MonitorEvent {
  /// A monotonically increasing sequence number within the current session.
  final int seq;

  /// The precise timestamp when the event was captured.
  final DateTime timestamp;

  /// A unique identifier for the current application session.
  final String sessionId;

  /// Internal constructor for monitor events.
  MonitorEvent({
    required this.sessionId,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        seq = _nextSeq++;

  static int _nextSeq = 0;

  /// Converts the event metadata into a standard JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'seq': seq,
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
      };

  /// Safeguard for converting arbitrary objects to string representations.
  static dynamic _stringify(dynamic value) {
    if (value == null) return null;
    try {
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }
}

// ============================================================================
// Reactive Events
// ============================================================================

/// Base class for events related to the reactive state engine ([Lx]).
sealed class ReactiveEvent extends MonitorEvent {
  /// The reactive object that triggered the event.
  final LxReactive reactive;

  ReactiveEvent({required super.sessionId, required this.reactive});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'reactiveId': reactive.id.toString(),
        'name': reactive.name,
        'ownerId': reactive.ownerId,
      };
}

/// Event triggered when a new reactive variable is instantiated.
class ReactiveInitEvent extends ReactiveEvent {
  ReactiveInitEvent({required super.sessionId, required super.reactive});
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'reactive_init',
        'valueType': reactive.value?.runtimeType.toString() ?? 'dynamic',
        'initialValue': MonitorEvent._stringify(reactive.value),
      };
}

/// Event triggered when a reactive object's lifecycle ends.
class ReactiveDisposeEvent extends ReactiveEvent {
  ReactiveDisposeEvent({required super.sessionId, required super.reactive});
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'reactive_dispose',
      };
}

/// Event triggered by a single state mutation.
class ReactiveChangeEvent extends ReactiveEvent {
  /// The change record intercepted from the middleware.
  final LevitReactiveChange change;

  ReactiveChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.change,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'state_change',
        'oldValue': MonitorEvent._stringify(change.oldValue),
        'newValue': MonitorEvent._stringify(change.newValue),
        'valueType': change.valueType.toString(),
        'isBatch': false,
      };
}

/// Event triggered at the completion of a reactive batch.
class ReactiveBatchEvent extends MonitorEvent {
  /// The batch record containing all mutations occurred within the scope.
  final LevitReactiveBatch change;

  ReactiveBatchEvent({required super.sessionId, required this.change});

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'batch',
        'batchId': change.batchId,
        'count': change.length,
        'entries': change.entries
            .map((e) => {
                  'reactiveId': e.$1.id.toString(),
                  'name': e.$1.name,
                  'oldValue': MonitorEvent._stringify(e.$2.oldValue),
                  'newValue': MonitorEvent._stringify(e.$2.newValue),
                  'valueType': e.$2.valueType.toString(),
                })
            .toList(),
      };
}

/// Event triggered when a computed value's dependency graph is updated.
class ReactiveGraphChangeEvent extends ReactiveEvent {
  /// The current set of dependencies for the reactive object.
  final List<LxReactive> dependencies;

  ReactiveGraphChangeEvent({
    required super.sessionId,
    required super.reactive,
    required this.dependencies,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'graph_change',
        'dependencies': dependencies
            .map((d) => {
                  'id': d.id.toString(),
                  'name': d.name,
                })
            .toList(),
      };
}

// ============================================================================
// Dependency Injection Events
// ============================================================================

/// Base class for events related to the dependency injection system ([Levit]).
sealed class DependencyEvent extends MonitorEvent {
  /// The unique identifier of the scope where the event occurred.
  final int scopeId;

  /// The descriptive name of the scope.
  final String scopeName;

  /// The registration key of the dependency.
  final String key;

  /// Metadata about the dependency at the time of the event.
  final LevitDependency info;

  DependencyEvent({
    required super.sessionId,
    required this.scopeId,
    required this.scopeName,
    required this.key,
    required this.info,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'scopeId': scopeId,
        'scopeName': scopeName,
        'key': key,
        'isLazy': info.isLazy,
        'isFactory': info.isFactory,
        'isAsync': info.isAsync,
        'permanent': info.permanent,
        'isInstantiated': info.isInstantiated,
      };
}

/// Event triggered when a dependency is registered with a scope.
class DependencyRegisterEvent extends DependencyEvent {
  final String source;
  DependencyRegisterEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_register',
        'source': source,
      };
}

/// Event triggered when a dependency is successfully resolved.
class DependencyResolveEvent extends DependencyEvent {
  final String source;
  DependencyResolveEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_resolve',
        'source': source,
        'instance': MonitorEvent._stringify(info.instance),
      };
}

/// Event triggered when a dependency is removed from a scope.
class DependencyDeleteEvent extends DependencyEvent {
  final String source;
  DependencyDeleteEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.source,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_delete',
        'source': source,
      };
}

/// Event triggered when a dependency instance creation begins.
class DependencyInstanceCreateEvent extends DependencyEvent {
  DependencyInstanceCreateEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_instance_create',
      };
}

/// Event triggered when a dependency instance is fully initialized and ready.
class DependencyInstanceReadyEvent extends DependencyEvent {
  /// The resulting instance.
  final dynamic instance;

  DependencyInstanceReadyEvent({
    required super.sessionId,
    required super.scopeId,
    required super.scopeName,
    required super.key,
    required super.info,
    required this.instance,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'type': 'di_instance_init',
        'instance': MonitorEvent._stringify(instance),
      };
}
