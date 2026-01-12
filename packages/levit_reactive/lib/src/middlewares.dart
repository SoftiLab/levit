import 'core.dart';

/// A middleware that logs state changes to the console.
///
/// Use this middleware to debug state changes during development.
///
/// ## Usage
/// ```dart
/// Lx.middlewares.add(LxLoggerMiddleware());
/// ```
class LxLoggerMiddleware extends LxMiddleware {
  /// Whether to include stack traces in the log output.
  final bool includeStackTrace;

  /// Optional custom log formatter.
  final String Function(StateChange change)? formatter;

  /// Creates a logger middleware.
  ///
  /// [filter] can be used to filter logs by variable name.
  LxLoggerMiddleware({
    this.includeStackTrace = false,
    bool Function(String? name)? filter,
    this.formatter,
  }) {
    if (filter != null) {
      this.filter = (change) => filter(change.name);
    }
  }

  @override
  bool onBeforeChange<T>(StateChange<T> change) => true;

  @override
  void onAfterChange<T>(StateChange<T> change) {
    if (formatter != null) {
      print(formatter!(change));
    } else {
      print('[Lx] ${change.toString()}');
    }

    if (includeStackTrace && change.stackTrace != null) {
      print(change.stackTrace);
    }
  }

  @override
  void onBatchStart() {
    print('[Lx] Batch started');
  }

  @override
  void onBatchEnd() {
    print('[Lx] Batch ended');
  }
}

/// A middleware that records state history for undo/redo functionality.
///
/// This middleware tracks all state changes and provides methods to traverse
/// the history.
///
/// ## Usage
/// ```dart
/// final history = LxHistoryMiddleware();
/// Lx.middlewares.add(history);
///
/// // Later...
/// history.undo();
/// ```
class LxHistoryMiddleware extends LxMiddleware {
  final List<StateChange> _undoStack = [];
  final List<StateChange> _redoStack = [];

  final _version = Lx(0);

  List<StateChange>? _currentBatch;
  bool _isRestoring = false;

  /// Returns an unmodifiable list of all recorded changes.
  List<StateChange> get changes {
    _version.value;
    return List.unmodifiable(_undoStack);
  }

  /// The number of recorded changes in the undo stack.
  int get length {
    _version.value;
    return _undoStack.length;
  }

  /// Whether undo is possible (stack is not empty).
  bool get canUndo {
    _version.value;
    return _undoStack.isNotEmpty;
  }

  /// Whether redo is possible.
  bool get canRedo {
    _version.value;
    return _redoStack.isNotEmpty;
  }

  @override
  bool onBeforeChange<T>(StateChange<T> change) => true;

  @override
  void onAfterChange<T>(StateChange<T> change) {
    if (_isRestoring) return;

    _redoStack.clear();

    if (_currentBatch != null) {
      _currentBatch!.add(change);
    } else {
      _addChange(change);
    }
  }

  @override
  void onBatchStart() {
    if (_isRestoring) return;
    _currentBatch = [];
  }

  @override
  void onBatchEnd() {
    if (_isRestoring) return;
    if (_currentBatch != null && _currentBatch!.isNotEmpty) {
      final composite = CompositeStateChange(List.from(_currentBatch!));
      _addChange(composite);
    }
    _currentBatch = null;
  }

  void _addChange(StateChange change) {
    _undoStack.add(change);

    if (Lx.maxHistorySize > 0 && _undoStack.length > Lx.maxHistorySize) {
      _undoStack.removeAt(0);
    }
    Lx.runWithoutMiddleware(() => _version.value++);
  }

  /// Reverts the last change.
  ///
  /// Returns `true` if undo was successful, `false` if history is empty.
  bool undo() {
    if (_undoStack.isEmpty) return false;

    final change = _undoStack.removeLast();
    _redoStack.add(change);

    _applyRestore(change, isUndo: true);
    Lx.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  /// Re-applies the last undone change.
  ///
  /// Returns `true` if redo was successful, `false` if redo stack is empty.
  bool redo() {
    if (_redoStack.isEmpty) return false;

    final change = _redoStack.removeLast();
    _undoStack.add(change);

    _applyRestore(change, isUndo: false);
    Lx.runWithoutMiddleware(() => _version.value++);
    return true;
  }

  void _applyRestore(StateChange change, {required bool isUndo}) {
    _isRestoring = true;
    try {
      if (change is CompositeStateChange) {
        final listToProcess = isUndo ? change.changes.reversed : change.changes;
        for (final subChange in listToProcess) {
          _restoreSingle(subChange, isUndo: isUndo);
        }
      } else {
        _restoreSingle(change, isUndo: isUndo);
      }
    } finally {
      _isRestoring = false;
    }
  }

  void _restoreSingle(StateChange change, {required bool isUndo}) {
    final valueToRestore = isUndo ? change.oldValue : change.newValue;

    if (change.restore != null) {
      Lx.runWithoutMiddleware(() {
        change.restore!(valueToRestore);
      });
      return;
    }

    print(
        '[LxHistoryMiddleware] Warning: No restore mechanism for ${change.name ?? change.valueType}');
  }

  /// Clears the entire history (both undo and redo stacks).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    Lx.runWithoutMiddleware(() => _version.value++);
  }

  /// Returns all changes associated with a specific variable [name].
  List<StateChange> changesFor(String name) {
    return _undoStack.where((c) => c.name == name).toList();
  }

  /// Prints the current history to the console for debugging.
  void printHistory() {
    print('--- Undo Stack ---');
    for (final change in _undoStack) {
      print(change);
    }
    if (_redoStack.isNotEmpty) {
      print('--- Redo Stack ---');
      for (final change in _redoStack.reversed) {
        print(change);
      }
    }
  }

  /// Serializes the history state to JSON.
  Map<String, dynamic> toJson() => {
        'undoStack': _undoStack.map((c) => c.toJson()).toList(),
        'redoStack': _redoStack.map((c) => c.toJson()).toList(),
        'canUndo': canUndo,
        'canRedo': canRedo,
      };
}
