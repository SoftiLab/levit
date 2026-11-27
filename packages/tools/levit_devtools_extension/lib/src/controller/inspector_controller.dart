import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../client/devtools_client.dart';

/// Filter pills available in the Reactives tab.
enum ReactiveFilterMode { all, sensitive, unowned, computed, highListeners }

/// Flattened scope hierarchy entry rendered by `ScopeTreeView`.
final class ScopeTreeNode {
  /// Scope model from the current redacted runtime snapshot.
  final LevitScopeModel scope;

  /// Nesting depth in the active scope hierarchy (`0` for root scopes).
  final int depth;

  /// Creates a flattened scope tree node.
  const ScopeTreeNode(this.scope, this.depth);
}

/// Owns the client-side [LevitStateSnapshot], live stream buffering, filters,
/// navigation state, and deterministic anomaly diagnostics for the DevTools UI.
class LevitInspectorController extends LevitController {
  /// Maximum history events retained in the DevTools UI buffer.
  static const int maxTimelineEvents = 500;

  /// Maximum error summaries retained in the DevTools UI buffer.
  static const int maxRecentErrors = 50;

  final LevitDevToolsClient _client;
  final bool _ownsClient;

  LevitStateSnapshot _snapshot = LevitStateSnapshot(
    maxEvents: maxTimelineEvents,
    maxVariables: 4096,
  );
  final ListQueue<Map<String, dynamic>> _recentErrors = ListQueue();
  final ListQueue<LevitEventEnvelope> _pausedBuffer = ListQueue();

  /// Whether the target isolate has `LevitDevTools` / `LevitMonitor` attached.
  final attached = false.lx.named('attached');

  /// Whether a snapshot refresh is currently in progress.
  final loading = false.lx.named('loading');

  /// Whether live event ingestion is currently paused.
  final paused = false.lx.named('paused');

  /// Number of events queued while paused.
  final pausedCount = 0.lx.named('pausedCount');

  /// Last connection or refresh error, if any.
  final errorMessage = LxVar<String?>(null).named('errorMessage');

  /// Monotonic counter incremented whenever snapshot data changes.
  final revision = 0.lx.named('revision');

  /// Total dropped events reported by the target isolate.
  final droppedEvents = 0.lx.named('droppedEvents');

  /// Active tab index (`0=Scopes`, `1=Reactives`, `2=Tasks`, `3=Timeline`, `4=Diagnostics`).
  final activeTabIndex = 0.lx.named('activeTabIndex');

  /// Currently selected scope ID in the Scopes tab.
  final selectedScopeId = LxVar<int?>(null).named('selectedScopeId');

  /// Currently selected reactive ID in the Reactives tab.
  final selectedReactiveId = LxVar<int?>(null).named('selectedReactiveId');

  /// Currently selected timeline event sequence number.
  final selectedEventSeq = LxVar<int?>(null).named('selectedEventSeq');

  /// Search query for the Reactives tab.
  final reactiveSearch = ''.lx.named('reactiveSearch');

  /// Quick filter mode for the Reactives tab.
  final reactiveFilter =
      LxVar<ReactiveFilterMode>(ReactiveFilterMode.all).named('reactiveFilter');

  /// Search query for the Timeline tab.
  final timelineSearch = ''.lx.named('timelineSearch');

  /// Optional category filter (`state`, `di`, `log`, `custom`, `error`) for Timeline.
  final timelineCategory = LxVar<String?>(null).named('timelineCategory');

  /// Configurable high-listener warning threshold for Diagnostics.
  final highListenerThreshold = LevitSnapshotDiagnostics
      .defaultHighListenerThreshold.lx
      .named('highListenerThreshold');

  /// Owned text controller for the Reactives search input.
  late final TextEditingController reactiveSearchController = own(
    TextEditingController(),
    dispose: (controller) => controller.dispose(),
  );

  /// Owned text controller for the Timeline search input.
  late final TextEditingController timelineSearchController = own(
    TextEditingController(),
    dispose: (controller) => controller.dispose(),
  );

  late final _findings = computed(() {
    revision();
    return LevitSnapshotDiagnostics.analyze(
      _snapshot,
      recentErrors: recentErrors,
      highListenerThreshold: highListenerThreshold(),
    );
  }, name: 'findings');

  late final _flattenedScopes = computed(() {
    revision();
    return _buildScopeTree(_snapshot.scopes);
  }, name: 'flattenedScopes');

  late final _filteredReactives = computed(() {
    revision();
    final query = reactiveSearch().trim().toLowerCase();
    final filter = reactiveFilter();
    final threshold = highListenerThreshold();

    final list = _snapshot.variables.values.where((v) {
      switch (filter) {
        case ReactiveFilterMode.all:
          break;
        case ReactiveFilterMode.sensitive:
          if (!v.isSensitive) return false;
        case ReactiveFilterMode.unowned:
          if (v.ownerId != null && v.ownerId!.isNotEmpty && v.ownerId != '?') {
            return false;
          }
        case ReactiveFilterMode.computed:
          if (v.dependencies.isEmpty) return false;
        case ReactiveFilterMode.highListeners:
          if (v.listenerCount < threshold) return false;
      }
      if (query.isEmpty) return true;
      return v.name.toLowerCase().contains(query) ||
          (v.ownerId?.toLowerCase().contains(query) ?? false) ||
          (v.valueType?.toLowerCase().contains(query) ?? false) ||
          '${v.id}'.contains(query);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }, name: 'filteredReactives');

  late final _filteredTimeline = computed(() {
    revision();
    final query = timelineSearch().trim().toLowerCase();
    final category = timelineCategory();
    final matched = <LevitEventEnvelope>[];
    for (final envelope in _snapshot.events.reversed) {
      if (category != null && envelope.category != category) continue;
      if (query.isNotEmpty) {
        final data = envelope.data;
        final haystack =
            '${envelope.type} ${envelope.category} ${data['name'] ?? ''} '
                    '${data['key'] ?? ''} ${data['ownerId'] ?? ''} '
                    '${data['scopeName'] ?? ''} ${data['error'] ?? ''}'
                .toLowerCase();
        if (!haystack.contains(query)) continue;
      }
      matched.add(envelope);
    }
    return matched;
  }, name: 'filteredTimeline');

  late final _sortedTaskTrees = computed(() {
    revision();
    return _snapshot.taskTrees.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }, name: 'sortedTaskTrees');

  /// Creates an inspector controller backed by [_client].
  LevitInspectorController(this._client, {bool ownsClient = true})
      : _ownsClient = ownsClient;

  /// Current redacted shadow state reconstructed from snapshot + live events.
  LevitStateSnapshot get snapshot => _snapshot;

  /// Unmodifiable view of recent error summaries.
  List<Map<String, dynamic>> get recentErrors =>
      List.unmodifiable(_recentErrors);

  /// Live deterministic diagnostic findings computed from [snapshot].
  List<LevitDiagnosticFinding> get findings => _findings();

  /// Whether any active diagnostic finding has error severity.
  bool get hasErrorFindings =>
      findings.any((f) => f.severity == LevitDiagnosticSeverity.error);

  /// Flattened scope tree in deterministic depth-first order.
  List<ScopeTreeNode> get flattenedScopes => _flattenedScopes();

  /// Filtered reactive variables matching [reactiveSearch] and [reactiveFilter].
  List<LevitReactiveModel> get filteredReactives => _filteredReactives();

  /// Filtered timeline events in reverse-chronological order (newest first).
  List<LevitEventEnvelope> get filteredTimeline => _filteredTimeline();

  /// Active task tree entries sorted by owner path.
  List<MapEntry<String, Map<String, dynamic>>> get sortedTaskTrees =>
      _sortedTaskTrees();

  @override
  void onInit() {
    super.onInit();
    own(_client.events.listen(_handleIncomingEvent));
    own(
      _client.connectionChanges.listen((connected) {
        if (connected) {
          unawaited(refresh());
        } else {
          attached.value = false;
        }
      }),
    );
    unawaited(refresh());
  }

  /// Hydrates the client snapshot and history from the connected target isolate.
  Future<void> refresh() async {
    if (isClosed) return;
    loading.value = true;
    errorMessage.value = null;
    try {
      final result = await _client.fetchSnapshot();
      if (isClosed) return;

      attached.value = result.attached;
      droppedEvents.value = result.droppedEvents;

      final nextSnapshot = LevitStateSnapshot(
        maxEvents: maxTimelineEvents,
        maxVariables: 4096,
      );
      if (result.attached && result.snapshot != null) {
        nextSnapshot.applyEnvelope(
          LevitEventEnvelope({
            'sessionId': 'devtools',
            'seq': 0,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'type': 'snapshot',
            'category': 'system',
            'state': result.snapshot,
          }),
        );
        final history = await _client.fetchHistory(limit: maxTimelineEvents);
        if (isClosed) return;
        for (final envelope in history) {
          nextSnapshot.applyEnvelope(envelope);
        }
      }

      _snapshot = nextSnapshot;
      _recentErrors
        ..clear()
        ..addAll(result.recentErrors.take(maxRecentErrors));
      _pausedBuffer.clear();
      pausedCount.value = 0;

      if (selectedScopeId.value == null && _snapshot.scopes.isNotEmpty) {
        selectedScopeId.value = _snapshot.scopes.keys.first;
      } else if (selectedScopeId.value != null &&
          !_snapshot.scopes.containsKey(selectedScopeId.value)) {
        selectedScopeId.value =
            _snapshot.scopes.isEmpty ? null : _snapshot.scopes.keys.first;
      }

      revision.value++;
    } catch (error) {
      if (!isClosed) {
        errorMessage.value = '$error';
      }
    } finally {
      if (!isClosed) {
        loading.value = false;
      }
    }
  }

  void _handleIncomingEvent(LevitEventEnvelope envelope) {
    if (isClosed) return;
    if (!attached.value) {
      attached.value = true;
    }
    if (paused.value) {
      if (_pausedBuffer.length == maxTimelineEvents) {
        _pausedBuffer.removeFirst();
      }
      _pausedBuffer.add(envelope);
      pausedCount.value = _pausedBuffer.length;
      return;
    }
    _applyEnvelope(envelope);
    revision.value++;
  }

  void _applyEnvelope(LevitEventEnvelope envelope) {
    _snapshot.applyEnvelope(envelope);
    final errorSummary = LevitSnapshotDiagnostics.extractErrorSummary(envelope);
    if (errorSummary != null) {
      if (_recentErrors.length == maxRecentErrors) {
        _recentErrors.removeFirst();
      }
      _recentErrors.add(errorSummary);
    }
  }

  /// Toggles live event streaming; resuming flushes buffered events in order.
  void togglePause() {
    if (paused.value) {
      paused.value = false;
      if (_pausedBuffer.isNotEmpty) {
        for (final envelope in _pausedBuffer) {
          _applyEnvelope(envelope);
        }
        _pausedBuffer.clear();
        pausedCount.value = 0;
        revision.value++;
      }
    } else {
      paused.value = true;
    }
  }

  /// Clears locally retained timeline history without modifying the target app.
  void clearLocalTimeline() {
    final raw = _snapshot.toJson();
    final next = LevitStateSnapshot(
      maxEvents: maxTimelineEvents,
      maxVariables: 4096,
    );
    next.applyEnvelope(
      LevitEventEnvelope({
        'sessionId': 'devtools',
        'seq': 0,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'type': 'snapshot',
        'category': 'system',
        'state': raw,
      }),
    );
    _snapshot = next;
    selectedEventSeq.value = null;
    revision.value++;
  }

  /// Jumps to a specific scope in the Scopes tab.
  void focusScope(int scopeId) {
    Levit.batch(() {
      selectedScopeId.value = scopeId;
      activeTabIndex.value = 0;
    });
  }

  /// Jumps to a specific reactive in the Reactives tab.
  void focusReactive(int reactiveId) {
    Levit.batch(() {
      selectedReactiveId.value = reactiveId;
      activeTabIndex.value = 1;
    });
  }

  /// Filters Reactives to unowned variables and switches to the Reactives tab.
  void showUnownedReactives() {
    Levit.batch(() {
      reactiveFilter.value = ReactiveFilterMode.unowned;
      activeTabIndex.value = 1;
    });
  }

  /// Filters Reactives to high-listener variables and switches to Reactives.
  void showHighListenerReactives() {
    Levit.batch(() {
      reactiveFilter.value = ReactiveFilterMode.highListeners;
      activeTabIndex.value = 1;
    });
  }

  /// Returns the number of tracked DI dependencies in [scopeId].
  int dependencyCountForScope(int scopeId) {
    return _snapshot.dependencies.values
        .where((d) => d.scopeId == scopeId)
        .length;
  }

  /// Returns sorted DI dependency registrations owned by [scopeId].
  List<LevitDependencyModel> dependenciesForScope(int scopeId) {
    return _snapshot.dependencies.values
        .where((d) => d.scopeId == scopeId)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Returns sorted reactive variables linked to [scopeId].
  List<LevitReactiveModel> ownedReactivesForScope(int scopeId) {
    return _snapshot.variables.values
        .where((v) => v.scopeId == scopeId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Returns resolved upstream reactive models for [reactive].
  List<LevitReactiveModel> upstreamDependenciesOf(LevitReactiveModel reactive) {
    return reactive.dependencies
        .map((id) => _snapshot.variables[id])
        .whereType<LevitReactiveModel>()
        .toList();
  }

  /// Returns downstream reactive models that list [reactiveId] in their
  /// upstream `dependencies`.
  List<LevitReactiveModel> downstreamDependentsOf(int reactiveId) {
    return _snapshot.variables.values
        .where((v) => v.dependencies.contains(reactiveId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Builds a concise single-line summary for a timeline [envelope].
  String summarizeEvent(LevitEventEnvelope envelope) {
    final data = envelope.data;
    if (envelope.type == 'state_change') {
      final name = data['name'] ?? data['reactiveId'];
      return '$name: ${data['oldValue']} → ${data['newValue']}';
    }
    if (data['scopeName'] != null) {
      return 'scope: ${data['scopeName']}'
          '${data['key'] != null ? ' • ${data['key']}' : ''}';
    }
    if (data['error'] != null) return 'error: ${data['error']}';
    if (data['name'] != null) return '${data['name']}';
    return data['timestamp']?.toString() ?? '';
  }

  /// Exports a pretty-printed, redacted JSON snapshot for sharing/bug reports.
  String exportRedactedJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'snapshot': _snapshot.toJson(),
      'recentErrors': recentErrors,
      'findings': findings.map((f) => f.toJson()).toList(),
      'droppedEvents': droppedEvents.value,
    });
  }

  List<ScopeTreeNode> _buildScopeTree(Map<int, LevitScopeModel> scopes) {
    final childrenByParent = <int?, List<LevitScopeModel>>{};
    for (final scope in scopes.values) {
      final parentId =
          scope.parentScopeId != null && scopes.containsKey(scope.parentScopeId)
              ? scope.parentScopeId
              : null;
      childrenByParent.putIfAbsent(parentId, () => []).add(scope);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final result = <ScopeTreeNode>[];
    final visited = <int>{};
    void visit(LevitScopeModel scope, int depth) {
      if (!visited.add(scope.id)) return;
      result.add(ScopeTreeNode(scope, depth));
      for (final child in childrenByParent[scope.id] ?? const []) {
        visit(child, depth + 1);
      }
    }

    for (final root in childrenByParent[null] ?? const []) {
      visit(root, 0);
    }
    return result;
  }

  @override
  Future<void> onClose() async {
    if (_ownsClient) {
      await _client.dispose();
    }
    await super.onClose();
  }
}
