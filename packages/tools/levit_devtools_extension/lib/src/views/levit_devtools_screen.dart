import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../client/devtools_client.dart';
import '../controller/inspector_controller.dart';
import 'diagnostics_view.dart';
import 'reactive_graph_view.dart';
import 'scope_tree_view.dart';
import 'task_tree_view.dart';
import 'timeline_view.dart';

/// Main Flutter DevTools screen for inspecting a live Levit application.
///
/// Owns a dedicated [LScope] hosting [LevitInspectorController]. When [client]
/// is omitted, resolves [LevitDevToolsClient] from the enclosing [LScope].
class LevitDevToolsScreen extends LScopedView<LevitInspectorController> {
  /// Optional explicit transport client; falls back to DI resolution.
  final LevitDevToolsClient? client;

  /// Whether [LevitInspectorController] should dispose the client when closed.
  final bool ownsClient;

  /// Creates the Levit DevTools inspector screen.
  const LevitDevToolsScreen({
    super.key,
    this.client,
    this.ownsClient = false,
  }) : super(autoWatch: false, scopeName: 'levit_devtools');

  @override
  void onConfigureScope(LevitScope scope) {
    final resolvedClient = client ?? scope.find<LevitDevToolsClient>();
    scope.put(
      () => LevitInspectorController(resolvedClient, ownsClient: ownsClient),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return Scaffold(
      body: Column(
        children: [
          const _HeaderToolbar(),
          const Divider(height: 1),
          Expanded(
            child: LWatch(() {
              if (!controller.attached()) {
                return const _UnattachedEmptyState();
              }
              return const Column(
                children: [
                  _InspectorTabBar(),
                  Divider(height: 1),
                  Expanded(child: _ActiveInspectorTab()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _InspectorTabBar extends LView<LevitInspectorController> {
  const _InspectorTabBar();

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    controller.revision();
    final activeIndex = controller.activeTabIndex();
    final findings = controller.findings;
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = [
      ('Scopes (${controller.snapshot.scopes.length})', null),
      ('Reactives (${controller.snapshot.variables.length})', null),
      ('Tasks (${controller.snapshot.taskTrees.length})', null),
      ('Timeline (${controller.snapshot.events.length})', null),
      (
        'Diagnostics',
        findings.isEmpty
            ? null
            : _CountBadge(
                count: findings.length,
                hasError: controller.hasErrorFindings,
              ),
      ),
    ];

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                InkWell(
                  onTap: () => controller.activeTabIndex.value = i,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: activeIndex == i
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            color: activeIndex == i
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: activeIndex == i
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (tabs[i].$2 case final badge?) ...[
                          const SizedBox(width: 6),
                          badge,
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveInspectorTab extends LView<LevitInspectorController> {
  const _ActiveInspectorTab();

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return switch (controller.activeTabIndex()) {
      0 => const ScopeTreeView(),
      1 => const ReactiveGraphView(),
      2 => const TaskTreeView(),
      3 => const TimelineView(),
      _ => const DiagnosticsView(),
    };
  }
}

class _HeaderToolbar extends LView<LevitInspectorController> {
  const _HeaderToolbar();

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    final isAttached = controller.attached();
    final isPaused = controller.paused();
    final queued = controller.pausedCount();
    final findings = isAttached ? controller.findings : const [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Levit Inspector',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          Chip(
            avatar: Icon(
              isAttached ? Icons.check_circle : Icons.link_off,
              size: 16,
              color: isAttached ? Colors.green : Colors.orange,
            ),
            label: Text(
              isAttached ? 'Connected (Read-Only)' : 'Not Attached',
            ),
            visualDensity: VisualDensity.compact,
          ),
          if (isAttached) ...[
            OutlinedButton.icon(
              onPressed: controller.togglePause,
              icon: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                size: 16,
              ),
              label: Text(
                isPaused ? 'Resume${queued > 0 ? ' (+$queued)' : ''}' : 'Pause',
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.loading() ? null : controller.refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final json = controller.exportRedactedJson();
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied redacted snapshot JSON.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Copy JSON'),
            ),
            if (findings.isNotEmpty)
              ActionChip(
                avatar: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: controller.hasErrorFindings
                      ? Colors.red
                      : Colors.amber.shade700,
                ),
                label: Text('${findings.length} finding(s)'),
                onPressed: () => controller.activeTabIndex.value = 4,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool hasError;

  const _CountBadge({required this.count, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: hasError ? Colors.red.shade700 : Colors.amber.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnattachedEmptyState extends LView<LevitInspectorController> {
  const _UnattachedEmptyState();

  static const _snippet =
      '''import 'package:levit_devtools/levit_devtools.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  await LevitDevTools.attach();
  runApp(const MyApp());
}''';

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    final loading = controller.loading();
    final error = controller.errorMessage();

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LevitDevTools is not attached in the running app',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attach LevitDevTools in main() before runApp() to stream '
                    'redacted scopes, reactives, tasks, timeline events, and '
                    'diagnostics over the Dart VM Service.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      _snippet,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Last error: $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: loading ? null : controller.refresh,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          loading ? 'Checking...' : 'Retry Connection',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: _snippet),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Snippet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
