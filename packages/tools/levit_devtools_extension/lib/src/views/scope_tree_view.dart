import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Displays the live DI scope hierarchy and selected scope registrations.
class ScopeTreeView extends LView<LevitInspectorController> {
  /// Creates the scope tree inspector view.
  const ScopeTreeView({super.key});

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    final flattened = controller.flattenedScopes;
    if (flattened.isEmpty) {
      return const Center(child: Text('No active scopes recorded yet.'));
    }

    final scopes = controller.snapshot.scopes;
    final selectedId = controller.selectedScopeId() ?? flattened.first.scope.id;
    final selectedScope = scopes[selectedId] ?? flattened.first.scope;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: flattened.length,
            itemBuilder: (context, index) {
              final node = flattened[index];
              final scope = node.scope;
              final isSelected = scope.id == selectedScope.id;
              final isClosing = scope.progress['isClosing'] == true;
              final pending =
                  scope.progress['pendingInitializations'] as int? ?? 0;
              final depCount = controller.dependencyCountForScope(scope.id);

              return ListTile(
                dense: true,
                selected: isSelected,
                contentPadding: EdgeInsets.only(
                  left: 12.0 + (node.depth * 18.0),
                  right: 12,
                ),
                leading: Icon(
                  isClosing
                      ? Icons.hourglass_bottom
                      : Icons.account_tree_outlined,
                  size: 16,
                  color: isClosing ? Colors.orange : null,
                ),
                title: Text(
                  '${scope.name} (#${scope.id})',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '$depCount dep(s)'
                  '${pending > 0 ? ' • $pending pending' : ''}'
                  '${isClosing ? ' • closing' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => controller.selectedScopeId.value = scope.id,
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: _ScopeDetailPane(scope: selectedScope),
        ),
      ],
    );
  }
}

class _ScopeDetailPane extends StatelessWidget {
  final LevitScopeModel scope;

  const _ScopeDetailPane({required this.scope});

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<LevitInspectorController>();
    final deps = controller.dependenciesForScope(scope.id);
    final ownedReactives = controller.ownedReactivesForScope(scope.id);
    final progressRegistrations =
        (scope.progress['registrations'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${scope.name} (scope #${scope.id})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Chip(
              label: Text(
                scope.parentScopeId == null
                    ? 'Root Scope'
                    : 'Parent #${scope.parentScopeId}',
              ),
              visualDensity: VisualDensity.compact,
            ),
            if (scope.progress['isClosing'] == true)
              const Chip(
                label: Text('Closing'),
                backgroundColor: Color(0x33FF9800),
                visualDensity: VisualDensity.compact,
              ),
            if ((scope.progress['pendingInitializations'] as int? ?? 0) > 0)
              Chip(
                label: Text(
                  'Pending Init: ${scope.progress['pendingInitializations']}',
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Registrations (${deps.isNotEmpty ? deps.length : progressRegistrations.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (deps.isEmpty && progressRegistrations.isEmpty)
          const Text('No registrations in this scope.')
        else if (deps.isNotEmpty)
          ...deps.map(
            (dep) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(dep.key),
                subtitle: Text(
                  '${dep.type.name} • ${dep.status.name}'
                  '${dep.isLazy ? ' • lazy' : ''}'
                  '${dep.isFactory ? ' • factory' : ''}'
                  '${dep.isAsync ? ' • async' : ''}',
                ),
              ),
            ),
          )
        else
          ...progressRegistrations.map(
            (reg) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text('${reg['key']} (${reg['type']})'),
                subtitle: Text(
                  '${reg['isInstantiated'] == true ? 'instantiated' : 'registered'}'
                  '${reg['aliasOf'] != null ? ' • aliasOf ${reg['aliasOf']}' : ''}'
                  '${reg['permanent'] == true ? ' • permanent' : ''}'
                  '${reg['isFactory'] == true ? ' • factory' : ''}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Owned Reactives (${ownedReactives.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (ownedReactives.isEmpty)
          const Text('No reactive variables linked to this scope.')
        else
          ...ownedReactives.map(
            (v) => ListTile(
              dense: true,
              title: Text(v.name),
              subtitle: Text(
                '${v.isSensitive ? '***' : '${v.value}'} • ${v.listenerCount} listener(s)',
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () => controller.focusReactive(v.id),
            ),
          ),
      ],
    );
  }
}
